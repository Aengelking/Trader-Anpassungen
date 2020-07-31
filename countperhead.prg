NetUse("engauf","auf",.F.,0)
auf->(dbSeek(Str(10000,6)))

Head("Count orders per head")

hUsers := {=>}
nX := 0

Do While ! auf->(Eof()) //.AND. nX < 10000
	If auf->besda >= Date()-365
    	If ! HHasKey(hUsers,auf->Buyer)
    		hUsers[auf->Buyer] := {}
    	Endif
    	If AScan(hUsers[auf->Buyer],auf->Abnr) == 0
    		Aadd(hUsers[auf->Buyer],auf->Abnr)
    		//? auf->Abnr," added"
    	Endif
	Endif
	auf->(dbSkip())
	nX++
Enddo

nX := 1
Do While nX <= Len(hUsers)
	? Buy(HGetKeyAt(hUsers,nX),.T.,.F.),Len(HGetValueAt(hUsers,nX))
	nX++
Next
Sinkey(0)
? "Done"