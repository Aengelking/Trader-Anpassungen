Head("Export addresses for Blackberry")

NetUse("engkund","ku",.F.,0)
NetUse("angebot","ang",.F.,0)
NetUse("engauf","auf",.F.,0)
NetUse("contacts","conts",.F.,0)

nF := Fcreate(Trim(Tr_getini(1))+"\export\addressbook.csv")
If nF <= 0
	MsgBox("Error creating file ("+LTrim(Str(Ferror()))+")")
Else

//write the header
FWrite(nF,'"Last Name","Company Name","Work Phone","Fax","Mobile Phone","Email Address 1","Address1","City","Zip/Postal Code","Country"')

ku->(dbGoTop())
nCount := 0
Do While ! ku->(Eof())
	ang->(dbSetORder(2))
	auf->(dbSetOrder(2))
	
	cKunde := ku->Kunde
	nInq := GetCustomerOpenEnquiries(cKunde)[2]
	nTurn := GetCustomerCTurnover("last3",cKunde)
	nTurn2 := ku->Turnover
	nOrders := GetSupplierOpenOrders(cKunde)
	lNew := ku->K_Seit >= Date()-365

	If (ku->Group == "K"  .AND. (nInq > 0 .OR. nTurn > 0 .OR. lNew)) .OR. (ku->Group == "L" .AND. (nOrders > 0 .OR. nTurn2 > 0))

		conts->(dbSetOrder(2))
		conts->(dbSeek( Str(ku->Nummer,6) ))

		Do While ! conts->(Eof()) .AND. conts->Address == ku->Nummer
			nCount ++
			FWrite(nF,Chr(13)+Chr(10)+'"'+Trim(StrTran(HB_OemToAnsi(conts->Name),'"',''))+'","'+Trim(StrTran(HB_OemToAnsi(Trim(ku->Name1)+" "+ku->Name2),'"',''))+'",')
			cPhone := ku->Telefon
			If At("-",conts->telephone) == 1
				cPhone := SubStr(cPhone,0,RAt("-",cPhone)-1)+conts->telephone
			Elseif ! Empty(conts->telephone)
				cPhone := conts->telephone
			Endif
			FWrite(nF,'"'+Trim(StrTran(cPhone,'"',''))+'",')
			cFax := ku->TeleFax
			If At("-",conts->Fax) == 1
				cFax := SubStr(cFax,0,RAt("-",cFax)-1)+conts->Fax
			Elseif ! Empty(conts->fax)
				cFax := conts->fax
			Endif
            FWrite(nF,'"'+Trim(StrTran(cFax,'"',''))+'","'+Trim(StrTran(conts->Mobile,'"',''))+'","'+Trim(StrTran(conts->Email,'"',''))+'",')
            FWrite(nF,'"'+Trim(StrTran(HB_OemToAnsi(ku->Street),'"',''))+'","'+Trim(StrTran(HB_OemToAnsi(ku->Town),'"',''))+'","'+Trim(StrTran(ku->Plz,'"',''))+'","'+Trim(GetCountryName(ku->CountryIso))+'"')
			conts->(dbSkip())
		Enddo
	Endif
	ku->(dbSkip())
Enddo
FClose(nF)
@ 01,00 SAY "Anzahl: "+Str(nCount)
Inkey(0,128)
Endif

/*
First Name
Middle Name
Last Name
Title
Company Name
Work Phone
Work Phone2
Home Phone
Home Phone2
Other Phone
Fax
Mobile Phone
PIN
Pager
Email Address 1
Email Address 2
Email Address 3
Address1
Address2
Address3
City
State/Prov
Zip/Postal Code
Country

*/