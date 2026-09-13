/*****************************************************************************
 *  tilta_submit.prg  -  Run_Tilta_Submit(nRechnr,lAllowNoFactoring)
 *
 *  Reicht eine Factoring-Rechnung bei Tilta ein. Laeuft ohne jede Rueckfrage,
 *  damit es aus dem Nachtlauf heraus geht:
 *
 *    1. POST /v1/invoices                      Rechnung anlegen (Capture)
 *    2. POST /v1/invoices/{external_id}/files  Belege hochladen
 *    3. POST /v1/services                      Finanzierung beantragen
 *
 *  Schritt 3 ist der eigentliche Finanzierungsauftrag: der Capture legt die
 *  Rechnung bei Tilta nur ab. Er kommt nach dem Upload, weil das Rechnungs-PDF
 *  zu den Voraussetzungen gehoert (Requirement INVOICE_FILE_MISSING).
 *
 *  Erst wenn alle drei Schritte durch sind, wird die Rechnung fuer den Versand
 *  freigegeben: FactorAprD setzen und den Status FINA leeren. Das ersetzt
 *  RUN_RECH_FACTOR_APPROVE. Scheitert etwas, bleibt FINA stehen - dann geht die
 *  Rechnung nicht raus, genau wie bisher, wenn niemand sie freigegeben hat.
 *
 *  Aufgerufen wird es an zwei Stellen:
 *    - checkresend (Nachtlauf), vor dem Rechnungsversand
 *    - RUN_TILTA_INVOICE, wenn jemand eine Rechnung von Hand einreicht
 *  Deshalb steht hier die Logik und dort nur die Oberflaeche.
 *
 *  Die external_id ist die blanke Rechnungsnummer - so sind die bisher von Hand
 *  hochgeladenen Rechnungen bei Tilta abgelegt, und nur so findet der GET sie
 *  wieder. Ob eine Rechnung schon eingereicht ist, sagt daher Tilta selbst und
 *  nicht ein zusaetzliches Feld im Trader.
 *
 *  Rueckgabe: Hash mit
 *     "ok"      .T. wenn eingereicht, Belege da und Finanzierung beantragt
 *     "changed" .T. wenn bei Tilta etwas angelegt wurde
 *     "freed"   .T. wenn der Status FINA geleert wurde
 *     "status"  Status des Finanzierungsservice, soweit bekannt
 *     "log"     Array mit Klartextzeilen zum Anzeigen oder Protokollieren
 *****************************************************************************/

#define TILTA_PDF_PRINTER   "Create PDF"   //Trader-Drucker vom Typ PDF

FUNCTION Run_Tilta_Submit(nRechnr,lAllowNoFactoring)

LOCAL hRes := {"ok" => .F., "changed" => .F., "freed" => .F., "status" => "", "log" => {}}
LOCAL oRech, oKuExtra, oReExtra
LOCAL cExtId, cBuyer
LOCAL hInv, hSvc
LOCAL cBody, nResponse := 0, cResponse := ""
LOCAL aDocs := {}, aLs
LOCAL cPdf, cWhy := ""
LOCAL nDueDays, nNetto
LOCAL cSvcSt := "", cReq := ""
LOCAL nAdvance := 0
LOCAL cDocs := ""
LOCAL nX
LOCAL lExists := .F.

   Default(@lAllowNoFactoring,.F.)

   NetUse("rechnung","reh")
   NetUse("englsre","re",.F.,0)
   NetUse("engkund","ku",.F.,0)
   NetUse("skontoa","sk")

   reh->(dbSetOrder( 1 ))
   IF ! reh->(dbSeek( Str(nRechnr,6) ))
      Aadd(hRes["log"],"Rechnung "+LTrim(Str(nRechnr))+" nicht gefunden.")
      RETURN hRes
   ENDIF
   oRech := Rechnung():New()
   oRech:Load(nRechnr)

   ku->(dbSetOrder( 1 ))
   IF ! ku->(dbSeek( Pad(oRech:Kunde,8)+"K" ))
      Aadd(hRes["log"],"Kunde "+Trim(oRech:Kunde)+" nicht gefunden.")
      RETURN hRes
   ENDIF
   cBuyer := LTrim(Str(ku->Nummer))
   cExtId := LTrim(Str(oRech:Rechnr))

   /*  Vorbedingungen. Alles, was hier abbricht, laesst die Rechnung im Status
    *  FINA - sie wird also nicht versendet, sondern gemeldet.  */
   oKuExtra := ku->(ExtraData():New(ku->Nummer))
   IF ! oKuExtra:Factoring .AND. ! lAllowNoFactoring
      Aadd(hRes["log"],"Kunde "+Trim(ku->Kunde)+" ist nicht fuer Factoring angemeldet.")
      RETURN hRes
   ENDIF

   IF oRech:Brutto <= 0
      Aadd(hRes["log"],"Rechnungsbetrag ist 0 - nichts einzureichen.")
      RETURN hRes
   ENDIF

   /*  Nur ohne Skonto: geprueft wird die Bedingung der Rechnung selbst, nicht
    *  die des Kunden - beim Kunden haengt die Sicherung im Setup.  */
   IF __TiltaHasSkonto(oRech:Skonto,oRech:Rechdat)
      Aadd(hRes["log"],"Zahlungsbedingung mit Skonto - Factoring geht nur ohne Skonto.")
      RETURN hRes
   ENDIF

   /*  Nur gepackte Rechnungen: Tilta finanziert gelieferte Ware, und der
    *  Lieferschein ist der Leistungsnachweis. oRech:Versandt ist im Modell auf
    *  re->Packed gemappt.  */
   IF ! oRech:Versandt
      Aadd(hRes["log"],"Rechnung ist noch nicht gepackt.")
      RETURN hRes
   ENDIF

   /*  Tilta nimmt nur Rechnungen an, deren Faelligkeit mindestens zwei Tage in
    *  der Zukunft liegt ("Invoice due date must minimum in two days"). Bei
    *  Vorkasse und Bankeinzug ergibt GetSkontoWait 0 Tage - die gehoeren auch
    *  nicht ins Factoring.  */
   nDueDays := sk->(GetSkontoWait(oRech:Skonto,oRech:Rechdat))
   IF oRech:Rechdat + nDueDays < Date() + 2
      Aadd(hRes["log"],"Faellig am "+DToC(oRech:Rechdat+nDueDays)+", Tilta verlangt "+ ;
                       "Faelligkeit ab "+DToC(Date()+2)+" - bitte im Portal klaeren.")
      RETURN hRes
   ENDIF

   /*  Belege einsammeln: ohne Rechnungs-PDF wird nichts eingereicht. Gesucht
    *  wird ausschliesslich im Archiv; bei einer Rechnung im Status FINA ist
    *  noch nichts gedruckt, dann wird das PDF hier erzeugt.  */
   cPdf := __TiltaFindPdf(oRech:Rechnr)
   IF Empty(cPdf) .AND. __TiltaMakePdf(oRech,@cWhy)
      cPdf := __TiltaFindPdf(oRech:Rechnr)
   ENDIF
   IF Empty(cPdf)
      Aadd(hRes["log"],"Kein Rechnungs-PDF im Archiv"+IF(Empty(cWhy),".",": "+cWhy))
      RETURN hRes
   ENDIF
   Aadd(aDocs,{cPdf,"INVOICE"})

   aLs := GetArchiveFiles( {"LS"=>oRech:Rechnr} )
   FOR nX := Len(aLs) TO 1 STEP -1                //von hinten: das juengste gewinnt
      IF Lower(Right(Trim(aLs[nX][6]),4)) == ".pdf"
         Aadd(aDocs,{aLs[nX][6],"PERFORMANCE_PROOF"})   //Lieferschein als Leistungsnachweis
         EXIT
      ENDIF
   NEXT

   /*  Ohne Buyer gibt es dort nichts zu finanzieren - das richtet
    *  tilta_setup.prg bei der Umstellung auf Factoring ein.  */
   __TiltaCall("buyers/"+cBuyer,"GET",NIL,@nResponse,@cResponse)
   IF nResponse == 404
      Aadd(hRes["log"],"Kunde ist bei Tilta nicht als Buyer "+cBuyer+" angelegt.")
      RETURN hRes
   ELSEIF nResponse != 200
      Aadd(hRes["log"],"Buyer-Abfrage: HTTP "+LTrim(Str(nResponse))+" "+cResponse)
      RETURN hRes
   ENDIF

   /*  Ist die Rechnung dort schon angelegt?  */
   __TiltaCall("invoices/"+cExtId,"GET",NIL,@nResponse,@cResponse)
   IF nResponse == 200
      lExists := .T.
      Aadd(hRes["log"],"Rechnung war bei Tilta schon angelegt.")
   ELSEIF nResponse != 404
      Aadd(hRes["log"],"Rechnungsabfrage: HTTP "+LTrim(Str(nResponse))+" "+cResponse)
      RETURN hRes
   ENDIF

   /*  1. Rechnung anlegen (Capture)  */
   IF ! lExists
      nNetto := oRech:Brutto - oRech:MwSt

      hInv := {=>}
      hInv["external_id"]       := cExtId
      hInv["buyer_external_id"] := cBuyer
      hInv["payment_method"]    := "TRANSFER"
      hInv["invoice_number"]    := LTrim(Str(oRech:Rechnr))
      hInv["invoiced_at"]       := __TiltaTs(oRech:Rechdat)
      hInv["due_at"]            := __TiltaTsEnd(oRech:Rechdat+nDueDays)   //Tagesende, siehe __TiltaTsEnd
      hInv["amount"]            := {"gross"    => Round(oRech:Brutto*100,0), ;
                                    "net"      => Round(nNetto*100,0), ;
                                    "currency" => "EUR"}
      //Textfelder als UTF-8: die Quelle ist CP865, der JSON-Body muss UTF-8 sein
      hInv["billing_address"]   := {"country"  => Trim(ku->CountryIso), ;
                                    "postcode" => hb_StrToUtf8(Trim(ku->PLZ)), ;
                                    "city"     => hb_StrToUtf8(Trim(ku->Town)), ;
                                    "street"   => hb_StrToUtf8(Trim(ku->Street))}

      __TiltaTxt("Rechnung wird bei Tilta angelegt...")
      cBody := __TiltaCall("invoices","POST",hInv,@nResponse,@cResponse)
      __TiltaTxt("")

      IF nResponse < 200 .OR. nResponse >= 300
         Aadd(hRes["log"],"Tilta hat die Rechnung nicht angenommen: HTTP "+ ;
                          LTrim(Str(nResponse))+" "+cResponse+" "+Left(cBody,160))
         RETURN hRes
      ENDIF
      hRes["changed"] := .T.
      Aadd(hRes["log"],"Rechnung eingereicht ueber "+LTrim(Transform(oRech:Brutto,"@E 999,999.99"))+ ;
                       " EUR, faellig "+DToC(oRech:Rechdat+nDueDays)+".")

      /*  Factorer setzen, damit die Rechnung in RUN_CHECK_FACTORING und im
       *  Nachtlauf RUN_TILTA_FACILITY_SYNC auftaucht  */
      oReExtra := reh->(ExtraData():New(oRech:Rechnr))
      IF Empty(oReExtra:Factorer)
         oReExtra:Factorer := Pad("TILTA",12)
         oReExtra:Save()
      ENDIF
   ENDIF

   /*  2. Belege hochladen  */
   __TiltaTxt("Belege werden hochgeladen...")
   nResponse := __TiltaUpload(cExtId,aDocs,@cResponse)
   __TiltaTxt("")

   IF nResponse < 200 .OR. nResponse >= 300
      Aadd(hRes["log"],"Upload der Belege fehlgeschlagen: HTTP "+LTrim(Str(nResponse))+ ;
                       " "+Left(cResponse,120))
      RETURN hRes
   ENDIF
   FOR nX := 1 TO Len(aDocs)
      cDocs += IF(nX>1,", ","")+aDocs[nX][2]
   NEXT
   Aadd(hRes["log"],"Belege hochgeladen: "+cDocs)

   /*  3. Finanzierung beantragen. Vorher fragen, ob es den Service schon gibt:
    *  bei einer Rechnung, die bereits angelegt war, waere ein zweiter Antrag
    *  entweder ein Fehler oder ein Duplikat.  */
   cBody := __TiltaCall("invoices/"+cExtId+"/services","GET",NIL,@nResponse,@cResponse)
   IF nResponse == 200
      cSvcSt := __TiltaSvcInfo(cBody,@nAdvance,@cReq)
   ENDIF

   IF Empty(cSvcSt)
      hSvc := {=>}
      hSvc["external_id"]         := cExtId+"-FIN"
      hSvc["invoice_external_id"] := cExtId
      hSvc["service_type"]        := "FINANCING"
      hSvc["terms_accepted_at"]   := __TiltaTsNow()

      __TiltaTxt("Finanzierung wird beantragt...")
      cBody := __TiltaCall("services","POST",hSvc,@nResponse,@cResponse)
      __TiltaTxt("")

      IF nResponse < 200 .OR. nResponse >= 300
         Aadd(hRes["log"],"Finanzierung nicht beantragt: HTTP "+LTrim(Str(nResponse))+ ;
                          " "+cResponse+" "+Left(cBody,160))
         RETURN hRes
      ENDIF
      cSvcSt := __TiltaSvcInfo(cBody,@nAdvance,@cReq)
   ENDIF

   /*  Eine abgelehnte Finanzierung darf die Rechnung nicht freigeben: die Ware
    *  ist raus, aber das Geld kommt nicht von Tilta.  */
   IF cSvcSt == "REJECTED" .OR. cSvcSt == "CANCELLED"
      Aadd(hRes["log"],"Tilta finanziert diese Rechnung nicht: "+cSvcSt+ ;
                       IF(Empty(cReq),""," ("+cReq+")"))
      RETURN hRes
   ENDIF
   hRes["status"] := cSvcSt
   Aadd(hRes["log"],"Finanzierung: "+IF(Empty(cSvcSt),"beantragt",cSvcSt)+ ;
                    IF(nAdvance != 0,", Auszahlung "+LTrim(Transform(nAdvance/100,"@E 9,999,999.99")),"")+ ;
                    IF(Empty(cReq),""," , offen: "+cReq))

   /*  Freigabe: Tilta gibt nicht separat frei, der beantragte Service ist die
    *  Freigabe. Also FactorAprD setzen und den Status FINA leeren, dann
    *  verschickt checkresend die Rechnung.  */
   oReExtra := reh->(ExtraData():New(oRech:Rechnr))
   IF Empty(oReExtra:FactorAprD)
      oReExtra:FactorAprD := Date()
      oReExtra:Save()
   ENDIF
   IF oRech:State == "FINA"
      oRech := Rechnung():New()          //frisch laden, wie in RUN_RECH_FACTOR_APPROVE
      oRech:Load(nRechnr)
      oRech:State := ""
      oRech:Save()
      hRes["freed"] := .T.
      Aadd(hRes["log"],"Rechnung ist zum Versand freigegeben.")

      /*  Kontrolle: checkresend prueft re->State (englsre), geschrieben wird
       *  ueber Rechnung() aber reh->State. Beide Dateien fuehren denselben
       *  Kopfsatz - wenn das doch einmal auseinanderlaeuft, bliebe die
       *  Rechnung stumm im Versand haengen. Deshalb hier nachsehen.  */
      re->(dbSetOrder( 4 ))
      IF re->(dbSeek( Str(nRechnr,6) )) .AND. re->State == "FINA"
         Aadd(hRes["log"],"ACHTUNG: FINA steht in englsre noch - Versand pruefen.")
      ENDIF
   ENDIF

   hRes["ok"] := .T.

RETURN hRes

/*  Meldung nur zeigen, wenn jemand zusieht - im Nachtlauf laeuft alles stumm.
 *  Leerer Text raeumt das Fenster wieder ab.                              */
STATIC FUNCTION __TiltaTxt(cTxt)
   IF ! GetConfigValue("BATCHMODE")
      IF Empty(cTxt)
         TxtClear()
      ELSE
         TxtBox(cTxt)
      ENDIF
   ENDIF
RETURN NIL

/*  Enthaelt die Zahlungsbedingung ein Skonto? GetSkonto() liefert JEDE Stufe
 *  als {Rate,Tage} zurueck, also auch "30 Tage netto" mit Rate 0 - es zaehlt
 *  daher nur eine Stufe mit Rate ungleich 0.                              */
STATIC FUNCTION __TiltaHasSkonto(nSkonto,dDate)
   LOCAL aSk := sk->(GetSkonto(nSkonto,dDate,dDate))
   LOCAL nX
   FOR nX := 1 TO Len(aSk)
      IF ValType(aSk[nX]) == "A" .AND. Len(aSk[nX]) >= 1 .AND. aSk[nX][1] != 0
         RETURN .T.
      ENDIF
   NEXT
RETURN .F.

/*  Rechnungs-PDF aus dem Archiv holen - bewusst nur dort, das Ausgabever-
 *  zeichnis des PDF-Druckers wird nicht durchsucht.
 *  GetArchiveFiles liefert aufsteigend, deshalb von hinten: das juengste
 *  Dokument gewinnt.                                                     */
STATIC FUNCTION __TiltaFindPdf(nRechnr)
   LOCAL aFiles := GetArchiveFiles( {"RE"=>nRechnr} )
   LOCAL nX
   FOR nX := Len(aFiles) TO 1 STEP -1
      IF Lower(Right(Trim(aFiles[nX][6]),4)) == ".pdf"
         RETURN aFiles[nX][6]
      ENDIF
   NEXT
RETURN ""

/*  Rechnung als PDF erzeugen, damit sie im Archiv liegt. Der Druckweg waehlt
 *  den Drucker vorrangig ueber GetConfigValue("printer") - also Index setzen,
 *  drucken, zuruecksetzen. engrepr(...,.F.,1,0) = ohne Dialog, ein Original,
 *  keine Kopie.
 *
 *  Ohne Rueckfrage, weil das auch im Nachtlauf laufen muss. Der Grund eines
 *  Fehlschlags kommt per cWhy zurueck und landet im Protokoll.            */
STATIC FUNCTION __TiltaMakePdf(oRech,cWhy)
   LOCAL nPrinter := __TiltaPdfPrinterNo()
   LOCAL nOld, e
   LOCAL lOk := .T.

   cWhy := ""
   IF nPrinter == 0
      cWhy := "Drucker "+TILTA_PDF_PRINTER+" ist auf diesem Rechner nicht eingerichtet"
      RETURN .F.
   ENDIF

   nOld := SetConfigValue("printer",nPrinter)
   BEGIN SEQUENCE WITH {|e| Break(e)}
      __TiltaTxt("Rechnung wird als PDF gedruckt...")
      engrepr("",0,oRech:Rechnr,.F.,1,0)
      __TiltaTxt("")
   RECOVER USING e
      __TiltaTxt("")
      cWhy := "PDF-Druck fehlgeschlagen: "+e:Description
      lOk  := .F.
   END SEQUENCE
   SetConfigValue("printer",nOld)
RETURN lOk

/*  Index des PDF-Druckers in der Druckerliste des Benutzers (0 = nicht da).
 *  Die Liste kommt aus Printer():Printers - genau wie in SelectPrint(); die
 *  Klasse weiss selbst, wo PRINT.DAT liegt.                                */
STATIC FUNCTION __TiltaPdfPrinterNo()
   LOCAL aPr
   LOCAL nX

   BEGIN SEQUENCE WITH {|e| Break(e)}
      aPr := Printer():Printers
   RECOVER
      aPr := NIL
   END SEQUENCE

   IF ValType(aPr) != "A"
      RETURN 0
   ENDIF

   FOR nX := 1 TO Len(aPr)
      IF ValType(aPr[nX]) == "A" .AND. Len(aPr[nX]) >= 2 .AND. ValType(aPr[nX][2]) == "C" ;
         .AND. Upper(AllTrim(aPr[nX][2])) == Upper(TILTA_PDF_PRINTER)
         RETURN nX
      ENDIF
   NEXT
RETURN 0

#include "x:\run\tilta_api.prg"
