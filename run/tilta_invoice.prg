/*****************************************************************************
 *  tilta_invoice.prg  -  RUN_TILTA_INVOICE
 *
 *  Rechnung von Hand bei Tilta einreichen: anlegen, Belege hochladen,
 *  Finanzierung beantragen.
 *
 *  Die Arbeit macht run\tilta_submit.prg - hier steht nur die Oberflaeche,
 *  damit Nachtlauf und Menuepunkt dieselbe Logik benutzen.
 *
 *  Normalerweise passiert das automatisch: der Nachtlauf checkresend reicht
 *  jede gepackte Factoring-Rechnung im Status FINA ein und verschickt sie
 *  danach. Dieser Menuepunkt ist fuer den Fall, dass eine Rechnung liegen
 *  geblieben ist und jemand sehen will, warum - oder dass es sofort raus soll.
 *****************************************************************************/

PROCEDURE Run_Tilta_Invoice()

LOCAL nNr := 0
LOCAL getList := {}
LOCAL oRech, oKuExtra
LOCAL hRes
LOCAL lNoFact := .F.
LOCAL nDueDays
LOCAL aMsg := {}
LOCAL nX

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
      reh->(dbSetOrder( 1 ))
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

   /*  In der Sandbox darf man auch mit einem Nicht-Factoring-Kunden testen  */
   oKuExtra := ku->(ExtraData():New(ku->Nummer))
   IF ! oKuExtra:Factoring
      IF ! __TiltaIsSandbox()
         Tr_MsgBox({"Dieser Kunde ist nicht fuer Factoring angemeldet.", ;
                    "Die Rechnung wird nicht eingereicht."})
         RETURN
      ELSEIF Tr_MsgBox({"Dieser Kunde ist nicht fuer Factoring angemeldet.", ;
                        "In der Sandbox trotzdem einreichen?"},"SANDBOX",{"Nein","Ja"}) != 2
         RETURN
      ENDIF
      lNoFact := .T.
   ENDIF

   nDueDays := sk->(GetSkontoWait(oRech:Skonto,oRech:Rechdat))
   IF Tr_MsgBox({"Rechnung "+LTrim(Str(oRech:Rechnr))+" ueber "+ ;
                 LTrim(Transform(oRech:Brutto,"@E 999,999.99"))+" EUR", ;
                 "faellig am "+DToC(oRech:Rechdat+nDueDays), ;
                 "jetzt bei Tilta einreichen und Finanzierung beantragen?"}, ;
                IF(__TiltaIsSandbox(),"SANDBOX",""),{"Nein","Ja"}) != 2
      RETURN
   ENDIF

   TxtBox("Rechnung wird eingereicht...")
   hRes := MBaseRun(Path("run\tilta_submit.prg"),{nNr,lNoFact})
   TxtClear()

   IF ValType(hRes) != "H" .OR. ! HHasKey(hRes,"log")
      Tr_MsgBox("Das Einreichen hat kein Ergebnis geliefert.","FEHLER")
      RETURN
   ENDIF

   FOR nX := 1 TO Len(hRes["log"])
      Aadd(aMsg,hRes["log"][nX])
   NEXT
   IF Len(aMsg) == 0
      Aadd(aMsg,"Keine Rueckmeldung.")
   ENDIF
   Tr_MsgBox(aMsg,IF(hRes["ok"],"OK","NICHT EINGEREICHT"))

RETURN

#include "x:\run\tilta_api.prg"
