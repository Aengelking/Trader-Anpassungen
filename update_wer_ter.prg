NetUse("werkauf","wer")
wer->(dbSetOrder( 1 ))

wer->(dbGoTop())

DO WHILE ! wer->(EOF())
   wer->(Rec_Lock())
   IF Empty(wer->EndDate)
      wer->StartDate := CalWd(wer->termin)
   ENDIF
   IF Empty(wer->EndDate)
      wer->EndDate := CalWd(wer->END)+5
   ENDIF
   wer->(dbUnLock())

   wer->(dbSkip())
ENDDO