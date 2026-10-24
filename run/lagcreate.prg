PROCEDURE LagCreate
LOCAL cSpalte := Space(7)
LOCAL nBisFach := 1
LOCAL nFach
LOCAL cLager
LOCAL getlist := {}
LOCAL nForm,aForm := {"999/99!","999/!"}

NETUSE("LAGERORT","LAGO")

Head("Lagerorte anlegen")

nForm := Tr_MsgBox("Format w„hlen",,{"Normales Lager","Musterregal"})
IF LastKey() == 27
   RETURN
ENDIF
DO WHILE .T.

   @ 00,00 CLEAR

   @ 01,00 SAY "Spalte"
   @ 01,10 GET cSpalte PICTURE aForm[nForm] VALID ! Empty(cSpalte)
   @ 02,00 SAY "Bis Fach"
   @ 02,10 GET nBisFach PICTURE "999"
   READ

   IF LastKey() == 27
      RETURN
   ENDIF


   FOR nFach := 1 TO nBisFach
      cLager := Trim(cSpalte)+StrZero(nFach,3)
      IF ! lago->(dbSeek( cLager ))
         ? cLager
         lago->(Add_Rec())
         lago->Lagerort := cLager
         lago->(dbUnLock())
      ENDIF
   NEXT

   //Inkey(0)

ENDDO