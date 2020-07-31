NetUse("engabg","abg",.F.,0)
NetUSe("engkund","ku",.F.,0)
NetUse("ups","ups",.F.,0)
NetUse("lagerne","lne",.F.,0)

abg->(dbSetOrder(4))
ku->(dbSetOrder(1))
ups->(dbSetOrder(4)) //nr
lne->(dbSetOrder(1))

abg->(dbGoTop())
nX := 0
nNr := 0
cBuart := ""

? "Running"
abg->(dbSeek("A",.T.)) //goto first matchcode
//abg->(dbSeek("BULGIN",.T.)) //goto first matchcode
Do While ! abg->(Eof()) //.AND. Trim(abg->Liefma) <= "BULGIN"
	cLiefma := abg->Liefma
	cGroupO := cGroup := abg->Group
    If ! Empty(cLiefma) .AND. (Empty(abg->Group) .OR. Empty(abg->Kundennr))
		? abg->Liefma,abg->Group,abg->Kundennr,Empty(abg->Kundennr),abg->matchcode
	    cBuart := ""
		If Empty(cGroup)
			If Trim(abg->Buart) $ "WE RE"
				cGroup := "L"
			Elseif Trim(abg->Buart) $ "RNR RAŽ"
				cGroup := "K"
			ElseIf Trim(abg->Buart) == "PKZ"
				? "Packzettel nachschlagen"
				If ups->(dbSeek(abg->Besnr))
					?? " gefunden"
					If Empty(ups->Rechnr)
						cBuart := "ENT"
						nNr := ups->Nr
					Else
						//cBuart := "RNR"
						cGroup := "K"
					Endif
				Else
					? Val(abg->Besnr)," nicht gefunden"
				Endif
			Else
				cBuart := abg->Buart
				nNr := abg->Besnr
			Endif
			If Trim(cBuart) $ "ENT ENŽ ENL"
				? "Lagerentnahme nachschlagen!"
				If lne->(dbSeek(nNr))
					?? " gefunden"
					cGroup := lne->Gruppe
				Else
					cGroup := GetBox(" ","Gruppe","!")
				Endif
			Endif
			If ! Empty(cGroup)
				?? "/replacing Group/"
			Endif
		Endif
		If ! ku->(dbSeek(cLiefma+cGroup))
			?? "",cLiefma+cGroup,"not found ",abg->BuArt,cBuArt
			//nX++
		Else
			?? "found, replacing kundennr"
			abg->(dbSkip(-1))
			nRec := abg->(Recno())  //get last record
			abg->(dbSkip(1))
			abg->(Rec_Lock(0))
			abg->Group := cGroup
			abg->Kundennr := ku->Nummer
			abg->(dbUnLock())
			abg->(dbGoto(nRec)) //goto next record, as the replace will change the order
		Endif
	Endif

	//Do While abg->Liefma == cLiefma .AND. abg->Group == cGroupO .AND. ! abg->(eof())
		abg->(dbSkip())
	//Enddo
Enddo
Inkey(0)


			/*If Trim(abg->Buart) $ "WE RE"
				cGroup := "L"
			Elseif Trim(abg->Buart) $ "RNR RAŽ"
				cGroup := "K"
			ElseIf Trim(abg->Buart) == "PKZ"
				? "Packzettel nachschlagen"
				If ups->(dbSeek(Val(abg->Beleg)))
					?? " gefunden"
					If Empty(ups->Rechnnr)
						cBuart := "ENT"
					Else
						cBuart := "RNR"
						nNr := ups->Nr
					Endif
				Endif
			Else
				cBuart := abg->Buart
				nNr := abg->Besnr
			Endif
			If Trim(cBuart) $ "ENT ENŽ"
				? "Lagerentnahme nachschlagen!"
				If lne->(dbSeek(nNr))
					?? " gefunden"
					cGroup := lne->Gruppe
				Endif
			Endif */