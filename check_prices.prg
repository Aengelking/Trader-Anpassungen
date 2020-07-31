NetUse("buyprice","bpr",.F.,0)
bpr->(dbSetOrder(2))
bpr->(dbGoTop())

Do While ! bpr->(Eof())
	Do While nArtnr == bpr->Artikelnr

		bpr->(dbSkip())
	Enddo
Enddo