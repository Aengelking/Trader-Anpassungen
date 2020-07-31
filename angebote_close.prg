FUNCTION Angebote_Close
   LOCAL nRec
   IF TR_MsgBox("Angebote „lter als ein Jahr schlieáen?",,{"Nein","Ja"}) != 2
      RETURN NIL
   ENDIF
   NetUse("angebot","ang")
   ang->(dbSetOrder( 4 ))
   ang->(dbGoTop())
   DO WHILE ang->Bestat < 3 .AND. ! ang->(EOF())
      IF ang->Besda < Date()-365
         ang->(dbSkip())
         nRec := ang->(recno())
         ang->(dbSkip(-1))
         ? ang->Angnr,ang->Besda
         ang->(Rec_Lock())
         ang->Bestat := 3
         ang->(dbUnLock())
         ang->(dbGoto(nRec))
      ELSE
         ang->(dbSkip())
      ENDIF
   ENDDO
RETURN NIL  