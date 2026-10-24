NetUse("artlief","alil",.F.,0)
NetUse("artikel","art",.F.,0)
CLS

aBrands := {}
//Aadd(aBrands,"4294960186") //Bulgin
//Aadd(aBrands,"4294953981") //ITW Switches
Aadd(aBrands,"4294769679") //EDAC

FOR nX := 1 TO Len(aBrands)
   nNo := 0
   Do While .T. //.AND. nNo < 200
   	cUrl := "http://www.mouser.de/Search/Refine.aspx?N="+aBrands[nX]+"&No="+LTrim(Str(nNo))
   	
   	oHttp := TIpClientHttp():new( cUrl )
   	If oHttp:open()
   		cData := oHttp:ReadAll()
         IF cData != NIl
      		nPos := At('<table class="SearchResultsTable"',cData)

      		If nPos == 0
      			? "Done"
      			Inkey(0,128)
      			Return
      		Endif

      		cString := SubStr(cData,nPos)

      		cMarker := "SearchResultsRow"
      		Do While (nR := At(cMarker,cString)) != 0
      			cRow := SubStr(cString,nR)

      			cPart := SubStr(cRow,At("MouserPartNumber",cRow))
      			cPart := SubStr(cPart,0,At("</a",cPart)-1)
      			cPart := Substr(cPart,Rat(">",cPart)+1)

      			cMatch := SubStr(cRow,At("MfrPartNumberLink",cRow))
      			cMatch := SubStr(cMatch,0,At("</a",cMatch)-1)
      			cMatch := SubStr(cMatch,Rat(">",cMatch)+1)
      
      			If art->(dbSeek( Pad(cMatch,25) ))
      				If Trim(cPart) == "Nicht zugewiesen"
      					/*If alil->(dbSeek( Pad("MOUSER",8)+Str(art->Artikelnr,6) ))
      						alil->(Rec_Lock())
      						alil->(dbDelete())
      						alil->(dbUnLock())
      					Endif */
      				Else
                                             ? cMatch,cPart
      					If alil->(dbSeek( Pad("MOUSER",8)+Str(art->Artikelnr,6) ))
      	                                	?? " update"
      						alil->(Rec_Lock())
      					Else
      						alil->(Add_Rec())
      						alil->Artikelnr := art->Artikelnr
      						alil->Matchcode := art->Matchcode
      						alil->Kunde     := Pad("MOUSER",8)
      	
      					Endif
      					alil->ArtLief := cPart
      					alil->(dbUnLock())
      				Endif
      			Endif
      
      			cString := SubStr(cString,nR+Len(cMarker))
      		Enddo
      	ENDIF
   	Endif
   	nNo += 25
   Enddo
NEXT