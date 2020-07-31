LOCAL nManu
LOCAL cFilter := "bestand > 0"
//LOCAL nArtRec
Head(HB_AnsiToOem("Bestandsanalyse"))

NetUse("artikel","art",.F.,0)
NetUse("engabg","abg",.F.,0)
NetUSe("manufact","manu",.F.,0)
NetUse("me","me",.F.,0)



abg->(dbSetOrder( 3 ))

art->(dbSetFilter( {|| art->(&(cFilter)) },cFilter))
art->(dbGoTop())



hStock := {=>}
nTotal := 0
Do While ! art->(Eof()) 
   //nArtRec := art->(Recno())
	//If art->Bestand > 0
	   IF art->manufactur == 8 .AND. Trim(art->Type) == "RHB"
         nManu := -1
	   ELSEIF art->manufactur == 8 .AND. Trim(art->Type) == "VERP"
         nManu := -2
	   ELSE
	     nManu := art->manufactur
	   ENDIF
		If ! HHasKey(hStock,nManu)
			hStock[nManu] := {"total"=>0,"over"=>0,"3years"=>0,"5years"=>0,"products"=>{}}
		Endif
		hReqInq := GetProductRequirementAndIncoming(art->Artikelnr)
		nBestand := Min(art->Bestand,art->Bestand-hReqInq["requirement"]+hReqInq["income"])
		If nBestand > 0 //.AND. art->Manufactur == 1
		   oArt := Artikel():New(.F.)
         oArt:Load(art->Artikelnr)

			nPrice := oArt:GetAvgBuyPrice(Date())
			abg->(dbSetFilter( {|| Trim(abg->Buart) $ "WE WA" },'Trim(buart) $ "WE WA"'))
			abg->(OrdScope(0,{|| art->Matchcode }))
			abg->(OrdScope(1,{|| art->Matchcode }))

			//abg->(dbSeek( art->Matchcode,.T. ))
			abg->(dbGoBottom())
			dDate := SToD("")
			nX := 1
			Do While abg->Matchcode == art->Matchcode .AND. ! abg->(Eof())
			   @ 00,00 SAY nX++
				dDate := abg->Datum
            abg->(dbSkip())
			Enddo
			abg->(dbClearFilter())
			abg->(OrdScope(0,{|| .T. }))
			abg->(OrdScope(1,{|| .T. }))

			@ MAxRow(),00 SAY art->Matchcode+" "+art->Type
			//If Trim(art->Matchcode) == "KS21943/3"
//				? art->Matchcode,nBestand,nBestand*nPrice,dDate
				/*? "Bestand:",art->Bestand
				? "Incoming:",hReqInq["income"]
				? "Requirement:",hReqInq["requirement"]
				Inkey(0)*/
			//Endif
			Aadd(hStock[nManu]["products"],{"matchcode"=>art->Matchcode,"bestand"=>nBestand,"value"=>nBestand*nPrice,"lastwe"=>dDate})
			nTotal += nBestand*nPrice
			hStock[nManu]["total"] += art->Bestand*nPrice
			hStock[nManu]["over"] += nBestand*nPrice
			If dDate <= Date()-365*3
				hStock[nManu]["3years"] += nBestand*nPrice
			Endif
			If dDate <= Date()-365*5
				hStock[nManu]["5years"] += nBestand*nPrice
			Endif
		Endif
	IF Inkey() == 27
      EXIT
   ENDIF

	//Endif
//	art->(dbGoTo(nArtRec))
   art->(dbSetFilter( {|| art->(&(cFilter)) },cFilter))  //the artikel model resets the filter
	art->(dbSkip())
Enddo

art->(dbClearFilter())

CLS

nX := 1
nTotal := 0
nOver := 0
n3Y :=0
n5Y := 0
? Pad("Hersteller",15),Pad("Gesamt",12),Pad(t("Überbestand"),12),Pad(t("ÜB m. WE>=3J."),12),Pad(t("ÜB m. WE>=5J."),12)
Do While nX <= Len(hStock)
   IF HGetKeyAt(hStock,nX) > 0
   	manu->(dbSeek( Str(HGetKeyAt(hStock,nX),5) ))
	  ? manu->Short
	ELSE
	  ? Pad(IF(HGetKeyAt(hStock,nX)==-1,"RHB","Verpackung"),15)
   ENDIF
   ?? "",Str(HGetValueAt(hStock,nX)["total"],12,2),Str(HGetValueAt(hStock,nX)["over"],12,2),Str(HGetValueAt(hStock,nX)["3years"],12,2),Str(HGetValueAt(hStock,nX)["5years"],12,2)
	nTotal += HGetValueAt(hStock,nX)["total"]
	nOver += HGetValueAt(hStock,nX)["over"]
	n3Y += HGetValueAt(hStock,nX)["3years"]
	n5Y += HGetValueAt(hStock,nX)["5years"]
	nX++
Enddo
? Space(15),Str(nTotal,12,2),Str(nOver,12,2),Str(n3Y,12,2),Str(n5Y,12,2)
?
? "Weiter mit beliebiger Taste..."
SInkey(0)

If Tr_MsgBox(t("Bestände drucken?"),,{"Ja","Nein"}) == 1
	StartPrint(,,"PDF")
	oPdf := GetCurrentPrinterObject():Data
	oPdf:SetFont("COURIER")
	nX := 1
	Do While nX < Len(hStock)
      IF HGetKeyAt(hStock,nX) > 0
		    manu->(dbSeek( Str(HGetKeyAt(hStock,nX),5) ))
		ENDIF
		dD := 1
		Do While dD <= 3
			oPdf:NewPage()
			IF HGetKeyAt(hStock,nX) > 0
			   oPdf:AtSay(manu->Short)
			ELSE
			   oPdf:AtSay(IF(HGetKeyAt(hStock,nX)==-1,"RHB","Verpackung"))
			ENDIF
			If dD == 1
				oPdf:AtSay("bis zu 3 Jahre alt")
			Elseif dD == 2
				oPdf:AtSAy("zwischen 3 und 5 Jahre alt")
			Else
				oPdf:AtSay("älter als fünf Jahre")
			Endif
			oPdf:NewLine()
			oPdf:AtSay(Pad("Matchcode",25)+" "+Pad("Bestand",12)+" "+Pad("Wert",12)+" "+"Letzter WE" )
			nP := 1
			nTot := 0
			aProds := HGetValueAt(hStock,nX)["products"]
			Do While nP < Len(aProds)
				If (dD == 1 .AND. aProds[nP]["lastwe"] > Date()-365*3) .OR. ;
					(dD == 2 .AND. aProds[nP]["lastwe"] <= Date()-365*3 .AND. aProds[nP]["lastwe"] > Date()-365*5) .OR.;
					(dD == 3 .AND. aProds[nP]["lastwe"] <= Date()-365*5)
					oPdf:NewLine()
					art->(dbSeek( aProds[nP]["matchcode"] ))
					oPdf:AtSAy( aProds[nP]["matchcode"]+" "+Pad(Transform(aProds[nP]["bestand"],Me(art->me)),12)+" "+Str(aProds[nP]["value"],12,2)+" "+DToC(aProds[nP]["lastwe"]) )
					nTot += aProds[nP]["value"]
				Endif
				nP++
			Enddo
			oPdf:NewLine()
			oPdf:AtSay( Space(38)+" "+Replicate("=",12))
			oPdf:NewLine()
			oPdf:AtSAy( Space(38)+" "+Str(nTot,12,2) )
			dD++
		Enddo
		nX++
	Enddo

	CopyPrint()
Endif