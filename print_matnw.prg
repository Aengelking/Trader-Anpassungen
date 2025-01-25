PROC PRINT_MATNW()
   LOCAL oEK:=ku->(ExtraData():New(ku->Nummer))
   LOCAL oPrinter
   LOCAL cFile
   LOCAL cText
   LOCAL nLineLength := 200
   LOCAL nLen
   
   IF oEK:Get("EMPB-MAT")
      cFile := Path("config\texts\parts\MN_"+LTrim(Str(art->Artikelnr))+"_"+CharRepl("/\?",Trim(art->Zeichnung),"_")+"_"+CharRepl("/\?",Trim(art->ZeichIndex),"_"))+".txt"
      
      IF File(cFile)         

         oPrinter := GetCurrentPrinterObject()   
         cText := MemoRead(cFile)         
         nLen := MlCount(cText,nLineLength)   

         IF oPrinter:Data:ReportLine+1+nLen+1 >= frm->par11 //if it does not fit on the current page            
            frm->(Endpage(,,,,,.T.))
         ENDIF
   
         IF oPrinter != NIL .AND. oPrinter:Type == "PDF"            
            Conv( "\5\Materialnachweis", oPrinter )
            oPrinter:Data:ReportLine++
            oPrinter:Data:ReportCol := 0            
            
         ENDIF
         

         FOR nX := 1 To nLen
            cLine := MemoLine(cText,nLineLength,nX)            
            IF Conv( cLine, oPrinter )
               oPrinter:Data:ReportLine++
               oPrinter:Data:ReportCol := 0            
            ENDIF
         NEXT
                  
         Conv("\arial,10\")
      ELSE
         Alert("File not found")
      ENDIF
   ENDIF      

  RETURN