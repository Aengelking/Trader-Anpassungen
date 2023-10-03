FUNC RESET_AUF_REMINDSTAT
   LOCAL nAbnr := 0
   LOCAL Getlist := {}

   NetUse("engauf","auf")

   Head("Erinnerung zurcksetzen")
   @ 01,00 SAY "AB-Nummer" Get nAbnr VALID nAbnr > 0 PICTURE "999999"
   READ

   IF LastKey() == 27
      RETURN .T.
   ENDIF

   IF auf->(dbSeek(Str(nAbnr,6))) .AND. Tr_MsgBox("Erinnungerung zurcksetzen?",,{"Nein","Ja"}) == 2
      DO WHILE auf->Abnr == nAbnr
         auf->(Rec_Lock())
         auf->RemindStat := ""
         auf->RemindDate := Stod("")
         auf->(dbUnLock())
         auf->(dbSkip())
      ENDDO
   ENDIF


