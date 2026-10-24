PROC RUN_PRINT_RE   
   LOCAL getlist := {}
   LOCAL nRe,nVonRe := 0,nBisRe := 0
   LOCAL nPrinter
   NetUse("me","me")
   NetUse("englsre","re")

   Head("Rechnungen drucken")
   @ 01,00 SAY "Ab  Rechnr" GET nVonRe PICTURE "999999" VALID {|| 
      IF nBisRE == 0
         nBisRe := nVonRe
      ENDIF
      RETURN .T.
   }
   @ 02,00 SAY "Bis Rechnr" GET nBisRe PICTURE "999999" VALID nBisRe >= nVonRe
   READ
   IF LastKey() == 27
      RETURN
   ENDIF
   SelectPrint(@nPrinter,,"PDF")
   SetStdPrinter(1,nPrinter)
   SetConfigValue("BATCHMODE",.T.)
   SetPrinterMethodType(1)
   nRe := NIL
   Head("Rechnungen drucken")
   FOR nRe := nBisRe TO nVonRe STEP -1
   //FOR nRe := 47920 TO 48010
      ? nRe
      re->(dbSetOrder( 4 ))
      IF ! re->(dbSeek( Str(nRe,6) ))
         ?? " nicht vorhanden."
         EXIT
      ELSEIF ! re->Packed
         ?? " nicht versandt - wird nicht gedruckt"
      ELSE
         engrepr(,3,nRe,.F.,1,0)
         ? nRE,"gedruckt"
      ENDIF
      IF Inkey() == 27
         EXIT
      ENDIF
   NEXT
   UnSetStdPrinter(1)
   SetPrinterMethodType(0)
   SetConfigValue("BATCHMODE",.F.)
   ? "abgeschlossen"
   Sinkey(0)