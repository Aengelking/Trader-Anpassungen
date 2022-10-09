PROC RUN_PRINT_RE
   LOCAL aRe
   NetUse("me","me")
   aRe := {59706}
   //SetConfigValue("BATCHMODE",.T.)
   //SetPrinterMethodType(1)
   nRe := NIL
   Head("Rechnungen drucken")
   FOR EACH nRe IN aRe
   //FOR nRe := 47920 TO 48010
      @ 01,00 SAY nRe      
      engrepr(,3,nRe,.F.,1,0)
   NEXT
   SetPrinterMethodType(0)
   SetConfigValue("BATCHMODE",.F.)