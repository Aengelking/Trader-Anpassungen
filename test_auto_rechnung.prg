PROC RUN_TEST_AUTO_RECHNUNG
   LOCAL nAufnr := 0
   LOCAL getlist := {}   

   NetUse("engkund","ku")

   DO WHILE .T.
      Head("Test automatische Rechnungserstellung")
      @ 01,00 SAY "AB-Nummer" GET nAufnr PICTURE "999999" VALID ! Empty(nAufnr) 
      READ
      IF LastKey() == 27
         EXIT
      ENDIF
      SetConfigValue("BATCHMODE",.T.)      
      lMessage := HOOK("ON_AUF_READY",{nAufnr,.F.})
      SetConfigValue("BATCHMODE",.F.)
      
      IF lMessage
         Alert("Keine Automatik")
      ENDIF

      //inventur
      //kreditlimit
   ENDDO

   