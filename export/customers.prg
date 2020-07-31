Head("Kunden als CSV exportieren")
NetUse("engkund","ku",.f.,0)
ku->(dbSetOrder(2))
ku->(dbSeek("K",.T.))
NetUse("countrie","ctr",.F.,0)
NetUse("lagerne","lne",.F.,0)
NetUse("muster","mus",.F.,0)

nCount := 0
//nFormat := MsgBox("Format",,{"UPS","DHL"})
nFormat := 1
d := If(nFormat==2,Chr(59),Chr(254))

aCustomers := {}

lne->(dbGoTop())
Do While ! lne->(Eof()) //.AND. nCount < 150
	If ! Empty(lne->Kunde) .AND. AScan(aCustomers,lne->Gruppe+lne->Kunde) == 0
		//? nCount,lne->Kunde,lne->Gruppe
		Aadd(aCustomers,lne->Gruppe+lne->Kunde)
		//nCount++
	Endif

	lne->(dbSkip())
Enddo

mus->(dbGoTop())
Do While ! mus->(Eof()) //.AND. nCount < 150
	If AScan(aCustomers,"K"+mus->Kunde) == 0
		//? nCount,mus->Kunde
		Aadd(aCustomers,"K"+mus->Kunde)
		//nCount++
	Endif
 	mus->(dbSkip())
Enddo

//Inkey(0)
nCount := 0

SET PRINTER TO (Trim(Tr_Getini(1))+"\export\customers.csv")
SET PRINTER ON
ku->(dbGoTop())
While ! ku->(Eof()) //ku->group == "K" //.AND. nCount <= 100
	cCountry := "DE"
	If ! ku->Kunde $ "$DEFAULT GRUPPEN" .AND. ! Empty(ku->PLZ) .AND. ! Empty(ku->Street) .AND. (AScan(aCustomers,ku->Group+ku->kunde) != 0 .OR. ! Empty(GetCustomerCTurnover("last3",ku->Kunde)) .OR. GetCustomerOpenOrders(ku->Kunde) > 0)
/*		If ctr->(dbSeek(ku->country))
			cCountry := ctr->Short
		Endif*/
		SET DEVICE TO PRINTER
		SET CONSOLE OFF
		If nFormat == 2
			? LTrim(Str(nCount))+d+HB_OemToAnsi(Pad(ku->name1,30)+d+Pad(ku->street,30)+d+d+ku->PLZ+d+Pad(ku->Town,30)+d+ku->CountryIso+d+Pad(ku->Name2,30)+d+d+ku->Kunde+d+ku->Telefon+d+ku->telefax+d+ku->email+d+ku->vatnr+d+(ku->(GetContact(1))["name"])+d)
		Else
			cP := Str(ku->Nummer)+d
			cP := ku->Kunde+d
			cP += ku->name1+d
			cP += ku->name2+d
			cP += ku->(GetContact(1))["department"]+d
			cP += ku->street+d+d
			cP += d
			cP += GetCountryName(ku->CountryIso)+d
			cP += SubStr(ku->PLZ,At("-",ku->PLZ)+1)+d
			cP += ku->Town+d
			cP += ku->VatNr+d
			cP += d
			cP += ku->(GetContact(1))["name"]+d
			cP += Pad(ku->Telefon,15)+d
			cP += ku->(GetContact(1))["email"]+d
			cP += ku->Telefax+d
			cp += d
			? HB_OemToAnsi(StrTran(StrTran(cP,","," "),Chr(254),","))

		Endif
		SET DEVICE TO SCREEN
		SET CONSOLE ON
		nCount++

		@ 24,00 SAY nCount
	Endif
	ku->(dbSkip())
end

//Inkey(0)
