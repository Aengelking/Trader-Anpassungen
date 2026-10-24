Head(t("Export offener Musteraufträge"))

NetUse("muster","mus",.F.,0)
mus->(dbSetOrder( 6 ))
mus->(dbGoTop())

NetUse("artikel","art",.F.,0)
art->(dbSetOrder(1))

NetUse("manufact","manu",.F.,0)

NetUse("artlief","ali",.F.,0)
ali->(dbSetORder( 2 ))

NetUse("me","me",.F.,0)

cFile :=Trim(Tr_Getini(1))+"\export\offene_muster.csv"

nH := FCreate(cFile)
FWrite(nH,"Matchcode"+","+"Datum"+","+"Hersteller"+","+t("Verfügbar")+","+"RS"+","+"Farnell"+Chr(13)+Chr(10))
Do While mus->Status == 0 .AND. ! mus->(Eof())
	art->(dbSeek( mus->Matchcode ))
	manu->(dbSeek( Str(art->Manufactur,5) ))
	cRs := Space(35)
	cFarnell := Space(35)
	If ali->(dbSeek( Pad("RS",8)+mus->Matchcode ))
		cRS := Trim(ali->Artlief)
	Endif
	If ali->(dbSeek( Pad("FARNELL",8)+mus->Matchcode ))
		cRS := Trim(ali->Artlief)
	Endif
	hReq := GetProductRequirementAndIncoming(art->Artikelnr)
	nAvail := hReq["income"]-hReq["requirement"]+art->Bestand
	FWrite(nH,Trim(mus->Matchcode)+","+DToC(mus->Datum)+","+Trim(manu->Short)+","+LTrim(Transform(nAvail,Me(art->me)))+","+cRS+","+cFarnell+Chr(13)+Chr(10))
	mus->(dbSkip())
Enddo

FClose(nH)