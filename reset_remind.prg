NetUse("engauf","auf")
CLS
DO WHILE LastKey() != 27
   auf->(dbSeek( Str(46738,6) ))
   DO WHILE auf->Abnr == 46738
      auf->(Rec_Lock())
      auf->RemindDate := StoD("20170319")
      auf->(dbUnLock())
      auf->(dbSkip())
   ENDDO
   ? "RESET"
   Inkey(0,128)
ENDDO