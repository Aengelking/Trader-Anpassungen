NetUse("werkauf","wer")
NetUse("artikel","art")
art->(dbSetOrder( 2 ))
DO WHILE ! wer->(Eof())
   IF art->(dbSeek( Str(wer->Artno,6) ))
      wer->(Rec_Lock())
      wer->Matchcode := art->Matchcode
      wer->(dbUnLock())
   ENDIF
   wer->(dbSkip())
ENDDO