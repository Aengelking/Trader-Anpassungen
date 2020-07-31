LOCAL getlist := {}
LOCAL nAng := 0
Head(t("Angebot schließen"))

NetUse("angebot","ang")
ang->(dbSetOrder( 1 ))

DO WHILE .T.
   @ 01,00 SAY "Nummer" GET nAng PICTURE "999999" VALID nAng != 0 .AND. ang->(dbSeek(Str(nAng,6)))
   READ
   IF LastKey() == 27
      EXIT
   ENDIF

   IF Tr_MsgBox(t("Angebot Nr. "+LTrim(Str(ang->Angnr))+" an "+Trim(ang->Kundma)+" schließen?"),,{"Nein","Ja"}) == 2

      ang->(dbSeek(Str(nAng,6)))
      DO WHILE ang->Angnr == nAng .AND. ! ang->(EOF())
         IF ang->Bestat < 3
            ang->(Rec_Lock())
            ang->Bestat := 3
            ang->(dbUnLock())
            ang->(dbSkip())
         ENDIF
      ENDDO
   ENDIF
ENDDO