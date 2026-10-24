PARAMETERS nArtnr,cArtlief
aSites := {"uk","fr","de"}
nX := 1
nQty := 0
lFound := .F.
lQuit := .F.
Do While nX <= Len(aSites) .AND. ! lQuit
	If Type("nR") == "N"
		@ nR,26 SAY Replicate(".",nX)
	Endif
	nY := 1
//http://de.rs-online.com/web/search/searchBrowseAction.html?method=checkStockAvailability&productNumber=0488208A&quantity=100&sid=FA5754B703EE4867B5F345F502489269.55
	cUrl := "http:/"+"/"+aSites[nX]+".rs-online.com/web/search/searchBrowseAction.html?method=checkStockAvailability&productNumber="+Trim(cArtlief)+"&quantity=99999"
	cCookies := ""
	Do While nY <= 2
		oHttp := TIpClientHttp():new( cUrl )
		If oHttp:open()
			//oHttp:readToFile("d:\trader30\rs_"+aSites[nX]+".txt",,1000)
			If nY == 1
				oHttp:ReadAll()
				cCookies := oHttp:GetCookies()
				//@ 24+nX,00 SAY Str(nX)+Str(nY)+cCookies
				aMatches := HB_RegExAll('JSESSIONID=([^'+Chr(59)+']*)',cCookies)
				cSid := ""
				If Valtype(aMatches) == "A" .AND. Len(aMatches) > 0
				  cSid := aMatches[1][2]
				Endif
				cUrl += "&sid="+cSid
                                   //@ 24+nX,00 SAY Str(nX)+cSid
			Else
				oHttp:SetCookie(cCookies)
				cData := oHttp:ReadAll()
				If ValType(cData) != "C"
					//Alert("Invalid response from RS: "+ValType(cData)
					lQuit := .T.
				Else
					cType := SubStr(cData,At('||',cData)+2)
					If cType == "Q" .OR. cType == "V"
						nQty += Val(cData)
						lFound := .T.
					Elseif cType == "F" //no Stock
					    lFound := .T.
					Elseif cType == "N" //nicht lieferbar
						lFound := .T.
					Elseif cType == "OS" .OR. cType == "D" //OS=temp. unavailable,D=not RS part anymore
						lQuit := .T.
					Elseif cType == "Y"  //kurzfristig lieferbar
						lFound := .T.
					Else
						lQuit := .T.
//						Alert("Meldung: "+cType+" "+cUrl)
//						GTSetClipBoard(cUrl)
					Endif
				Endif
			Endif
		Endif
		oHttp:close()
		nY++
	Enddo
	nX++
Enddo
if lQuit
	Return -2
ElseIf lFound
	Return nQty
Else
	Return -1
Endif
