

NetUse("buyprice","bpr",.T.,0)
NetUse("artlief","ali",.F.,0)

/*   //marked out to avoid harm
bpr->(__dbZap())
ali->(dbGoTop())
Do While ! ali->(eof())
	If ! Empty(ali->lastprice)
		bpr->(Add_rec(0))
		bpr->Artikelnr 	:= ali->Artikelnr
		bpr->Liefma		:= ali->Kunde
		bpr->Price 		:= ali->lastprice
		bpr->Qty		:= ali->lastmenge
		bpr->startdate 	:= ali->lastdate
		bpr->PE			:= ali->Pe
		bpr->(dbUnLock())
		? ali->Artikelnr,ali->lastmenge,ali->lastprice
	Endif
	ali->(dbSkip())
Enddo
*/


//remove duplicates
ali->(dbGoTop())
nLastArt := 0
Do While ! ali->(Eof())
	If nLastArt == ali->Artikelnr
		ali->(Rec_Lock())
		ali->(dbDelete())
		ali->(dbUnLock())
	Endif
	nLastArt := ali->Artikelnr
	ali->(dbSkip())
Enddo