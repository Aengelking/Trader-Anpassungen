/*****************************************************************************
 *  tilta_invoice.prg  -  RUN_TILTA_INVOICE
 *
 *  Reicht eine Factoring-Rechnung bei Tilta ein, was bisher von Hand im Portal
 *  passiert ist:
 *
 *    1. POST /v1/invoices                      Rechnung anlegen (Capture)
 *    2. POST /v1/invoices/{external_id}/files  Belege hochladen
 *
 *  Der Kunde muss bei Tilta schon als Buyer mit Fazilitaet eingerichtet sein -
 *  das macht RUN_TILTA_BUYER bei der Umstellung auf Factoring.
 *
 *  Orders werden bewusst NICHT angelegt: order_external_ids ist optional, die
 *  Order ist nur die Vorab-Reservierung von Kredit vor der Lieferung.
 *
 *  Der Capture ist laut Tilta die rechtswirksame Finanzierung und stoesst die
 *  Auszahlung an - deshalb ist das hier ein bewusster Aufruf durch einen
 *  Menschen und laeuft nicht automatisch aus after_pack. Die Mail aus
 *  RUN_FACTORING bleibt unveraendert die Aufforderung dazu.
 *
 *  Die external_id ist die blanke Rechnungsnummer - so sind die bisher von Hand
 *  hochgeladenen Rechnungen bei Tilta abgelegt, und nur so findet der GET sie
 *  wieder. Dadurch braucht es auch kein neues ExtraData-Feld: ob eine Rechnung
 *  schon eingereicht ist, sagt ein GET auf die Rechnung bei Tilta.
 *****************************************************************************/

#define TILTA_PDF_PRINTER   "Create PDF"   //Trader-Drucker vom Typ PDF

PROCEDURE Run_Tilta_Invoice()

LOCAL nNr := 0
LOCAL getList := {}
LOCAL oRech, oKuExtra, oReExtra
LOCAL cExtId, cBuyer
LOCAL hInv
LOCAL cBody, nResponse := 0, cResponse := ""
LOCAL aDocs := {}, aLs
LOCAL cPdf
LOCAL nDueDays, nNetto
LOCAL cMsg
LOCAL nX
LOCAL lExists := .F.
LOCAL lFreed := .F.

   NetUse("rechnung","reh")
   NetUse("englsre","re",.F.,0)
   NetUse("engkund","ku",.F.,0)
   NetUse("skontoa","sk")

   Head("Rechnung bei Tilta einreichen"+IF(__TiltaIsSandbox()," [SANDBOX]",""))

   /*  Rechnung waehlen  */
   DO WHILE .T.
      @ 01,00 SAY "Rechnung" GET nNr PICTURE "999999"
      READ
      IF LastKey() == 27
         RETURN
      ENDIF
      @ 01,16 CLEAR TO 01,MaxCol()
      IF ! reh->(dbSeek( Str(nNr,6) ))
         @ 01,16 SAY "NICHT GEFUNDEN"
      ELSE
         oRech := Rechnung():New()
         oRech:Load(nNr)
         @ 01,16 SAY oRech:oKunde:cName
         EXIT
      ENDIF
   ENDDO

   ku->(dbSetOrder( 1 ))
   IF ! ku->(dbSeek( Pad(oRech:Kunde,8)+"K" ))
      Tr_MsgBox("Kunde nicht gefunden")
      RETURN
   ENDIF
   cBuyer := LTrim(Str(ku->Nummer))

   /*  Vorbedingungen  */
   oKuExtra := ku->(ExtraData():New(ku->Nummer))
   IF ! oKuExtra:Factoring
      //in der Sandbox darf man auch mit einem Nicht-Factoring-Kunden testen
      IF ! __TiltaIsSandbox()
         Tr_MsgBox({"Dieser Kunde ist nicht fuer Factoring angemeldet.","Rechnung wird nicht eingereicht."})
         RETURN
      ELSEIF Tr_MsgBox({"Dieser Kunde ist nicht fuer Factoring angemeldet.","In der Sandbox trotzdem einreichen?"},"SANDBOX",{"Nein","Ja"}) != 2
         RETURN
      ENDIF
   ENDIF

   IF oRech:Brutto <= 0
      Tr_MsgBox("Rechnungsbetrag ist 0 - nichts einzureichen.")
      RETURN
   ENDIF

   /*  Nur gepackte Rechnungen: Tilta finanziert gelieferte Ware, und der
    *  Lieferschein ist der Leistungsnachweis. oRech:Versandt ist im Modell
    *  auf re->Packed gemappt.  */
   IF ! oRech:Versandt
      Tr_MsgBox({"Rechnung "+LTrim(Str(oRech:Rechnr))+" ist noch nicht gepackt.", ;
                 "Nur gepackte Rechnungen koennen bei Tilta eingereicht werden."},"NICHT GEPACKT")
      RETURN
   ENDIF

   cExtId := LTrim(Str(oRech:Rechnr))   //wie bisher von Hand: blanke Nummer, kein Praefix

   /*  Belege einsammeln: ohne Rechnungs-PDF reichen wir nichts ein.
    *  Bei einer Rechnung im Status FINA ist noch nichts gedruckt - dann wird das
    *  PDF auf Nachfrage mit dem Drucker TILTA_PDF_PRINTER erzeugt.  */
   cPdf := __TiltaFindPdf(oRech:Rechnr)
   IF Empty(cPdf) .AND. __TiltaMakePdf(oRech)
      cPdf := __TiltaFindPdf(oRech:Rechnr)
   ENDIF
   IF Empty(cPdf)
      Tr_MsgBox({"Ohne Rechnungs-PDF wird nichts eingereicht.", ;
                 "Bitte die Rechnung mit dem Drucker "+TILTA_PDF_PRINTER+" ausdrucken", ;
                 "und hier erneut starten."},"KEIN PDF")
      RETURN
   ENDIF
   Aadd(aDocs,{cPdf,"INVOICE"})
   aLs := GetArchiveFiles( {"LS"=>oRech:Rechnr} )
   FOR nX := Len(aLs) TO 1 STEP -1                //auch hier das juengste
      IF Lower(Right(Trim(aLs[nX][6]),4)) == ".pdf"
         Aadd(aDocs,{aLs[nX][6],"PERFORMANCE_PROOF"})   //Lieferschein als Leistungsnachweis
         EXIT
      ENDIF
   NEXT

   /*  Ist die Rechnung dort schon angelegt?  */
   __TiltaCall("invoices/"+cExtId,"GET",NIL,@nResponse,@cResponse)
   IF nResponse == 200
      lExists := .T.
   ELSEIF nResponse != 404 .AND. nResponse != 0
      IF Tr_MsgBox({"Unerwartete Antwort von Tilta beim Pruefen: "+LTrim(Str(nResponse))+" "+cResponse,"Trotzdem weitermachen?"},,{"Nein","Ja"}) != 2
         RETURN
      ENDIF
   ENDIF

   /*  1. Rechnung anlegen (Capture)  */
   IF ! lExists

      /*  Ohne Buyer gibt es dort nichts zu finanzieren - das richtet
       *  RUN_TILTA_BUYER bei der Umstellung auf Factoring ein.  */
      __TiltaCall("buyers/"+cBuyer,"GET",NIL,@nResponse,@cResponse)
      IF nResponse == 404
         Tr_MsgBox({"Kunde "+Trim(ku->Kunde)+" ist bei Tilta nicht als Buyer "+cBuyer+" angelegt.", ;
                    "Bitte den Kunden zuerst mit RUN_TILTA_BUYER einrichten."},"NICHT EINGERICHTET")
         RETURN
      ELSEIF nResponse != 200
         IF Tr_MsgBox({"Buyer-Abfrage bei Tilta: HTTP "+LTrim(Str(nResponse))+" "+cResponse,"Trotzdem weitermachen?"},,{"Nein","Ja"}) != 2
            RETURN
         ENDIF
      ENDIF

      nDueDays := sk->(GetSkontoWait(oRech:Skonto,oRech:Rechdat))
      nNetto   := oRech:Brutto - oRech:MwSt

      /*  Tilta nimmt nur Rechnungen an, deren Faelligkeit mindestens zwei Tage
       *  in der Zukunft liegt ("Invoice due date must minimum in two days").
       *  Das hier vorher pruefen, statt in ein 400 zu laufen.  */
      IF oRech:Rechdat + nDueDays < Date() + 2
         Tr_MsgBox({"Diese Rechnung kann bei Tilta nicht mehr eingereicht werden.", ;
                    "Faellig am "+DToC(oRech:Rechdat+nDueDays)+" - Tilta verlangt mindestens", ;
                    "zwei Tage Vorlauf, also Faelligkeit ab "+DToC(Date()+2)+".", ;
                    "Bitte wie bisher im Portal klaeren."},"ZU SPAET")
         RETURN
      ENDIF

      cMsg := "Rechnung "+LTrim(Str(oRech:Rechnr))+" ueber "+LTrim(Transform(oRech:Brutto,"@E 999,999.99"))+" EUR"
      IF Tr_MsgBox({cMsg,"faellig am "+DToC(oRech:Rechdat+nDueDays),"jetzt bei Tilta einreichen?"},IF(__TiltaIsSandbox(),"SANDBOX",""),{"Nein","Ja"}) != 2
         RETURN
      ENDIF

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
      hInv["billing_address"]   := {"country"  => Trim(ku->CountryIso), ;
                                    "postcode" => Trim(ku->PLZ), ;
                                    "city"     => Trim(ku->Town), ;
                                    "street"   => Trim(ku->Street)}

      TxtBox("Rechnung wird bei Tilta angelegt...")
      cBody := __TiltaCall("invoices","POST",hInv,@nResponse,@cResponse)
      TxtClear()

      IF nResponse < 200 .OR. nResponse >= 300
         Tr_MsgBox({"Tilta hat die Rechnung nicht angenommen.","HTTP "+LTrim(Str(nResponse))+" "+cResponse,Left(cBody,200)},"FEHLER")
         RETURN
      ENDIF

      /*  Factorer setzen, damit die Rechnung in RUN_CHECK_FACTORING auftaucht  */
      oReExtra := reh->(ExtraData():New(oRech:Rechnr))
      IF Empty(oReExtra:Factorer)
         oReExtra:Factorer := Pad("TILTA",12)
         oReExtra:Save()
      ENDIF
   ENDIF

   /*  2. Belege hochladen  */
   TxtBox("Belege werden hochgeladen...")
   nResponse := __TiltaUpload(cExtId,aDocs,@cResponse)
   TxtClear()

   IF nResponse < 200 .OR. nResponse >= 300
      Tr_MsgBox({"Die Rechnung ist bei Tilta angelegt,","aber der Upload der Belege ist gescheitert:","HTTP "+LTrim(Str(nResponse))+" "+Left(cResponse,120),"Bitte die Belege im Portal nachreichen."},"TEILWEISE FEHLGESCHLAGEN")
      RETURN
   ENDIF

   /*  Erst jetzt - Rechnung angelegt UND Belege da - ist die Finanzierung
    *  angestossen. Tilta gibt nicht separat frei (der Capture IST die
    *  Finanzierung), also kann die Rechnung raus: FactorAprD setzen und den
    *  State FINA leeren, dann verschickt checkresend sie im Nachtlauf.
    *  Das ersetzt RUN_RECH_FACTOR_APPROVE.  */
   oReExtra := reh->(ExtraData():New(oRech:Rechnr))
   IF Empty(oReExtra:FactorAprD)
      oReExtra:FactorAprD := Date()
      oReExtra:Save()
   ENDIF
   IF oRech:State == "FINA"
      oRech := Rechnung():New()          //frisch laden, wie in RUN_RECH_FACTOR_APPROVE
      oRech:Load(nNr)
      oRech:State := ""
      oRech:Save()
      lFreed := .T.
   ENDIF

   cMsg := IF(lExists,"Rechnung war bereits angelegt, ","Rechnung eingereicht, ")
   FOR nX := 1 TO Len(aDocs)
      cMsg += IF(nX>1,", ","")+aDocs[nX][2]
   NEXT
   Tr_MsgBox({cMsg+" hochgeladen.", ;
              "Rechnung "+LTrim(Str(oRech:Rechnr))+" bei Tilta: "+cExtId, ;
              IF(lFreed,"Rechnung ist zum Versand freigegeben.","")},"OK")

RETURN

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

/*  Rechnung als PDF erzeugen. Der Druckweg waehlt den Drucker vorrangig ueber
 *  GetConfigValue("printer") - also Index setzen, drucken, zuruecksetzen. Die
 *  Druckerliste des Benutzers liegt als PRINT.DAT im Konfigurationsverzeichnis.
 *  engrepr(...,.F.,1,0) = ohne Dialog, ein Original, keine Kopie.          */
STATIC FUNCTION __TiltaMakePdf(oRech)
   LOCAL nPrinter := __TiltaPdfPrinterNo()
   LOCAL nOld, e

   IF nPrinter == 0
      Tr_MsgBox({"Der Drucker "+TILTA_PDF_PRINTER+" ist auf diesem Rechner nicht", ;
                 "eingerichtet (Druckerauswahl im Trader).", ;
                 "Bitte einrichten oder die Rechnung von Hand als PDF drucken."},"KEIN PDF-DRUCKER")
      RETURN .F.
   ENDIF

   IF Tr_MsgBox({"Fuer Rechnung "+LTrim(Str(oRech:Rechnr))+" liegt noch kein PDF vor.", ;
                 "Jetzt mit dem Drucker "+TILTA_PDF_PRINTER+" erzeugen?"},,{"Nein","Ja"}) != 2
      RETURN .F.
   ENDIF

   nOld := SetConfigValue("printer",nPrinter)
   BEGIN SEQUENCE WITH {|e| Break(e)}
      TxtBox("Rechnung wird als PDF gedruckt...")
      engrepr("",0,oRech:Rechnr,.F.,1,0)
      TxtClear()
   RECOVER USING e
      TxtClear()
      Tr_MsgBox({"Der PDF-Druck ist fehlgeschlagen.",e:Description},"FEHLER")
   END SEQUENCE
   SetConfigValue("printer",nOld)
RETURN .T.

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
      IF ValType(aPr[nX]) == "A" .AND. Len(aPr[nX]) >= 1 .AND. ValType(aPr[nX][1]) == "C" ;
         .AND. Upper(AllTrim(aPr[nX][2])) == Upper(TILTA_PDF_PRINTER)
         RETURN nX
      ENDIF
   NEXT
RETURN 0

#include "x:\run\tilta_api.prg"
