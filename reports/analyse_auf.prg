LOCAL cKundma := Pad("FP",8)

Head(HB_AnsiToOem("Wert Lagerbestand für Aufträge eines Kunden"))

@ 01,00 SAY "Kunde" GET cKundma PICTURE "@!"
READ


NetUse("engauf","auf",.F.,0)
NetUse("artikel","art",.F.,0)
art->(dbSetOrder( 1 ))
auf->(dbSetOrder( 2 ))
auf->(dbSeek(cKundma))

nStockTotal := 0
aParts := {}
? Pad("Artikel",25),"Wert EUR"
Do While auf->Kundma == cKundma .AND. auf->Bestat < 3 .AND. ! auf->(Eof())
	art->(dbSeek( auf->Matchcode ))
	If AScan(aParts,art->Matchcode) == 0
		nStock := (auf->vkpr - ( auf->vkpr * auf->rabatt / 100 ))/auf->pe*art->Bestand
		? art->Matchcode,Str(nStock,12,2)
		Aadd(aParts,art->Matchcode)
		nStockTotal += nStock
	Endif
	auf->(dbSkip())
Enddo

? Space(25),Str(nStockTotal,12,2)

Sinkey(0)