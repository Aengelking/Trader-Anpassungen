FUNCTION RUN_PRINT_BATCHNO(lRech,oPrinter)
   LOCAL lMulti := .F.,nCount := 0
   LOCAL lPdf := .T.,cText := ""
   LOCAL cFilter,oExtra
   LOCAL nMarginOld
   #command PRINT(<text>) => IF(!lPdf,cText+=<text>,__PDFPRINT(oPrinter,<text>))
   IF oPrinter == NIL .OR. oPrinter:Type != "PDF" //only works with PDF printers
      lPDF := .F.
   ENDIF

   IF lRech
      NetUse("lagrech","lagr",.F.,0)
      lagr->(dbSeek(STR(re->Rechnr,6)+STR(re->rePosNr,3)+STR(re->AbNr,6)))  //reposnr depends on abnr
      lagr->(dbSkip())
      IF lagr->RechNr == re->Rechnr .AND. lagr->RePosNr == re->RePosNr.AND. lagr->ABNR == re->AbNr
         lMulti := .T.
      ENDIF
      lagr->(dbSkip(-1))
      PRINT("Chargennummer"+IF(lMulti,"n","")+": ")
      IF lPdf
         oPrinter:Data:ReportCol := 30
         nMarginOld := oPrinter:Data:PDFLeft   
      ENDIF
      Do While lagr->RechNr == re->Rechnr .AND. lagr->RePosNr == re->RePosNr.AND. lagr->ABNR == re->AbNr         
         PRINT(IF(nCount>0,", ","")+HB_OemToAnsi(Trim(lagr->Batch)))
         IF lMulti
            PRINT(" ("+LTrim(Transform(lagr->LagerMenge,Me(art->Me)))+" "+art->Me+")")
         ENDIF
         GotoRechAddress()
         oExtra := ku->(ExtraData():New(ku->Nummer))
         IF art->Bezug >= 5 .AND. oExtra:PrintDC .AND. ! Empty(lagr->Batch) //only if the customer explicitly wants the date code printed
            NetUse("engabg","abg")
            abg->(dbSetOrder( 1 ))            
            cFilter := 'Trim(buart) == "WA" .AND. besnr == '+Trim(lagr->Batch)
            abg->(dbSetFilter({|| abg->(&(cFilter)) },cFilter))
            abg->(dbSeek( Descend(art->Matchcode), .T. ))
            IF ! abg->(EOF()) .AND. abg->Matchcode == art->Matchcode
               PRINT(" Date code: "+NiceWeek(CWeek(abg->Datum)))
            ENDIF
            abg->(dbClearFilter())
         ENDIF
        //oPrinter:Data:AtSay(HB_OemToAnsi(Transform(nMenge,Me(art->me))),,oPrinter:Data:REPORTCOL+20)
         //oPrinter:Data:NewLine()  	  	   
         lagr->(DBSKIP())
         nCount++
      Enddo
      IF lPdf
         oPrinter:Data:PDFLeft := nMarginOld
         oPrinter:Data:NewLine()
      ELSE
         cText += ";"
      ENDIF
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
