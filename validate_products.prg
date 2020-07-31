dDate := GetBox(Date()-30,"Ab Datum")

aManu := GetManufacturerArray()

NetUSe("engabg","abg",.F.,0)
abg->(dbSetOrder(0))
abg->(dbGoBottom())
NetUse("artikel","art",.F.,0)
art->(dbSetOrder(2))

Do While abg->Datum >= dDate
	//? abg->Matchcode,abg->Beleg
	If Trim(abg->Beleg) == "ANLAGE"
		art->(dbSeek( Str(abg->artikelnr,6) ))
		? art->Matchcode,aManu[2][AScan(aManu[1],art->Manufactur)]
	Endif
	abg->(dbSkip(-1))
Enddo
Inkey(0)