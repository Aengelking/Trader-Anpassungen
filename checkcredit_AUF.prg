NetUse("engkund","ku",.F.,0)
ku->(dbSetOrder( 2 ))
ku->(dbSeek( "K" ))

NetUse("skontoa","sk",.F.,0)

Head(HB_AnsiToOem("Kreditlimits überprüfen"))
SetPos(00,00)
? Pad("Matchcode",8),Pad("Name",35),Pad("Kreditlimit",10),Pad(t("Offen Aufträge"),10),Pad("Offene Rechnungen",10)
Do While ku->Group == "K" .AND. ! ku->(Eof())
	If ! sk->(IsPrePay(ku->Skonto))
		hTurnover := GetCustomerTurnover(ku->kunde)
		nOpenAuf := GetCustomerOpenOrders(ku->kunde,.T.)
		nCredit :=GetCustomerCreditLimit(ku->Kunde)
		If nOpenAuf > 0 .AND. hTurnover["open"]+nOpenAuf > nCredit
                        nCreditNew := Hook("get_customercreditlimit",{ku->Nummer,ku->Kunde,hTurnover["open"]+nOpenAuf})
                        If nCreditNew >= hTurnover["open"]+nOpenAuf
				Bewegung({"STM",2,Date(),0,ku->Nummer,0,0,0,0,HB_AnsiToOem("Kreditlimit von "+LTrim(Str(ku->CredLimit,12,0))+" auf "+LTrim(Str(hTurnover["open"]+nOpenAuf,12,0))+" erhöht [automatisch]"),0,0,ku->Group,0})

                        	ku->(Rec_Lock())
                        	ku->credlimit := hTurnover["open"]+nOpenAuf
                        	ku->(dbUnLock())
                        Else
				? ku->kunde,ku->Name1,Str(nCredit,10,0),Str(nOpenAuf,10,0),Str(hTurnover["open"],10,0)
			Endif
		Endif
	Endif
	ku->(dbSkip())
Enddo
? "...done..."
SInkey(0)