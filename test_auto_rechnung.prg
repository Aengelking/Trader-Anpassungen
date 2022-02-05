PROC RUN_TEST_AUTO_RECHNUNG
   LOCAL nAufnr := 0
   LOCAL getlist := {}

   DO WHILE .T.
      Head("Test automatische Rechnungserstellung")
      @ 01,00 SAY "AB-Nummer" GET nAufnr PICTURE "@K999999" VALID ! Empty(nAufnr) 
      READ
      IF LastKey() == 27
         EXIT
      ENDIF
      SetConfigValue("BATCHMODE",.T.)
      engreab(nAufnr)
      SetConfigValue("BATCHMODE",.F.)
      
   ENDDO