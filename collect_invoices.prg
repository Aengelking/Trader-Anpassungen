NetUse("engrech","rech",.F.,0)
NetUse("engabg","abg",.F.,0)
NetUse("artikel","art",.F.,0)


If Tr_MsgBox("This might delete some records. Are you sure?",,{"No","YES"}) != 2
	Return
Endif
If ! NetUse("rechpos","rpos",.T.,5)
	TR_MsgBox("Cannot open file in exclusive mode")
	Return
Endif
ZAP

abg->(dbSetOrder( 4 ))
abg->(dbGoTop())
//abg->(dbSeek( "BULGIN" ))
CLS

hInvoices := {=>}

Do While ! abg->(Eof())
	If Trim(abg->BuArt) == "RE" .AND. ! Empty(abg->Liefma)
		@ 01,00 SAY abg->Liefma+abg->Beleg
		If ! HHasKey(hInvoices,abg->Liefma+abg->Beleg)
			hInvoices[abg->Liefma+abg->Beleg] := {}
		Endif
        	Aadd(hInvoices[abg->Liefma+abg->Beleg],{"matchcode"=>abg->Matchcode,"menge"=>abg->Menge,"preis"=>abg->Preis,"pe"=>abg->Pe,"besnr"=>abg->Besnr,"pos"=>abg->bespos})
	Endif
	abg->(dbSkip())
Enddo

rech->(dbSetOrder( 2 ))  //liefma+rechnr
nX := 1

aKey := HGetKeys(hInvoices)
ASort(aKey)

Do While nX <= Len(aKey)
	rech->(dbSeek( aKey[nX] ))
	aData := hInvoices[aKey[nX]]
	//? rech->Liefma,rech->Rechnr,rech->rechdat,rech->gramt
	@ 24,00 SAY LTrim(Str(nX))+"/"+LTrim(Str(Len(aKey)))
	nD := 1
	Do While nD <= Len(aData)
		art->(dbSeek( aData[nD]["matchcode"] ))

		rpos->(Add_Rec(0))
		rpos->Liefma := rech->Liefma
		rpos->Beleg  := rech->Rechnr
		rpos->belegpos  := nD
		rpos->DATE      := rech->RechDat

		rpos->besnr     := aData[nD]["besnr"]
		rpos->posnr     := aData[nD]["pos"]
		rpos->matchcode := art->Matchcode
		rpos->artikelnr := art->Artikelnr
		rpos->artikel   := art->Artikel
		rpos->ekpr      := aData[nD]["preis"]
		rpos->pe        := aData[nD]["pe"]
		rpos->menge     := aData[nD]["menge"]
		rpos->rabatt    := 0
		rpos->(dbUnLock())

		//? Space(8),nD,aData[nD]["matchcode"],aData[nD]["menge"],aData[nD]["preis"],aData[nD]["pe"]
		nD++
	Enddo
	nX ++
Enddo
rpos->(dbCloseArea())
? "Finished"
Inkey(0,128)

