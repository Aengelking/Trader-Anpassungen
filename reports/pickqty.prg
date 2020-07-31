Head(HB_OemToAnsi("Analyse Pick-Häufigkeit"))

cLagerort := "001/"

nVeryHighPick := 96 //4x a month
nHighPick := 24  //once a month
nLowPick := 6  //every 4 months
nVeryLowPick := 0  //never in the last 2 years

//nOrt 	:= 0
nReihe 	:= 0
nRegal 	:= 0
nBoden	:= 0

nMitteSt := 2
nMitteEn := 4

nFirstRegal := 6
nStRowVH  := 1
nEnRowVH  := 2

aInclude := {"001/"}
aExclude := {"001/0306","001/0101"}


dStart := Date()-(365*2)

NetUse("englsre","re",.F.,0)
re->(dbSetOrder( 6 )) //matchcode+status
NetUse("artikel","art",.F.,0)
NetUse("lagerne","lne",.F.,0)
lne->(dbSetOrder( 2 ))
NetUse("LAGER","LAG",.F.,0)

aInv := {}
aArt := {}

art->(dbGoTop())
Do While ! art->(Eof()) //.AND. Len(aArt) < 100
	If art->Bestand != 0 .AND. art->Lagerart
		@ 24,00 SAY art->Matchcode

		If AScan(aArt,{|x| x[1] == art->Matchcode}) == 0
			Aadd(aArt,{art->Matchcode,art->Artikelnr,0,{}})
		Endif

        	aInv := {}
		re->(dbSeek( art->Matchcode ))
		Do While re->Matchcode == art->Matchcode .AND. ! re->(Eof())
			If re->Rechdat >= dStart .AND. AScan(aInv,re->Rechnr) == 0 //only once per invoice
				Aadd(aInv,re->Rechnr)
                                aArt[AScan(aArt,{|x| x[1] == art->Matchcode}),3] ++
			Endif
			re->(dbSkip())
		Enddo
		lne->(dbSeek( art->Matchcode ))
		aInv := {}
		Do While lne->Matchcode == art->Matchcode .AND. ! lne->(Eof())
			If lne->Datum >= dStart .AND. AScan(aInv,lne->Nummer) == 0
				Aadd(aInv,lne->Nummer)
                                aArt[AScan(aArt,{|x| x[1] == art->Matchcode}),3] ++
                        Endif
			lne->(dbSkip())
		Enddo
	Endif
	art->(dbSkip())
Enddo

ASort(aArt,,,{|x,y| x[3] > y[3] })

StartPrint(,,"PDF")
oPdf := GetCurrentPrinterObject():Data
oPdf:NewPage()
oPdf:SetFont("Courier")

oPdf:AtSay( "Folgende Artikel sollten umgelagert werden")
oPdf:NewLine()
oPdf:AtSay( Pad("Matchcode",25)+" "+"Entnahmen/Monat")

nX := 1
Do While nX <= Len(aArt)

	lMove := .F.
	lSchrott := .F.
	lag->(dbSeek( aArt[nX,2] ))
	Do While lag->artikelnr == aArt[nX,2] .AND. ! lMove
		lExclude := .F.
		lInclude := .F.
		AEval(aInclude,{|x| If(At(x,lag->Lagerort)!=0,lInclude:=.T.,"") })
		AEval(aExclude,{|x| If(At(x,lag->Lagerort)!=0,lExclude:=.T.,"") })
		If lInclude .AND. ! lExclude .AND. AScan(aArt[nX,4],lag->Lagerort) == 0
			Aadd(aArt[nX,4],lag->Lagerort)
			nReihe := Val(SubStr(lag->Lagerort,5,2))
			nRegal := Val(SubStr(lag->Lagerort,7,2))
			nBoden := Val(SubStr(lag->Lagerort,9,3))
			If aArt[nX,3] >= nVeryHighPick

			//	? nReihe,"-",nRegal,"-",nBoden
			Endif
			If aArt[nX,3] >= nVeryHighPick .AND. (nBoden < nMitteSt .OR. nBoden > nMitteEn .OR. nRegal != nFirstRegal .OR. nReihe > nEnRowVH .OR. nReihe < nStRowVH)
				//?? "move"
				lMove := .T.
			Elseif aArt[nX,3] >= nHighPick .AND. (nBoden < nMitteSt .OR. nBoden > nMitteEn)
	                	lMove := .T.
			Elseif aArt[nX,3] <= nLowPick .AND. nBoden >= nMitteSt .AND. nBoden <= nMitteEn
	                	lMove := .T.
			Elseif aArt[nX,3] <= nVeryLowPick
				lMove := .T.
				lSchrott := .F.
			Endif
		Endif
		lag->(dbSkip())
	Enddo
	If lMove
		oPdf:NewLine()
		oPdf:AtSay( aArt[nX,1]+" "+Str(aArt[nX,3]/24,7,4) )
		nL := 1
		oPdf:ReportCol := 100
		Do While nL <= Len(aArt[nX,4])
			If Mod(nL,4) == 0
				oPdf:NewLine()
				oPdf:ReportCol := 100
                        Endif
			oPdf:AtSAy( aArt[nX,4,nL]+" " )
			nL++
		Enddo
		If lSchrott
			oPdf:AtSAy("Schrott?")
		Endif
//        If lMove
//		oPdf:AtSay( " umbuchen" )
	Endif
	nX++
Enddo
//Inkey(0)
CopyPrint()

