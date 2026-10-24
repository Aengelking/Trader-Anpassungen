Head("Kunden im Umkreis suchen")

NetUse("geoplz","gplz",.F.,0)
NetUse("engkund","ku",.F.,0)
NetUse("engauf","auf",.F.,0)
NetUse("angebot","ang",.F.,0)
NetUse("notes","nts",.F.,0)

nKM := 50
cPLZ := "D-78609"

Do While .T.
	@ 01,00 SAY "Umkreis in km"
	getlist := {}
	oGet := Get():New(01,15,{|nNew| If(nNew==NIL,nKM,nKM := nNew) },,"9999"); oGet:Display(); Aadd(getlist,oGet)
	@ 02,00 SAY "von PLZ       "
	oGet := Get():New(02,15,{|cNew| If(cNew==NIL,cPlz,cPLZ := cNew) },,"D-99999"); oGet:Display(); Aadd(getlist,oGet)
	READ

	If LastKey() == 27
		Return
	Endif

	bPLZ := {|cPlz| SubStr(cPlz,At("-",cPLZ)+1) }
	cPlzN := Eval(bPlz,cPlz)

	gplz->(dbSetOrder( 1 )) //PLZ (ohne D-)

	If ! gplz->(dbSeek( cPlzN ))
		Tr_MsgBox("Postleitzahl nicht gefunden")
		Loop
	Endif

	nLatA := gplz->lat
	nLngA := gplz->lng

	gplz->(dbGoTop())
	
	ang->(dbSetOrder( 2 ))
	auf->(dbSetOrder( 2 ))
	nts->(dbSetOrder( 1 ))

	Do While ! gplz->(Eof()) //look for postcodes which meet the requirement
		cLastPlz := gplz->ZIP
		nCnt := 0
		nTotDist := 0

		//calculate average distance of all (same) zip
		Do While ! gplz->(Eof()) .AND. gplz->ZIP == cLastPlz
			nA := (sin( DToR(nLatA-gplz->lat)/2 ) ** 2) + cos( DToR(nLatA) ) * cos( DToR(gplz->lat) )* (sin( DToR(nLngA-gplz->lng)/2 )**2)
			nDist := 6371* 2*atn2(sqrt(nA),sqrt(1-nA))

			nTotDist += nDist
			nCnt ++
			gplz->(dbSkip())
		Enddo

		If nTotDist/nCnt <= nKM
			ku->(dbSetOrder( 4 )) //PLZ
			ku->(dbSeek( "D-"+cLastPlz ))
			Do While Trim(ku->PLZ) == Trim("D-"+cLastPlz)
				If ku->Group == "K" //.AND. ( auf->(dbSeek( ku->Kunde )) .OR. ang->(dbSeek( ku->Kunde )) .OR. nts->(dbSeek(ku->Kunde+ku->Group,.T.)) )
					? Trim(Trim(ku->Name1)+" "+ku->Name2),ku->PLZ,ku->Town
				Endif
				ku->(dbSkip())
			Enddo
		Endif

	Enddo
	/** FORMULAS
	//Spherical Law of Cosines
        acos(sin(lat1).sin(lat2)+cos(lat1).cos(lat2).cos(long2-long1)).R

        //HP geopostcodes.com
//	Distance(A,B) = 6371 * ACos( Cos(LatA) * Cos(LatB) * Cos(LngB - LngA) + Sin(LatA) * Sin(LatB) )

	//‘haversine’ formula
	a = sin²(delta lat/2) + cos(lat1).cos(lat2).sin²(delta long/2)
	c = 2.atan2(sqrt a, sqrt(1-a))
	d = R.c
	*/
Enddo