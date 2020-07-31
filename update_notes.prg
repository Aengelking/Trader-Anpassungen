NetUse("notes","nts",.F.,0)
nts->(dbSetOrder( 2 ))
nts->(dbGoTop())
Do While ! nts->(Eof())
	If /*Empty(nts->Betreff) .AND. */ At("Angebot",nts->Note) == 1
		nNr := Val(SubStr(nts->Note,8,7))
		? nts->Matchcode,nts->Date,nNr
		nts->(Rec_Lock(0))
		nts->Betreff := "ANG"
		nts->Nummer  := nNr
		nts->(dbUnLock())
	Endif
	nts->(dbSkip())
Enddo
Inkey(0,128)


