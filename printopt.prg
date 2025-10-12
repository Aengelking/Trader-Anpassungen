PROCEDURE RUN_PRINTOPT
//PRINT A LIST OF ALL AVAILBLE OPTIONS

LOCAL cBase
LOCAL oPdf
LOCAL aSizes,aPageS,aOrient
LOCAL nSize
LOCAL nTab,nLastTab,nLength
LOCAL nCol,nColWidth
LOCAL nPage,nXMargin,nExLen
LOCAL nTWidth,nLines
LOCAL nNextPos,nPosX,nPos,nR,nC
LOCAL cString
LOCAL nPageCount
LOCAL cExample
LOCAL nRow

MEMVAR c_four,c_one

NETUSE("engkund","ku",.F.,0)

NetUse("artikel","art",.F.,0)
art->(dbSetOrder(1))

NETUSE("option","op",.F.,0)
NetUse("opttab","opt")

cBase := GetBox(Space(24),"GERŽTETYP")

If LastKey() != 27 .AND. ! art->(dbSeek(cBase))
	TR_MsgBox("Artikel nich gefunden")
Else
	op->(dbSeek(cBase))
	If op->Model != op->Model1 .AND. ! Empty(op->Model1)
		//cSModel := op->Model
	    //lFlag   := .T.
	    cBase := op->model1
	    op->(dbSeek(cBase))
	Endif
	if ! op->(Found())
		TR_MsgBox("Variant nicht angelegt")
	Else
		SetColor(c_four)
		aSizes  := {"A4 hoch","A4 quer","A3 hoch","A3 quer","A2 hoch","A2 quer"}
		aPageS  := {"A4","A4","A3","A3","A2","A2"}
		aOrient := {"P","L","P","L","P","L"}
		nSize := AMenu(aSizes)
      IF LastKey() == 27 .OR. nSize == 0
         RETURN
      ENDIF
		SetColor(c_one)
//		nCopies := GetBox(1,"Kopien")
		BeginJob()
		StartPrint(,"VAR","PDF")
		oPdf := GetCurrentPrinterObject():Data
//		SET PRINTER ON
//		SET DEVICE TO PRINTER
		oPdf:NewPage(aPageS[nSize],aOrient[nSize])

		oPdf:SetFont("Helvetica",,14)
		oPdf:AtSay("GERÄTETYP: "+cBase+" "+art->artikel,1,0,'R')

		nTab := 1
		nLastTab := 1
		cExample := Trim(cBase)
		while nTab <= 99 .AND. op->(dbSeek(cBase+Str(nTab,2)))
			opt->(dbSeek(cBase+Str(nTab,2)))
			nLastTab := nTab
			cExample += Pad(op->TabKey,opt->Length)
			nTab++
		enddo
		oPdf:NewLine(2)
		oPdf:SetFont("Helvetica",,10)
		oPdf:AtSay("Beispiel:")

		oPdf:SetFont("Helvetica",,24)
		oPdf:NewLine(2)
		oPdf:AtSay(cExample)

		oPdf:SetFont("Helvetica",,8)
		nTab := 1
		nCol := 1
		nLength := Len(Trim(cBase))
		
		nXMargin := oPdf:M2X(oPdf:PDFLEFT)
		nExLen := oPdf:M2X(oPdf:Len(Trim(cExample)))+5

                //oPdf:Box(  20, nXMargin,200,nXMargin+(oPdf:PageX-nXMargin*2-9.0) , 1, 0, "D", "000000" )

		nColWidth := (oPdf:PageX-nXMargin*2-9.0)/(nLastTab) //

	        nColWidth := Max(nColWidth,nExLen)

	        nPageCount := (nColWidth*(nLastTab))/(oPdf:PageX-nXMargin*2-9.0)
		If nPageCount > 1 //more than one page, spreed evenly
	        	//Alert("Pages: "+LTrim(Str(Int(nPageCount)+1)))
	        	//Alert("Width: "+LTrim(Str(nColWidth))+" new: "+LTrim(Str(((oPdf:PageX-nXMargin*2-9.0)*(Int(nPageCount)+1))/(nLastTab))))
			nColWidth := (oPdf:PageX-nXMargin*2-9.0)/(Int(nLastTab/(Int(nPageCount)+1))+If(Mod(nLastTab,(Int(nPageCount)+1))>0,1,0))
	        Endif

	        nColWidth := Max(nColWidth,nExLen)
	        //oPdf:M2C())-oPDF:PDFLEFT+3)
		//Alert(oPdf:M2C(oPdf:Len(Trim(cExample))))

		oPdf:NewLine(2)

		nRow := oPdf:ReportLine
		nPage := oPdf:ReportPage

		while nTab <= 99 .AND. op->(dbSeek(cBase+Str(nTab,2)))

			nNextPos := nXMargin+nColWidth*(nCol-1)                     

			If nNextPos+nColWidth > oPdf:PageX-nXMargin /*oPdf:ReportWidth-oPdf:PDFLEFT*2-5*/ .OR. oPdf:ReportPage != nPage   //this col does not fit onto the page or options have flown onto the next page, so we start on a fresh page				
				nCol := 1
				oPdf:NewPage()
			Endif
         nPosX := nXMargin+nColWidth*(nCol-1)
         nPos := oPdf:X2C(nPosX)

			//oPdf:Box(  100, nPosX,400,nPosX+nColWidth, 1, 0, "D", "000000" )

			oPdf:ReportLine := nRow

			oPdf:NewLine()

         op->(dbSeek(cBase+Str(nTab,2)))
         opt->(dbSeek(cBase+Str(nTab,2)))

			cString := SubStr(cExample,0,nLength)
			nC := nPosX
			nR := oPdf:R2D(oPdf:ReportLine)
			oPdf:AtSay(cString,nR,nPosX,'X')
			oPdf:Bold()
			nC += oPdf:M2X(oPdf:Len(cString))
			cString := Pad(op->TabKey,opt->length)
			oPdf:AtSay(cString,nR,nC,'X')
			oPdf:Normal()
			nC += oPdf:M2X(oPdf:Len(cString))			
         oPdf:AtSay(SubStr(cExample,nLength+opt->length+1),nR,nC,'X') //,,nPos+nLength+op->length+1)

			//oPdf:NewLine()
            
			nTWidth := oPdf:X2M(nColWidth-oPdf:M2X(oPdf:Len(Replicate('X',opt->Length+2))))-5
			If ! Empty(opt->Funktion)
			   nLines := oPdf:Text(Trim(HB_OemToAnsi(opt->Funktion)),oPDF:ReportLine-1,oPdf:X2M(nPosX)+.5,nTWidth,,1,'-')
			Endif

			oPdf:NewLine(1) //nLines-If(nLines>1,1,0))

			nPage := oPdf:ReportPage

			nLength += opt->length
			while op->Table == nTab .AND. op->Model == cBase
				oPdf:NewLine()
				oPdf:AtSay(Pad(op->TabKey,opt->Length)+": ",oPdf:R2D(oPdf:ReportLine+1),nPosX,'X')

            If ! Empty(op->Descript)
 				   nLines := oPdf:Text(Trim(HB_OemToAnsi(op->Descript)),oPDF:ReportLine-1,oPdf:X2M(nPosX)+.5+oPdf:Len(Replicate('X',opt->Length+2)),nTWidth,,1,'-')
				Endif
				oPdf:NewLine(1) //nLines-If(nLines>1,1,0))

				op->(dbSkip())
			enddo

			nTab++
			nCol++
		enddo

		EndJob()
		CopyPrint(1)
	Endif
Endif