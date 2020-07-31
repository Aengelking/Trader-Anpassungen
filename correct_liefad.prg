NetUse("engkund","ku")
ku->(dbGoTop())
DO WHILE ! ku->(EOF())
   IF ku->ReliefAdr < 0 .OR. ku->StdLiefAdr < 0
      ku->(Rec_Lock())
      IF ku->ReliefAdr < 0
         ku->ReliefAdr := 0
      ENDIF
      IF ku->StdLiefAdr < 0
         ku->StdLiefAdr := 0
      ENDIF
      ku->(dbUnLock())
   ENDIF
   ku->(dbSkip())
ENDDO