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
 *  Kreditfazilit„t. Hier steht nur, was mit dem Ergebnis passiert.
 *****************************************************************************/

#define TILTA_NETTO_SKONTO  7      //14 Tage netto - wie in after_save_address

/*  Kunden bei Tilta einrichten und das Ergebnis festhalten.
 *
 *  Das Setup ist idempotent und prft selbst, was schon vorhanden ist - es
 *  braucht also keine Erkennung, wann das Kennzeichen gesetzt wurde, und ein
 *  gescheiterter Schritt wird beim n„chsten Mal nachgeholt.
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
               "Tilta-Einrichtung unvollst„ndig: "+cKunde, ;
               "Kunde: "+cKunde+" "+cName1+Chr(13)+Chr(10)+ ;
               "Buyer: "+LTrim(Str(nKuNr))+Chr(13)+Chr(10)+Chr(13)+Chr(10)+ ;
               IF(ValType(hTilta) == "H",__TiltaLogText(hTilta),"Das Setup lief auf einen Fehler."))
   ENDIF

RETURN ValType(hTilta) == "H" .AND. hTilta["ok"]

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
                 "Factoring ist nur ohne Skonto m”glich.", ;
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
