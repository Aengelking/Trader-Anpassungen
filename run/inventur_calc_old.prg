Head("Inventur")
NetUse("artikel","art",.F.,0)
NetUse("werkauf","wer",.F.,0)
art->(dbGoTop())

nWaren := 0
nRHB := 0
nUnfertig := 0

//nType := TR_MsgBox("Preisbasis",,{"Letzte EK","D/S Preis"})
nType := 2 //D/S Preise
dDate := Date() //GetBox(Date(),"Datum","99.99.99")

//dDate := Date()
If dDate < Date()
	Alert("Smaller date!")
	/*NetUse("engabg","abg",.T.,0)
	abg->(dbReindex())*/
	NetUse("engabg","abg",.F.,0)
	abg->(dbSetOrder(3)) //matchcode+DTos(Transdate)+TransTime
Endif
cList := ""
cUnfert := ""
Do While ! art->(Eof())
	nBestand := art->Bestand
	If dDate < Date()
//		@ 01,00 SAY art->Matchcode
//		abg->(dbSeek(art->Matchcode+DToS(dDate),.T.))
		abg->(dbSeek(art->Matchcode,.T.))
		//@ 02,00 SAY abg->Matchcode
		nBestand := 0
		lFound := .F.
		dFoundDate := Date()
		Do While abg->Matchcode == art->Matchcode .AND. ! abg->(Eof()) .AND. abg->TransDate <= dDate//! lFound
			//? abg->Buart,abg->TransDate,abg->Bestand
			//If abg->TransDate < dDate
			If ! abg->BuArt $ "STD" .AND. abg->Bestand >= 0
				nBestand := abg->Bestand
				//EXIT
				lFound := .T.
				dFoundDate := abg->Transdate
			Endif
			abg->(dbSkip(1))
		Enddo
		If art->Bestand != nBestand
			abg->(dbSkip( -1 ))
			cList += art->Matchcode+Str(art->Bestand)+Str(nBestand)+" "+DToC(dFoundDate)+Chr(10)+Chr(13)
		Endif
	Endif

	If nBestand > 0
		@ 24,00 SAY art->Matchcode
		nPreis := If(nType==2,art->avpreis,art->letzte_ek/art->pe*Currate(art->money,"E"))
		If art->Bezug >= 5
			nPreis := StCalc(art->artikelnr,If(nType==2,5,1),99,.T.)
		Endif
		nValue := nBestand*nPreis
		@ 24,27 SAY Str(nValue,12,2)
				If nValue > 10000
					//Alert(art->Matchcode+Str(nvalue))
				Endif
		/*If art->Gruppe == "ENTW"
			If art->Bezug >= 5  //Unfertige Erzeugnisse
				nUnfertig += nValue
			Else
				nRHB +=  nValue
			Endif
		Else
			//für bulgin artikel vkpreis2?? oder netto_ek??
			nWaren += nValue
		Endif*/
		If Trim(art->Type) == "RHB"
			nRHB += nValue
		Elseif Trim(art->Type) == "UNFER"
			cUnfert += art->Matchcode+Str(nvalue)+Chr(13)+Chr(10)
			nUnfertig += nValue
		Else
			nWaren += nValue
		Endif
	Endif
	art->(dbSkip())
Enddo
wer->(dbGoTop())
Do While ! wer->(Eof())
	if wer->Status < 4 .AND. wer->Status >= 3
		art->(dbSetOrder(2))
		art->(dbSeek(Str(wer->artno,6)))
		nGelQty := wer->gelqty



		@ 24,00 SAY art->Matchcode
		nPrice := StCalc(wer->artno,If(nType==2,5,1),99,.F.)
		nValue := (wer->qty-nGelqty)*nPrice*Currate(art->money,"E")
		If nValue > 10000
                	Alert(art->Matchcode+Str(nvalue))
                Endif
                cUnfert += art->Matchcode+Str(nvalue)+Chr(13)+Chr(10)
		nUnfertig += nValue

	Endif
	wer->(dbSkip())
Enddo
/*StartPrint()
SET DEVICE TO PRINTER
SET PRINTER ON
? cList
SET PRINTER OFF
SET DEVICE TO SCREEN
CopyPrint()*/
//MemoEdit/(cUnfert)
SetCursor(.T.)
If dDate < Date()
	MemoEdit(cList)
Endif

@ 24,00 CLEAR
@ 02,00 SAY "Waren und Fertigerzeugnisse    "+Str(nWaren,12,2)
@ 03,00 SAY "Roh-, Hilfs- u. Betriebsstoffe "+Str(nRHB,12,2)
@ 04,00 SAY "unfertige Erzeugnisse          "+Str(nUnfertig,12,2)
nChoice := 0
Do While nChoice != 1 .AND. LastKey() != 27
	nChoice := AMenu({"Verlassen","Drucken",t("In Lexware übertragen")})
	If nChoice == 2
		BeginJob()
		StartPrint(,"VAR","PDF")
		oP := getCurrentPrinterObject()

		oP:Data:NewPage("A4","P",6)
		Conv("\17\\arialb,14\\y,80\\x,30\Inventur vom "+DToC(Date()),oP)
		oP:Data:REPORTLINE++;oP:Data:REPORTCOL := 0
		Conv("\1\\y,100\\x,30\Waren und Fertigerzeugnisse    "+Str(nWaren,12,2),oP)
		oP:Data:REPORTLINE++;oP:Data:REPORTCOL := 0
	    Conv("\x,30\Roh-, Hilfs- u. Betriebsstoffe "+Str(nRHB,12,2),oP)
		oP:Data:REPORTLINE++;oP:Data:REPORTCOL := 0
	    Conv("\x,30\unfertige Erzeugnisse          "+Str(nUnfertig,12,2),oP)
		oP:Data:REPORTLINE+=2;oP:Data:REPORTCOL := 0
	    Conv("\x,30\Gesamt                         "+Str(nWaren+nRHB+nUnfertig,12,2),oP)
	    /*If Lx_Start()
	    	oP:Data:REPORTLINE+=2;oP:Data:REPORTCOL := 0
	    	Conv("Buchungen")
	    	oP:Data:REPORTLINE+=1;oP:Data:REPORTCOL := 0
			oP:AtSay(Str(Lx_GetSaldo(8510,Date()),12,2))
	    Endif*/
		CopyPrint()
		EndJob()
	Elseif nChoice == 3
		hKonten := {"WARE"=>7140,"RHB"=>3970,"UNFERT"=>7050}
		hVerKonten := {"WARE"=>8980,"RHB"=>3960,"UNFERT"=>8960}
		hDiff := {"WARE"=>0,"RHB"=>0,"UNFERT"=>0}

		dDate := GetBox(dDate,"Buchungsdatum")

		LX_Start()
		//LX_CreateBooking(hData)
		//hData := {dBelegDate,dBookDate,cText,nHaben,nSoll,nBrutto,cBelegKreis}

		nSaldoW := LX_GetSaldo(hKonten["WARE"],dDate)
		@ 02,47 SAY Str(nSaldoW,12,2)
		@ 02,60 SAY Str(nSaldoW-nWaren,12,2)
                hDiff["WARE"] := nSaldoW-nWaren
		nSaldoR := LX_GetSaldo(hKonten["RHB"],dDate)
		@ 03,47 SAY Str(nSaldoR,12,2)
		@ 03,60 SAY Str(nSaldoR-nRHB,12,2)
		hDiff["RHB"] := nSaldoR-nRHB
		nSaldoU := LX_GetSaldo(hKonten["UNFERT"],dDate)
		@ 04,47 SAY Str(nSaldoU,12,2)
		@ 04,60 SAY Str(nSaldoU-nUnfertig,12,2)
		hDiff["UNFERT"] := nSaldoU-nUnfertig

		If TR_MsgBox(t("Buchungen durchführen?"),,{"Nein","Ja"}) == 2
			cMessage := ""
			nX := 1
			Do While nX <= 3
				cKey := HGetKeyAt(hKonten,nX)
				If Round(hDiff[cKey],2) != 0
					nSoll := nHaben := 0
					If hDiff[cKey] >= 0
						nSoll  := hVerKonten[cKey]
						nHaben := hKonten[cKey]
					Else
						nHaben  := hVerKonten[cKey]
						nSoll := hKonten[cKey]
					Endif
					? "Buche: S"+LTrim(Str(nSoll))+" H"+LTrim(Str(nHaben))+" "+LTrim(Str(Abs(Round(hDiff[cKey],2))))
	
					hData := {=>}
					hData:nBelegNr   := 0
					hData:dBelegDate := dDate
					hData:dBookDate  := dDate
					hData:cText      := "Inventur"
					hData:nHaben     := nHaben
					hData:nSoll      := nSoll
					hData:nBrutto    := Round(Abs(hDiff[cKey]),2)
					hData:cBelegKreis := NIL

					If ! LX_CreateBooking(hData,.F.)
						cMessage += "Buchung S"+LTrim(Str(nSoll))+" H"+LTrim(Str(nHaben))+" fehlgeschlagen!"+Chr(59)
						cMessage += LX_GetErrorMessage()+Chr(59)
					Endif
				Endif

				nX++
			Enddo
			If ! Empty(cMessage)
				Alert(cMessage)
			Endif
			Return
		Endif
	Endif
Enddo
//SInkey(0)