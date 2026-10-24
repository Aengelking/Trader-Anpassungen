NetUse("engkund","ku",.F.,0)
ku->(dbSetOrder(2)) //group+kunde
NetUSe("enras","ras",.F.,0)
NetUse("englsre","re",.F.,0)
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
aTotal := {=>}
CLS
//ku->(dbSeek("K",.T.))
cKunde := GetBox(Pad("AQUIS",8),"Kunde")
ku->(dbSeek("K"+cKunde,.T.))
//Do While ! ku->(Eof()) .AND. ku->Group == "K" .AND. Inkey() != 27
	nPay := 0
	re->(dbSetOrder(1))
	re->(dbSeek(ku->Kunde,.T.))
	Do While ! re->(Eof()) .AND. re->Kunde == ku->Kunde
		if re->reposnr == 0
			If ! HHasKey(aTotal,re->money)
				aTotal[re->money] := {}
			Endif
			//If re->packed
				Aadd(aTotal[re->money],{"date"=>re->rechdat,"remark"=>"Rechnung "+Str(re->rechnr),"type"=>"soll","amount"=>re->poswt})
			//Endif
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
        cRemark := "Zahlung Rechnung "+Str(ras->rechnr)
        If ras->rechnr == 0
	        cRemark := ras->Bemerkung
	    Endif
        Aadd(aTotal[ras->money],{"date"=>ras->paydate,"remark"=>cRemark,"type"=>"haben","amount"=>ras->betrag})
        If ( ! Empty(ras->Skonto) )
        	Aadd(aTotal[ras->money],{"date"=>ras->paydate,"remark"=>"Skonto Rechnung "+Str(ras->rechnr),"type"=>"haben","amount"=>ras->skonto})
		Endif
		ras->(dbSkip())
	Enddo
	nX := 1
	BeginJob()
	nPrinter := NIL
	StartPrint(@nPrinter,"Debitorenkonto_"+ku->kunde,"PDF")
    oPrinter := getCurrentPrinterObject()

	nRow := 1
	Do While nX <= Len(aTotal)
		aVal := ASort(HGetValueAt(aTotal,nX),,,{|x,y| x["date"] < y["date"]})
		nY := 1
		oPrinter:Data:NewPage("A4","P",6)
		//oPrinter:Data:Box( 1, 0, 3, 20,, 100, "M" )
		//oPrinter:Data:Box( 10,  10, 100, 100,1,0, "D")
		oPrinter:Data:AtSay("Debitorenkonto: "+HB_OemToAnsi(ku->Kunde),2,1,'R')
		oPrinter:Data:AtSay("Währung: "+Currate(HGetKeyAt(aTotal,nX),"X"),3,1,'R')
		nRow := 4

		nHaben := 0
		nSoll := 0
		Do While nY <= Len(aVal)
			nRow++
			If nRow > 65
				oPrinter:Data:NewPage("A4","P",6)
				nRow := 1
			Endif
			oPrinter:Data:AtSay(DToC(aVal[nY]["date"]),nRow,0,'R')
			nPos := 35
			If aVal[nY]["type"] == "haben"
				nPos := 65
				nHaben += aVal[nY]["amount"]
			Endif
			If aVal[nY]["type"] == "soll"
				nSoll +=  aVal[nY]["amount"]
			Endif
			oPrinter:Data:RJust(Str(aVal[nY]["amount"],12,2),nRow,nPos,'R')
			oPrinter:Data:AtSay(aVal[nY]["remark"],nRow,70,'R')
			nY++
		Enddo
		nRow++
        oPrinter:Data:RJust(Replicate("-",12),nRow,35,'R')
        oPrinter:Data:RJust(Replicate("-",12),nRow,65,'R')
        nRow++
        oPrinter:Data:RJust(Str(nSoll,12,2),nRow,35,'R')
        oPrinter:Data:RJust(Str(nHaben,12,2),nRow,65,'R')
        oPrinter:Data:AtSay(Str(nSoll-nHaben,12,2),nRow,70,'R')
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