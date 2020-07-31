//number of months to compare the 12-month average with
nMonths := 1


NETUSE( "engkund","ku",.F.,5 )
ku->(dbSetOrder( 2 ))

nYear := 0
Do While nYear > Year(Date()) .OR. nYear == 0
	nYear := GetBox(Year(Date())-1,"Jahr")
Enddo

hCustomers := {=>}

SetColor(c_five)
@ 07,05 CLEAR TO 10,56
@ 07,05 TO 10,56
@ 08,06 SAY "Umsatz neuer Kunden "+Str(Year(Date())-1)

//Print the results to a PDF
StartPrint(,"TurnoverNewCustomers","PDF")
oPrinter := GetCurrentPrinterObject()
oPdf := oPrinter:Data
oPdf:NewPage("A4","P",6)
oPdf:SetFont("HELVETICA",0,12)
oPdf:AtSay("Umsatz neuer Kunden "+Str(nYear,4))
oPdf:NewLine()
oPdf:SetFont("COURIER")

oPdf:NewLine()
oPdf:Bold()
oPdf:AtSay("Kunde",,10)
oPdf:AtSay(" Land",,30)
oPdf:AtSay(" Umsatz",,100)
oPdf:Normal()

nX := 0
nOver10k := 0
nOver20k := 0
nOver300 := 0
nForeign := 0
nForeignOver500 := 0
nForeignOver20k := 0
ku->(dbSeek( "K" ))
Do While ku->Group == "K" .AND. ! ku->(Eof())
	@ 09,06 SAY ku->Kunde
	hTurn := GetCustomerTurnover(ku->Kunde)
	If HhasKey(hTurn["years"],nYear) .AND. hTurn["years"][nYear] != 0  .AND. HGetPos(hTurn["years"],nYear) == 1 //hTurn["total"] == hTurn["years"][nYear]
		oPdf:NewLine()

		oPdf:AtSay(HB_OemToAnsi(ku->Kunde),,10)
		oPdf:AtSay(" "+HB_OemToAnsi(GetCountryName(ku->CountryIso)),,30)
		oPdf:AtSay(" "+Str(hTurn["years"][nYear],8,2),,100)
		If ! Empty(ku->CountryIso) .AND. ku->CountryIso != "DE"
			nForeign ++
			If hTurn["years"][nYear] > 20000
				nForeignOver20k ++
			Endif
			If hTurn["years"][nYear] > 500
				nForeignOver500 ++
			Endif
		Else
			If hTurn["years"][nYear] > 10000
				nOver10k ++
			Endif
			If hTurn["years"][nYear] > 20000
				nOver20k ++
			Endif
			If hTurn["years"][nYear] > 300
				nOver300 ++
			Endif
		Endif
		nX++
	Endif
	ku->(dbSkip())
Enddo
oPdf:NewLine()
oPdf:NewLine()
oPdf:AtSay("Anzahl neuer Kunden")
oPdf:AtSAy(LTrim(Str(nX)),,100)
oPdf:NewLine()
oPdf:AtSay("Inland > 300 EUR",,30)
oPdf:AtSAy(LTrim(Str(nOver300)),,100)
oPdf:NewLine()
oPdf:AtSay("Inland > 10.000 EUR",,30)
oPdf:AtSAy(LTrim(Str(nOver10k)),,100)
oPdf:NewLine()
oPdf:AtSay("Inland > 20.000 EUR",,30)
oPdf:AtSAy(LTrim(Str(nOver20k)),,100)
oPdf:NewLine()
oPdf:AtSay("Ausland",,30)
oPdf:AtSAy(LTrim(Str(nForeign)),,100)
oPdf:NewLine()
oPdf:AtSay("Ausland > 500 EUR",,30)
oPdf:AtSAy(LTrim(Str(nForeignOver500)),,100)
oPdf:NewLine()
oPdf:AtSay("Ausland > 20.000 EUR",,30)
oPdf:AtSAy(LTrim(Str(nForeignOver20k)),,100)

CopyPrint()

