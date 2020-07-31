NetUse("artlief","alil",.F.,0)
NetUse("artikel","art",.F.,0)
CLS

aBrands := {}
Aadd(aBrands,"BULGIN") //Bulgin
//Aadd(aBrands,"ONPOW") //Onpow does not work, as the part nos are not correct


FOR nX := 1 TO Len(aBrands)
   ? aBrands[nX]
   cUrl := "http://www.reichelt.de/index.html?ACTION=446&SEARCH="+aBrands[nX]+"&OFFSET=9999&LA=446"  //offset is the number of products per page, currently they have 196 listed bulgin products (3/3/15)

	oHttp := TIpClientHttp():new( cUrl )
	If oHttp:open()
		cData := oHttp:ReadAll()

		nPos := At('al_artikellist',cData)

		If nPos == 0
			? "Done"
			Inkey(0,128)
			Return
		Endif

		cString := SubStr(cData,nPos)

      cMarker := '"al_gallery_article"'
		Do While (nR := At(cMarker,cString)) != 0
			cRow := SubStr(cString,nR)

         aRegEx := HB_RegEx("ARTICLE=([0-9]*)",cRow)
         cPart := aRegex[2]

			aRegex := HB_RegEx('productID.*content="(.*)"',cRow)
         cMatch := StrTran(aRegex[2],"PL ","")

			If art->(dbSeek( Pad(cMatch,25) ))
				If Trim(cPart) == "Nicht zugewiesen"
				Else
               ? cMatch,cPart
					If alil->(dbSeek( Pad("REICHELT",8)+Str(art->Artikelnr,6) ))
	                                	?? " update"
						alil->(Rec_Lock())
					Else
						alil->(Add_Rec())
						alil->Artikelnr := art->Artikelnr
						alil->Matchcode := art->Matchcode
						alil->Kunde     := Pad("REICHELT",8)

					Endif
					alil->ArtLief := cPart
					alil->(dbUnLock())
				Endif
			Endif

			cString := SubStr(cString,nR+Len(cMarker))
		Enddo
	Endif
NEXT
   Inkey(0,128)