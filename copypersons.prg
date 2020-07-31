NetUse("engkund","ku",.F.,0)
SqlOpen("contacts","conts")
INDEX ON Str(address,6)+If(active,"0","1")+Str(number,4) TO contacts.001
INDEX ON Str(address,6)+Str(number,4) TO contacts.002

ku->(dbGoTop())
Do While ! ku->(Eof()) .OR. Inkey() == 27
	@ 24,00 SAY ku->Kunde
	For nX := 1 To 5
		cPerson := &("ku->Person"+If(nX>1,Str(nX,1),""))
		If ( ! Empty(cPerson) )
			conts->(Add_rec(0))
			conts->Name := cPerson
			conts->Number := nX
			conts->Address := ku->Nummer
			conts->Department := &("ku->Abteil"+Str(nX,1))
			conts->Telephone := &("ku->Telefon"+Str(nX,1))
			conts->Anrede := &("ku->Anrede"+Str(nX,1))
			conts->Active := .T.
			conts->(dbUnlock())
		Endif
	Next
	ku->(dbSkip())
Enddo