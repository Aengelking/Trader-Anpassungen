NetUse("engkund","ku",.F.,0)
ku->(dbSetOrder( 2 ))
ku->(dbSeek( "K" ))

Head(HB_AnsiToOem("Kreditlimits überprüfen"))
SetPos(00,00)
? Pad("Matchcode",8),Pad("Name",35),Pad("Kreditlimit",10),Pad("3-Jahresumsatz",10),Pad("Umsatz",10)
Do While ku->Group == "K" .AND. ! ku->(Eof())
	hTurnover := GetCustomerTurnover(ku->kunde)
	If /*ku->credlimit > 3000 .AND.*/ hTurnover["last3"] < ku->credlimit .AND. hTurnover["current"]*1.5 < ku->credlimit .AND. hTurnover["last"]*1.5 < ku->credlimit
		If hTurnover["last3"] == 0 .OR. hTurnover["total"] < 1500 .OR. (hTurnover["current"] < 1500 .AND. hTurnover["last"] < 1500 .AND. Date() > CToD("01.09."+Str(Year(),4)))
			Bewegung({"STM",2,Date(),0,ku->Nummer,0,0,0,0,HB_AnsiToOem("Kreditlimit von "+LTrim(Str(ku->CredLimit,12,0))+" auf 0 reduziert [automatisch]"),0,0,ku->Group,0})
			ku->(Rec_Lock(0))
			ku->credlimit := 0
			ku->(dbUnLock())
		Else
			? ku->kunde,ku->Name1,Str(ku->credlimit,10,0),Str(hTurnover["last3"],10,0),Str(hTurnover["current"],10,0)
		Endif
	Endif
	ku->(dbSkip())
Enddo

Inkey(0,128)

