//NetUse("engkund","ku",.F.,0)
//ku->(dbSetOrder(2)) //group+kunde
LOCAL aEnv := SaveEnv()

NetUSe("enras","ras",.F.,0)
NetUse("englsre","re",.F.,0)

NetUse("skontoa","sk",.F.,0)
/*Do While ! ras->(Eof())
		re->(dbSetOrder(4))
		If re->(dbSeek(Str(ras->rechnr,6)))
			ras->(Rec_Lock(0))
			ras->money := re->money
			ras->rate := re->rate
			ras->(dbUnLock())
		Endif
		ras->(dbSkip())
Enddo
Inkey(0)*/
TxtBox("Daten werden gesammelt","Debitorenkonto")
LX_Start()
aTotal := {=>}
//CLS
//ku->(dbSeek("K",.T.))
//cKunde := GetBox(Pad("AQUIS",8),"Kunde")
//ku->(dbSeek("K"+cKunde,.T.))
//Do While ! ku->(Eof()) .AND. ku->Group == "K" .AND. Inkey() != 27
	nPay := 0
	re->(dbSetOrder(1))
	re->(dbSeek(ku->Kunde,.T.))
	Do While ! re->(Eof()) .AND. re->Kunde == ku->Kunde
		if re->reposnr == 0
			If ! HHasKey(aTotal,re->money)
				aTotal[re->money] := {}
			Endif
			If re->Rechdat <= SToD("20091231") .AND. re->Code == 2  //bezahlt

			Endif
			//If re->packed
				Aadd(aTotal[re->money],{"date"=>re->rechdat,"remark"=>IF(re->poswt<0,"Gutschrift","Rechnung")+" "+Str(re->rechnr),"type"=>"soll","amount"=>re->poswt,"paid"=>re->aoqty,"skonto"=>re->PaySkonto+If(re->Code>2,re->poswt-re->aoqty-re->PaySkonto,0),"vorkasse"=>.F.,"beleg"=>re->Rechnr})
			//Endif
			IF sk->(IsPrepay(re->Skonto))
			   //IF re->Rechdat >= STod("20090101")
   				ATail(aTotal[re->Money])["paid"] := 0
	  			   ATail(aTotal[re->Money])["skonto"] := 0
	  			//ENDIF
				ATail(aTotal[re->Money])["remark"] += " Vorkasse"
             	ATail(aTotal[re->Money])["vorkasse"] := .T.
			ENDIF
			/*aTotal[re->money][4] += re->poswt-re->aoqty*/
		Endif
		re->(dbSkip())
	Enddo
	ras->(dbSetOrder(1))
	ras->(dbSeek(ku->kunde,.T.))
	Do While ! ras->(Eof()) .AND. ras->Kunde == ku->Kunde
		re->(dbSetOrder(4))
		re->(dbSeek(Str(ras->rechnr,6)))
		If ! HHasKey(aTotal,ras->money)
			aTotal[ras->money] := {}
		Endif
		//aTotal[re->money][2] += ras->Betrag
		cRemark := ""
		If ras->rechnr != 0
			cRemark := "Zahlung Rechnung "+Str(ras->rechnr)+" "
		Endif
		If ras->Rechnr == 0
			cRemark += ras->Bemerkung
			Aadd(aTotal[ras->money],{"date"=>ras->paydate,"remark"=>cRemark,"type"=>"haben","amount"=>0,"paid"=>ras->betrag,"skonto"=>ras->skonto,"vorkasse"=>.T.,"beleg"=>0})
/*			If ( ! Empty(ras->Skonto) )
				Aadd(aTotal[ras->money],{"date"=>ras->paydate,"remark"=>"Skonto Rechnung "+Str(ras->rechnr),"type"=>"haben","amount"=>0,"paid"=>ras->skonto,"skonto"=>0})
			Endif*/
		Endif
		ras->(dbSkip())
	Enddo
	nX := 1
	TxtClear()

	BeginJob()
	nPrinter := NIL
	StartPrint(@nPrinter,"Debitorenkonto_"+ku->kunde,"PDF")
	oPdf := getCurrentPrinterObject():Data

	nRow := 1
	Do While nX <= Len(aTotal)
		aVal := ASort(HGetValueAt(aTotal,nX),,,{|x,y| x["date"] < y["date"]})
		nY := 1
		oPdf:NewPage("A4","P",6)
		//oPdf:Box( 1, 0, 3, 20,, 100, "M" )
		//oPdf:Box( 10,  10, 100, 100,1,0, "D")
		oPdf:AtSay("Debitorenkonto: "+LTrim(Str(ku->Nummer)),2,1,'R')
		oPdf:AtSay("Matchcode: "+HB_OemToAnsi(ku->Kunde),3,1,'R')
		oPdf:AtSay("Währung: "+Currate(HGetKeyAt(aTotal,nX),"X"),4,1,'R')
		oPdf:NewLine()
		oPdf:AtSay("Datum",,0)
		oPdf:RJust("Betrag",,35)
		oPdf:RJust("Zahlung",,65)
		oPdf:RJust("Skonto",,95)
		oPdf:RJust("Offen",,125)
		nRow := 5

		nHaben   := 0
		nSoll    := 0
		nSkonto  := 0

		nYear    := 0
		nYSoll   := 0
		nYHaben  := 0
		nYSkonto := 0

		Do While nY <= Len(aVal)
			If nYear == 0
				nYear := Year(aVal[nY]["date"])
			Endif
			nRow++
			If nRow > 65
				oPdf:NewPage("A4","P",6)
				nRow := 1
			Endif
			oPdf:AtSay(DToC(aVal[nY]["date"]),nRow,0,'R')
			nPos := 35
//			If aVal[nY]["type"] == "haben"
				nPos := 65
				nHaben  += aVal[nY]["paid"]
				nYHaben += aVal[nY]["paid"]
//			Endif
//			If aVal[nY]["type"] == "soll"
				nSoll  +=  aVal[nY]["amount"]
				nYSoll +=  aVal[nY]["amount"]
//			Endif
			nSkonto  += aVal[nY]["skonto"]
			nYSkonto += aVal[nY]["skonto"]

			oPdf:RJust(Str(aVal[nY]["amount"],12,2),nRow,35,'R')
			//oPdf:RJust(Str(aVal[nY]["paid"],12,2),nRow,65,'R')
			 oPdf:RJust(Str(aVal[nY]["skonto"],12,2),nRow,95,'R')
			oPdf:RJust(Str(aVal[nY]["amount"]-aVal[nY]["paid"]-aVal[nY]["skonto"],12,2),nRow,125,'R')
			oPdf:AtSay(HB_OemToAnsi(aVal[nY]["remark"]),nRow,130,'R')

			IF ! aVal[nY]["vorkasse"] .AND. aVal[nY]["amount"] != 0
				hOP := LX_GetOffenerPosten(ku->Nummer,aVal[nY]["beleg"],.T.)
				IF Len(hOp) == 0
                 	 nRow++
					 oPdf:AtSay(LX_GetErrorMessage(),nRow,35,'R')
				ELSE
					IF Round(hOP:nRest,2) != Round(aVal[nY]["amount"]-aVal[nY]["paid"]-aVal[nY]["skonto"],2)
	                 	 nRow++
						 oPdf:AtSay("Abweichung Lexware "+LTrim(Str(aVal[nY]["amount"]-aVal[nY]["paid"]-aVal[nY]["skonto"]-hOp:nRest)),nRow,0,'R')
	            ENDIF

	            hZahl := NIL
               FOR EACH hZahl IN hOp:aZahlungen
                  nRow++
                  oPdf:AtSay(DToC(hZahl:dDatum)+" "+hZahl:Text,nRow,130,'R')
                  oPdf:RJust(Str(hZahl:nBetrag,12,2),nRow,65,'R')
					NEXT
				ENDIF
         ELSEIF aVal[nY]["vorkasse"] .AND. aVal[nY]["paid"] != 0
            oPdf:RJust(Str(aVal[nY]["paid"],12,2),nRow,65,'R')
         ENDIF

			nY++


			If nY == Len(aVal)+1 .OR. nYear !=  Year(aVal[nY]["date"])
				nRow++
				oPdf:RJust(Replicate("-",12),nRow,35,'R')
				oPdf:RJust(Replicate("-",12),nRow,65,'R')
				oPdf:RJust(Replicate("-",12),nRow,95,'R')
				oPdf:RJust(Replicate("-",12),nRow,125,'R')

                		nRow++
				oPdf:AtSay(Str(nYear,4),nRow,0,'R')
				oPdf:RJust(Str(nYSoll,12,2),nRow,35,'R')
				oPdf:RJust(Str(nYHaben,12,2),nRow,65,'R')
				oPdf:RJust(Str(nYSkonto,12,2),nRow,95,'R')
				oPdf:RJust(Str(nYSoll-nYHaben-nYSkonto,12,2),nRow,125,'R')

				nRow++

				If nY <= Len(aVal)
					nYear := Year(aVal[nY]["date"])
					nYSoll   := 0
					nYHaben  := 0
					nYSkonto := 0
				Endif
			Endif


		Enddo
		nRow +=2
			If nRow > 65
				oPdf:NewPage("A4","P",6)
				nRow := 1
			Endif
		
		oPdf:RJust(Replicate("=",7),nRow,35,'R')
		oPdf:RJust(Replicate("=",7),nRow,65,'R')
		oPdf:RJust(Replicate("=",7),nRow,95,'R')
		oPdf:RJust(Replicate("=",7),nRow,125,'R')
		nRow++
		oPdf:RJust(Str(nSoll,12,2),nRow,35,'R')
		oPdf:RJust(Str(nHaben,12,2),nRow,65,'R')
		oPdf:RJust(Str(nSkonto,12,2),nRow,95,'R')
		oPdf:RJust(Str(nSoll-nHaben-nSkonto,12,2),nRow,125,'R')


		nX++
	Enddo
	CopyPrint()
    EndJob()
	/*aTurn := GetCustomerTurnover(ku->Kunde)
	If aTurn["open"] !=
		? ku->Kunde,Str(aTurn["total"],12,2),Str(nPay,12,2),Str(aTurn["total"]-nPay,12,2),Str(aTurn["open"],12,2)
	Endif
	ku->(dbSkip()) */
//Enddo

//Inkey(0)
RestEnv(aEnv,.T.)
