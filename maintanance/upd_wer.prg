NetUse("werkauf","wer")
SET FILTER TO wer->Besnr != 0 .AND. wer->BesPos == 0
wer->(dbGoTop())
DO WHILE ! wer->(EOF())
   wer->(Rec_Lock())
   wer->BesPos := 1
   wer->(dbUnLock())
   wer->(dbSkip())
ENDDO   