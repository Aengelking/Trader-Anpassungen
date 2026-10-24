PROC PRINT_MATNW()
   LOCAL oEK:=ku->(ExtraData():New(ku->Nummer))
   LOCAL oEA := art->(ExtraData():New(art->Artikelnr))
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
            frm->(Endpage(,,,,oPrinter:Data:ReportLine+1+nLen+1 ,.T.))            
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
      ELSEIF ! oEA:Get("NOMAT")
         IF Tr_Getini(28) == 9
            //Alert("File "+cFile+" not found for Materialnachweis")
         ENDIF
         SendMessage("Qualitaet | Materialnachweis fehlt","Materialnachweis fehlt",StrTran("Hallo,\n\nfr die Artikelnummer "+Str(art->Artikelnr)+" wurde kein Materialnachweis gefunden. Bitte diesen erstellen und im Verzeichnis "+Path("config\texts\parts\")+" ablegen.\n\nVielen Dank!","\n","<br>"))         
      ENDIF
   ENDIF      

  RETURN