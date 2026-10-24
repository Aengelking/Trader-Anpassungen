Head("Kundenstruktur")

NetUse("angebot","ang",.F.,0)
ang->(dbSetOrder(2))

NetUse("notes","nts",.F.,0)

NetUse("engkund","ku",.F.,0)
ku->(dbSetOrder(2))
ku->(dbSeek("K",.T.))

nCustomers := nPotentials := nOldCustomers := nOthers := nVeryOld := nContacted := nBigOld := nBig2Old := nPrivat := 0
nPrivTotal := nPrivLast3 := nBigCust := nOver2k5 := nOver10k := nOver20k := nLongTerm := 0
@ 01,00 SAY "Kundenstruktur wird analysiert"
nX := 0
Do While ku->Group == "K"
	If Mod(nX,20) == 0
		@ 01,31+Int(nX/20) SAY "."
	Endif
	hTurnover := GetCustomerTurnover(ku->Kunde)
	If hTurnover["current"]+hTurnover["last"] > 0
		If Len(hTurnover["years"]) > 3
			nLongterm++
		Endif
		nCustomers++
		If hTurnover["current"] > 500 .OR. hTurnover["last"] > 500
			nBigCust++
		Endif
		If hTurnover["current"] > 2500 .OR. hTurnover["last"] > 2500
			nOver2k5++
		Endif
		If hTurnover["current"] > 10000 .OR. hTurnover["last"] > 10000
			nOver10k++
		Endif
		If hTurnover["current"] > 20000 .OR. hTurnover["last"] > 20000
			nOver20k++
		Endif
	Elseif hTurnover["total"] > 0
		nOldCustomers++
		If hTurnOver["last3"] <= 0
			nVeryOld++
		Endif
		If hTurnOver["total"] >= 1000
			nBigOld++
		Endif
		If hTurnOver["total"] >= 500
			nBig2Old++
		Endif
		If ku->reart >= 2
			nPrivat++
			nPrivLast3 += hTurnOver["last3"]
			nPrivTotal += hTurnOver["total"]
		Endif
	Elseif ang->(dbSeek( ku->Kunde ))
    	nPotentials++
    Elseif nts->(dbSeek(ku->Kunde+ku->Group,.T.))
    	nContacted++
	Else
		nOthers++
	Endif
	nX++
	If nX > 60
		@ 01,31 SAY Space(4)
		nX := 0
	Endif
	ku->(dbSkip())
Enddo
@ 01,00 CLEAR
? "Kunden           ",nCustomers
? "  Umsatz > 500   ",nBigCust
? "  Umsatz > 2500  ",nOver2k5
? "  Umsatz > 10000 ",nOver10k
? "  Umsatz > 20000 ",nOver20k
? "  >= 3 Jahre     ",nLongTerm
? "Alte Kunden      ",nOldCustomers
? HB_AnsiToOem("  älter 3-Jahre  "),nVeryOld
? "  Ums. > 1000    ",nBigOld
? "  Ums. > 500     ",nBig2Old
? "  Brutto-Kunden  ",nPrivat
? "  Ums. Brutto 3J ",nPrivLast3
? "  Ums. Brutto    ",nPrivTotal
? "Interessenten    ",nPotentials
? "Kontaktiert      ",nContacted
? "Sonstige         ",nOthers


Inkey(0,128)