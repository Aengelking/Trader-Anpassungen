NetUse("artikel","art",.F.,0)
art->(dbGoTop())
NetUse("FOLGEART","FOL",.F.,0)

nPrice := 0
nCOunt := 0

CLS
? HB_AnsiToOem("Überprüfe ob Folgeartikel teurer sind als Gesamtartikel von Bulgin")
Do While ! art->(Eof()) //.AND. nCOunt < 5
	If Row() == MaxRow()
		Sinkey(0,128)
		CLS
	Endif
	If art->Manufactur == 1 .AND. ! art->Lagerart .AND. fol->(dbSeek(STR(art->Artikelnr,6)))
		nPrice := 0
		lPreise := .T.
		cNoPr := ""
		//? art->Matchcode
		Do While fol->Artikelnr == art->Artikelnr
			nEkPr := 0
			nPe := 1
			GetBuyPrice(Pad("BULGIN",8),fol->Folgeart,10000,@nEkPr,@nPe,.F.)
			If nEkPr == 0
				cNoPr += Str(fol->Folgeart)
				lPreise := .F.
			Endif
			//? "   ",fol->Folgeart,nEkPr/nPe
			nPrice += nEkPr/Max(nPe,1)*fol->Faktor
			fol->(dbSkip())
		Enddo
		nEkPr := 0
		nPe := 1

		GetBuyPrice(Pad("BULGIN",8),art->Artikelnr,10000,@nEkPr,@nPe,.F.)
		If lPreise .AND. nEkPr > 0 .AND. (nPrice-nEkPr/Max(nPe,1) > 0.10 .OR. nEkPr/Max(nPe,1)-nPrice > 0.10)
			nCount++
			//? art->Matchcode,nEkPr/Max(nPe,1),Str(nPrice,12,2) //,art->Manufactur
			If  nPrice-nEkPr/Max(nPe,1) > 0.10
				? art->Matchcode,nEkPr/Max(nPe,1),Str(nPrice,12,2) //,art->Manufactur
				@ Row(),Col()+1 SAY nPrice-nEkPr/Max(nPe,1) COLOR "R/W"
			Else
				//@ Row(),Col()+1 SAY nEkPr/Max(nPe,1)-nPrice COLOR "G/W"
			Endif
			If ! lPreise
				@ Row(),Col()+1 SAY "X" COLOR "R+/W"
				? cNoPr,"kein Preis"
			Endif
		Endif
	Endif
	art->(dbSkip())
Enddo
? "Done"
SInkey(0,128)