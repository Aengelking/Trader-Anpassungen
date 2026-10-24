aSites := {"uk","fr","de"}
nX := 1
nQty := 0
lFound := .F.
Do While nX < Len(aSites)
	@ 06,26 SAY Replicate(".",nX)
	oHttp := TIpClientHttp():new( "http:/"+"/"+aSites[nX]+".rs-online.com/web/search/searchBrowseAction.html?method=checkStockAvailability&productNumber="+Trim(alil->artlief)+"&quantity=99999" )
	If oHttp:open()
		cData := oHttp:ReadAll()
		cType := SubStr(cData,Len(cData))
		If cType == "Q" .OR. cType == "V"
			nQty += Val(cData)
			lFound := .T.
		Endif
	Endif
	nX++
Enddo