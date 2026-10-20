/*****************************************************************************
 *  tilta_hook.prg  -  Tilta-Einrichtung aus den Hooks heraus
 *
 *  Wird von den Hooks am Dateiende eingebunden:
 *
 *      #include "x:\run\tilta_hook.prg"
 *
 *  Zwei Stellen stossen die Einrichtung an, und beide sollen sich gleich
 *  verhalten:
 *     after_save_address      beim Speichern einer Kundenadresse
 *     after_save_extravalue   beim Setzen des Kennzeichens FACTORING
 *
 *  Die Arbeit macht run\tilta_setup.prg - Buyer, Ansprechpartner und
 *  KreditfazilitÑt. Hier steht nur, was mit dem Ergebnis passiert.
 *****************************************************************************/

#define TILTA_NETTO_SKONTO  7      //14 Tage netto - wie in after_save_address

/*  Kunden bei Tilta einrichten und das Ergebnis festhalten.
 *
 *  Das Setup ist idempotent und prÅft selbst, was schon vorhanden ist - es
 *  braucht also keine Erkennung, wann das Kennzeichen gesetzt wurde, und ein
 *  gescheiterter Schritt wird beim nÑchsten Mal nachgeholt.
 *
 *  Bewusst gekapselt: ein Fehler oder ein Ausfall der API darf das Speichern
 *  nicht behindern. Was angelegt wurde, landet als Bewegung am Kunden; nur
 *  wenn etwas offen bleibt, gibt es eine Mail.
 *
 *  Die Daten des Kunden werden vor dem Aufruf gelesen, weil tilta_setup den
 *  Satz selbst sucht und den Satzzeiger dabei bewegt.                      */
STATIC FUNCTION __TiltaSetupKunde(nKuNr)
   LOCAL hTilta := NIL
   LOCAL cKunde, cName1, cGroup

   NetUse("engkund","ku",.F.,0)
   ku->(dbSetOrder( 8 ))                        //str(nummer,6)
   IF ! ku->(dbSeek( Str(nKuNr,6) ))
      RETURN .F.
   ENDIF
   cKunde := Trim(ku->Kunde)
   cName1 := Trim(ku->Name1)
   cGroup := ku->Group

   /*  Factoring geht nur ohne Skonto. Bleibt die Bedingung stehen, lehnt
    *  tilta_setup ab und es ginge nur eine Mail raus - also hier gleich
    *  anbieten umzustellen.  */
   IF ! __TiltaFixSkonto(nKuNr)
      Bewegung({"STM",2,Date(),0,nKuNr,0,0,0,0, ;
                HB_AnsiToOem("Tilta: nicht eingerichtet, Zahlungsbedingung mit Skonto"), ;
                0,0,cGroup,0})
      RETURN .F.
   ENDIF

   BEGIN SEQUENCE WITH {|e| Break(e)}
      hTilta := MBaseRun(Path("run\tilta_setup.prg"),{nKuNr})
   RECOVER
      hTilta := NIL
   END SEQUENCE

   IF ValType(hTilta) == "H" .AND. hTilta["changed"]
      Bewegung({"STM",2,Date(),0,nKuNr,0,0,0,0, ;
                HB_AnsiToOem("Tilta: "+__TiltaLogLine(hTilta)),0,0,cGroup,0})
   ENDIF
   IF ValType(hTilta) != "H" .OR. ! hTilta["ok"]
      SendMail({{"amos.engelking@engelking.de","Amos"}, ;
                {"sigrid.reichmann@engelking.de","Sigrid"}}, ;
               "Tilta-Einrichtung unvollstÑndig: "+cKunde, ;
               "Kunde: "+cKunde+" "+cName1+Chr(13)+Chr(10)+ ;
               "Buyer: "+LTrim(Str(nKuNr))+Chr(13)+Chr(10)+Chr(13)+Chr(10)+ ;
               IF(ValType(hTilta) == "H",__TiltaLogText(hTilta),"Das Setup lief auf einen Fehler."))
   ENDIF

   /*  Erst wenn der Kunde bei Tilta steht, ist die Abtretungsanzeige faellig.
    *  Nur bei einer echten Neueinrichtung fragen - beim wiederholten Speichern
    *  eines laengst eingerichteten Kunden ist changed .F. und es bleibt still.
    *
    *  Und nur bei genehmigter FazilitÑt: bei PENDING ist noch nicht
    *  entschieden, ob Tilta den Kunden nimmt. Eine Anzeige "zahlen Sie ab
    *  sofort an die Tilta Pay GmbH" wÑre dann unter UmstÑnden
    *  zurÅckzunehmen - schlimmer als ein Brief zu spÑt.  */
   IF ValType(hTilta) == "H" .AND. hTilta["ok"] .AND. hTilta["changed"] ;
      .AND. ! GetConfigValue("BATCHMODE")
      IF hTilta["status"] == "ACTIVE"
         IF __TiltaInformKunde(nKuNr,cKunde)
            Bewegung({"STM",2,Date(),0,nKuNr,0,0,0,0, ;
                      HB_AnsiToOem("Tilta: Abtretungsanzeige an den Kunden verschickt"), ;
                      0,0,cGroup,0})
         ENDIF
      ELSE
         Tr_MsgBox({"Kunde "+cKunde+" ist bei Tilta eingerichtet.", ;
                    "Die KreditfazilitÑt ist aber noch nicht genehmigt:", ;
                    "Status "+IF(Empty(hTilta["status"]),"unbekannt",hTilta["status"])+".", ;
                    "", ;
                    "Die Abtretungsanzeige geht deshalb noch nicht raus.", ;
                    "Der Nachtlauf meldet, sobald die FazilitÑt aktiv ist -", ;
                    "dann lÑsst sie sich Åber den MenÅepunkt", ;
                    "'Kunde bei Tilta einrichten' nachholen."},"NOCH NICHT GENEHMIGT")
      ENDIF
   ENDIF

RETURN ValType(hTilta) == "H" .AND. hTilta["ok"]

/*  Den Kunden ueber die Abtretung informieren - auf Nachfrage.
 *
 *  Empfaenger ist der Buchhaltungskontakt, ersatzweise der Rechnungskontakt;
 *  dieselben, die auch Tilta als Ansprechpartner bekommt.
 *
 *  Das Stichdatum ist der heutige Tag: ab diesem Rechnungsdatum gehen die
 *  Forderungen an Tilta. Passt das nicht, hier ablehnen und die Anzeige von
 *  Hand schreiben - ein falsches Datum in einer Abtretungsanzeige waere
 *  schlimmer als ein Brief mehr.                                          */
STATIC FUNCTION __TiltaInformKunde(nKuNr,cKunde)
   LOCAL hContact
   LOCAL cMail, cName

   hContact := GetAccountsContact(nKuNr)
   IF hContact == NIL
      hContact := GetInvoiceContact(nKuNr)
   ENDIF
   IF hContact == NIL .OR. Empty(hContact["email"])
      Tr_MsgBox({"Kunde "+cKunde+" ist bei Tilta eingerichtet.", ;
                 "Es ist aber kein Buchhaltungs- oder Rechnungskontakt mit", ;
                 "E-Mail hinterlegt - die Abtretungsanzeige muss von Hand raus."}, ;
                "KEIN EMPFAENGER")
      RETURN .F.
   ENDIF
   cMail := AllTrim(hContact["email"])
   cName := AllTrim(hContact["name"])

   IF Tr_MsgBox({"Kunden Åber die Abtretung an die Tilta Pay GmbH informieren?", ;
                 "", ;
                 "An: "+cName+" <"+cMail+">", ;
                 "Forderungen ab Rechnungsdatum "+DToC(Date())}, ;
                "ABTRETUNGSANZEIGE",{"Nein","Ja"}) != 2
      RETURN .F.
   ENDIF

   SendMail({{cMail,cName}}, ;
            "Engelking Elektronik GmbH - Abtretung unserer Forderungen an die Tilta Pay GmbH", ;
            __TiltaAbtretungText(Date()))

RETURN .T.

/*  Die Abtretungsanzeige. Wortlaut wie die bisher von Hand verschickte
 *  Vorlage, nur das Stichdatum wechselt.                                  */
STATIC FUNCTION __TiltaAbtretungText(dAb)
   LOCAL aZ := {}
   LOCAL cOut := "", nX

   Aadd(aZ,"Sehr geehrte Damen und Herren,")
   Aadd(aZ,"")
   Aadd(aZ,"hiermit teilen wir Ihnen mit, dass die Engelking Elektronik GmbH eine")
   Aadd(aZ,"Factoring-Vereinbarung mit der Tilta Pay GmbH geschlossen hat.")
   Aadd(aZ,"")
   Aadd(aZ,"Im Rahmen dieser Vereinbarung wurden unsere Forderungen aus Rechnungen mit")
   Aadd(aZ,"einem Rechnungsdatum ab dem "+DToC(dAb)+" an die Tilta Pay GmbH abgetreten.")
   Aadd(aZ,"Wir bitten Sie daher, alle Zahlungen auf diese Rechnungen ausschlie·lich auf")
   Aadd(aZ,"folgendes Konto zu leisten:")
   Aadd(aZ,"")
   Aadd(aZ,"Kontoinhaber: Tilta Pay GmbH")
   Aadd(aZ,"IBAN: DE76 2022 0800 0029 7350 25")
   Aadd(aZ,"BIC: SXPYDEHH")
   Aadd(aZ,"Bank: Banking Circle")
   Aadd(aZ,"")
   Aadd(aZ,"Bitte beachten Sie, dass fÅr diese Rechnungen nur Zahlungen auf das")
   Aadd(aZ,"vorstehende Konto schuldbefreiende Wirkung haben. Zahlungen auf unser")
   Aadd(aZ,"bisheriges Konto kînnen insoweit nicht mehr als ErfÅllung anerkannt werden.")
   Aadd(aZ,"")
   Aadd(aZ,"Wir weisen Sie zudem darauf hin, dass bei Rechnungen ab dem o.g. Datum kein")
   Aadd(aZ,"Skontoabzug mehr mîglich ist. Die RechnungsbetrÑge sind jeweils in voller")
   Aadd(aZ,"Hîhe zur Zahlung fÑllig.")
   Aadd(aZ,"")
   Aadd(aZ,"Rechnungen mit einem Rechnungsdatum vor dem o.g. Datum begleichen Sie bitte")
   Aadd(aZ,"unverÑndert wie bisher.")
   Aadd(aZ,"")
   Aadd(aZ,"Wir bitten Sie, Ihre Unterlagen entsprechend anzupassen und diese Information")
   Aadd(aZ,"an Ihre Kreditorenbuchhaltung weiterzuleiten. Bitte geben Sie bei jeder")
   Aadd(aZ,"Zahlung weiterhin die jeweilige Rechnungsnummer an.")
   Aadd(aZ,"")
   Aadd(aZ,"Diese énderung betrifft ausschlie·lich die Abwicklung der Zahlungen. Unsere")
   Aadd(aZ,"GeschÑftsbeziehung, Ihre gewohnten Ansprechpartner sowie die vereinbarten")
   Aadd(aZ,"Konditionen unserer Zusammenarbeit bleiben im öbrigen unverÑndert bestehen.")

   FOR nX := 1 TO Len(aZ)
      cOut += aZ[nX]+Chr(13)+Chr(10)
   NEXT
RETURN cOut

/*  Zahlungsbedingung pruefen und auf Wunsch umstellen.
 *
 *  Rueckgabe .T. = die Bedingung passt (jetzt), .F. = es bleibt bei Skonto und
 *  damit bei keiner Einrichtung.
 *
 *  Geschrieben wird direkt ins Feld, nicht ueber Adresse():Save() - sonst
 *  liefe der Hook after_save_address erneut und damit diese Einrichtung ein
 *  zweites Mal. Genauso macht es after_save_address selbst, wenn es die
 *  Bedingung eines Factoring-Kunden korrigiert.
 *
 *  Im Batchmodus wird nicht gefragt: dann bleibt es beim bisherigen Weg, und
 *  tilta_setup meldet die Bedingung per Mail.                              */
STATIC FUNCTION __TiltaFixSkonto(nKuNr)
   LOCAL nRec

   ku->(dbSetOrder( 8 ))                        //str(nummer,6)
   IF ! ku->(dbSeek( Str(nKuNr,6) ))
      RETURN .F.
   ENDIF
   nRec := ku->(Recno())

   IF ! __TiltaKuHasSkonto(ku->Skonto)
      RETURN .T.
   ENDIF
   IF GetConfigValue("BATCHMODE")
      RETURN .F.
   ENDIF

   IF Tr_MsgBox({"Zahlungsbedingung: "+__TiltaSkontoText(ku->Skonto), ;
                 "Factoring ist nur ohne Skonto mîglich.", ;
                 "Jetzt umstellen auf "+__TiltaSkontoText(TILTA_NETTO_SKONTO)+"?"}, ;
                "SKONTO",{"Nein","Ja"}) != 2
      RETURN .F.
   ENDIF

   ku->(dbGoto( nRec ))
   ku->(Rec_Lock())
   ku->Skonto := TILTA_NETTO_SKONTO
   ku->(dbUnLock())

RETURN ! __TiltaKuHasSkonto(ku->Skonto)

/*  Enthaelt die Zahlungsbedingung ein Skonto? GetSkonto() liefert JEDE Stufe
 *  als {Rate,Tage} zurueck, also auch "30 Tage netto" mit Rate 0 - es zaehlt
 *  daher nur eine Stufe mit Rate ungleich 0. Dieselbe Pruefung wie in
 *  run\tilta_setup.prg, damit hier nichts repariert wird, was dort trotzdem
 *  abgelehnt wird.                                                         */
STATIC FUNCTION __TiltaKuHasSkonto(nSkonto)
   LOCAL aSk, nX

   NetUse("skontoa","ska",.F.,0)
   aSk := ska->(GetSkonto(nSkonto,Date(),Date()))
   FOR nX := 1 TO Len(aSk)
      IF ValType(aSk[nX]) == "A" .AND. Len(aSk[nX]) >= 1 .AND. aSk[nX][1] != 0
         RETURN .T.
      ENDIF
   NEXT
RETURN .F.

/*  Zahlungsbedingung als Klartext, damit in der Frage steht, was sich
 *  aendert. Die Beschreibung kommt aus skontob, Satz = Bedingung + 1.     */
STATIC FUNCTION __TiltaSkontoText(nSkonto)
   LOCAL cTxt := ""

   NetUse("skontob","skb")
   skb->(dbGoto( nSkonto+1 ))
   IF ! skb->(Eof()) .AND. ! skb->(Bof())
      cTxt := AllTrim(skb->(SKONT(0,0,skb->Ziel1,skb->Ziel2,skb->Ziel3, ;
                                  skb->Rate1,skb->Rate2,skb->Rate3,"D",.F.)))
   ENDIF
   IF Empty(cTxt)
      cTxt := "Bedingung "+LTrim(Str(nSkonto))
   ENDIF
RETURN cTxt

/*  Protokoll des Tilta-Setups: einzeilig fuer die Bewegung, mehrzeilig fuer
 *  die Mail.                                                             */
STATIC FUNCTION __TiltaLogLine(hRes)
   LOCAL cOut := "", nX
   FOR nX := 1 TO Len(hRes["log"])
      cOut += IF(Empty(cOut),""," / ")+hRes["log"][nX]
   NEXT
RETURN Left(cOut,60)

STATIC FUNCTION __TiltaLogText(hRes)
   LOCAL cOut := "", nX
   FOR nX := 1 TO Len(hRes["log"])
      cOut += hRes["log"][nX]+Chr(13)+Chr(10)
   NEXT
RETURN cOut
