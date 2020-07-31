NetUse("engabg","abg",.F.,0)
abg->(dbSetOrder(3)) //matchcode+descend(recno())

NetUse("artikel","art",.F.,0)
NetUse("engkund","ku",.F.,0)

abg->(dbGoTop())

//abg->(dbSeek(Pad("MPI002/28/AM",25)))
CLS
@ 00,00 SAY Pad("Matchcode",25)+Pad("D/S Preis",14)+Pad("Alt",14)+"Letzte-EK"
aDone := {}   

Do While ! abg->(Eof())
	cMatch := abg->Matchcode
	nQty   := 0
	nTotal := 0
	
	//If Left(art->Gruppe,4) $ "BLSC" // ED DI IT"
	If art->(dbSeek(cMatch))
		Do While cMatch == abg->Matchcode .AND. ! abg->(Eof())
	
			If abg->Datum >= Date()-365 .AND. Trim(abg->BuArt) == "RE"
				ku->(dbSeek(abg->Liefma+"L"))
			   //? abg->Datum,abg->Menge,abg->Preis*Currate(ku->Money,"E")/abg->Pe
			   nQty += abg->Menge
			   nTotal += abg->Menge*abg->Preis*Currate(ku->Money,"E")/abg->Pe
			   If AScan(aDone,art->Artikelnr) == 0
			   	  Aadd(aDone,art->Artikelnr)
			   Endif
	
			Endif
			abg->(dbSkip())
		Enddo
	
		If nQty > 0
			? cMatch,nTotal/nQty*art->pe/Currate(art->money,"E"),art->avpreis,art->letzte_ek,Currate(art->money,"X")
			art->(Rec_Lock(0))
			art->avpreis := nTotal/nQty*art->pe/Currate(art->money,"E")
			art->(dbUnLock())
		Endif
	Else
		abg->(dbSkip())
	Endif

Enddo

//Alert(Type("aDone"))

CLS
//check for wrong prices
art->(dbGoTop())
Do While ! art->(Eof())
	If art->Bestand != 0 .AND. art->avpreis > art->letzte_ek*1.5 .AND. art->letzte_ek > 0 .AND. AScan(aDone,art->Artikelnr) == 0
		? art->Matchcode,art->avpreis,art->letzte_ek
		art->(Rec_Lock(0))
		art->avpreis := art->letzte_ek
		art->(dbUnLock())
	Endif
	art->(dbSkip())
Enddo
SInkey(0)