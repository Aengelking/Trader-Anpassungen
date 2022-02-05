NetUse("buyprice","bpr",.F.,0)
bpr->(dbSetOrder(2))
bpr->(dbGoTop())

nCount := 0

Do While ! bpr->(Eof()) //.AND. nCount < 100
	hPrices := {=>}
	nArtnr  := bpr->Artikelnr
	Do While nArtnr == bpr->Artikelnr
		If Trim(bpr->Liefma) $ "BULGIN ITWMETAL" .AND. Empty(bpr->EndDate)
			If HHasKey(hPrices,bpr->Qty)
				nRec := bpr->(Recno())
				dStart := bpr->Startdate
				? "Preis bereits vorhanden ",bpr->Artikelnr,bpr->Qty,bpr->Price,bpr->Enddate
				bpr->(dbGoTo( hPrices[bpr->Qty] ))
				? bpr->Qty,bpr->Price,bpr->Enddate
				If bpr->Startdate < dStart
					bpr->(Rec_Lock(0))
					bpr->EndDate := dStart-1
					bpr->(dbUnLock())
				Endif
				bpr->(dbGoTo( nRec ))
				hPrices[bpr->Qty] := nRec
				nCount++
			Else
				hPrices[bpr->Qty] := bpr->(Recno())
			Endif
		Endif
		bpr->(dbSkip())
	Enddo
Enddo
//Inkey(0,128)