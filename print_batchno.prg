FUNCTION RUN_PRINT_BATCHNO(lRech,oPrinter,cLang)
   LOCAL lMulti := .F.,nCount := 0
   LOCAL lPdf := .T.,cText := ""
   LOCAL cFilter,oExtra
   LOCAL nMarginOld
   LOCAL cAli,bWhile
   #command PRINT(<text>) => IF(!lPdf,cText+=<text>,__PDFPRINT(oPrinter,<text>))
   IF cLang != "E"
      cLang := "D"
   ENDIF
   IF oPrinter == NIL .OR. oPrinter:Type != "PDF" //only works with PDF printers
      lPDF := .F.
   ENDIF

   IF lRech
      NetUse("lagrech","lagr",.F.,0)
      cAli := "lagr"
      IF ! lagr->(dbSeek(STR(re->Rechnr,6)+STR(re->rePosNr,3)+STR(re->AbNr,6)))  //reposnr depends on abnr
         RETURN ""
      ENDIF
      bWhile := {|| lagr->RechNr == re->Rechnr .AND. lagr->RePosNr == re->RePosNr.AND. lagr->ABNR == re->AbNr }
   ELSE
      NetUse("lagent","lage")
      cAli := "lage"      
      IF ! lage->(dbSeek(STR(lne->Nummer,6)+STR(lne->Pos,3)))
         RETURN ""
      ENDIF
      bWhile := {|| lage->Nummer == lne->Nummer .AND. lage->Pos == lne->Pos }
   ENDIF
      
   (cAli)->(dbSkip())
   IF Eval(bWhile)
      lMulti := .T.
   ENDIF
   (cAli)->(dbSkip(-1))
   IF cLang == "D"
      PRINT("Chargennummer"+IF(lMulti,"n","")+": ")
   ELSE
      PRINT("Batch number"+IF(lMulti,"s","")+": ")
   ENDIF
   IF lPdf
      oPrinter:Data:ReportCol := 30
      nMarginOld := oPrinter:Data:PDFLeft   
   ENDIF
   Do While Eval(bWhile)
      PRINT(IF(nCount>0,", ","")+HB_OemToAnsi(Trim((cAli)->Batch)))
      IF lMulti
         PRINT(" ("+LTrim(Transform((cAli)->LagerMenge,Me(art->Me)))+" "+art->Me+")")
      ENDIF
      GotoRechAddress()
      oExtra := ku->(ExtraData():New(ku->Nummer))
      IF art->Bezug >= 5 .AND. oExtra:PrintDC .AND. ! Empty((cAli)->Batch) //only if the customer explicitly wants the date code printed
         NetUse("engabg","abg")
         abg->(dbSetOrder( 1 ))            
         cFilter := 'Trim(buart) == "WA" .AND. besnr == '+Trim((cAli)->Batch)
         abg->(dbSetFilter({|| abg->(&(cFilter)) },cFilter))
         abg->(dbSeek( Descend(art->Matchcode), .T. ))
         IF ! abg->(EOF()) .AND. abg->Matchcode == art->Matchcode
            PRINT(" Date code: "+NiceWeek(CWeek(abg->Datum)))
         ENDIF
         abg->(dbClearFilter())
      ENDIF
      //oPrinter:Data:AtSay(HB_OemToAnsi(Transform(nMenge,Me(art->me))),,oPrinter:Data:REPORTCOL+20)
      //oPrinter:Data:NewLine()  	  	   
      (cAli)->(DBSKIP())
      nCount++
   Enddo
   IF lPdf
      oPrinter:Data:PDFLeft := nMarginOld
      oPrinter:Data:NewLine()
   ELSE
      cText += ";"
   ENDIF
   

RETURN IF(lPdf,"",cText)

STATIC FUNCTION __PDFPRINT(oPrinter,cText)
   IF oPrinter:Data:ReportCol+Len(cText) > 200
      oPrinter:Data:NewLine()
      oPrinter:Data:PDFLeft := 49   
      IF AT(",",cText) == 1
         cText := Ltrim(SubStr(cText,2))
      ENDIF
   ENDIF
   oPrinter:Data:AtSay(cText)   
RETURN NIL
