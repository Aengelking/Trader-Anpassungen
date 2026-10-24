FUNCTION RUN_PRINT_TEXTFILE(cFile,nL,nC)
   LOCAL oPrinter := GetCurrentPrinterObject()   
   LOCAL cText := MemoRead(cFile)
   LOCAL nLineLength := 200
   LOCAL nLen := MlCount(cText,nLineLength)   
   LOCAL nX
   LOCAL nPrinted := 0
   LOCAL cLine

   FOR nX := 1 To nLen
      cLine := MemoLine(cText,nLineLength,nX)
      IF oPrinter != NIL .AND. oPrinter:Type == "PDF"            
            IF Conv( cLine, oPrinter )
               oPrinter:Data:ReportLine++
               oPrinter:Data:ReportCol := 0            
            ENDIF
      ELSE
         cLine := Left(Conv(cLine),nLineLength)
         If ! Empty(cLine)
            @ nL+nPrinted,nC SAY cLine
            nPrinted++
         Endif
      ENDIF
   NEXT