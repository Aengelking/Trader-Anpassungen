LOCAL cFile := Trim(Tr_getini(1))+"\export\visitshead.csv"
NetUse("notes","nts",.F.,0)
NetUse("engkund","ku",.F.,0)
NetUse("buyer","buy",.F.,0)
NetUse("englsre","re",.F.,0)
NetUse("engauf","auf",.F.,0)
NetUse("angebot","ang",.F.,0)


dVon := Date()-365
dBis := Date()

hHeads := {=>}

Head("Analyse Kundenbesuche pro Mitarbeiter")

@ 01,00 SAY "Ab Datum " GET dVon
@ 02,00 SAY "Bis Datum" GET dBis
READ

ku->(dbSetOrder( 1 ))

auf->(dbSetOrder( 9 )) //kundma+dtos(besda)
nts->(dbSetOrder( 1 ))  //Matchcode+Group+descend(Dtos(date)+Time)
ang->(dbSetOrder(7))

nts->(dbGoTop())

SET PRINTER TO (Trim(Tr_getini(1))+"\export\visits.csv")
SET PRINTER ON



?? "Kunde"+Chr(59)+"Mitarbeiter"+Chr(59)+"Datum"+Chr(59)
?? "Besuche"+Chr(59)
?? "Umsatz 12 Monate vorher"+Chr(59)+"Umsatz danach"+Chr(59)
?? "Umsatz dananch alte Produkte"+Chr(59)+"Umsatz danach neue Produkte"+Chr(59)
?? "Aufträge 12 Monate vorher"+Chr(59)+"Aufträge danach"+Chr(59)
?? "Aufträge danach alte Produkte"+Chr(59)+"Aufträge danach neue Produkte"+Chr(59)
?? "Offene Angebote danach"+Chr(59)+"Angebote danach"
Do While ! nts->(Eof()) .AND. Inkey() != 27

	If nts->Group == "K" .AND. Trim(nts->Type) == "VISIT" .AND. nts->Date >= dVon .AND. nts->Date <= dBis .AND. Trim(nts->Matchcode) != "TEST"
		ku->(dbSeek( nts->Matchcode+"K" ))


		nVisits := 0
		dDate := nts->Date
		nBuy  := nts->Buyer
		nRec  := nts->(Recno())
		Do While nts->Matchcode == ku->Kunde .AND. nts->Group == "K"
			If nts->Date >= dVon .AND. nts->Date <= dBis .AND. Trim(nts->Type) == "VISIT"
				If ! HHaskey(hHeads,nts->Buyer)
					hHeads[nts->Buyer] := {"weeks"=>{=>}}
				Endif
				If ! HHaskey(hHeads[nts->Buyer]["weeks"],CalWeek(nts->Date))
	                        	hHeads[nts->Buyer]["weeks"][CalWeek(nts->Date)] := {}
	                        Endif
	                        If dDate > nts->Date
	                        	dDate := nts->Date
	                        	nBuy  := nts->Buyer
	                        Endif
	                        Aadd(hHeads[nts->Buyer]["weeks"][CalWeek(nts->Date)],{"kunde"=>nts->Matchcode,"datum"=>nts->Date})
				nVisits ++
				nRec := nts->(Recno())
			Endif
			nts->(dbSkip())
		Enddo
		nts->(dbGoTo(nRec))

		//collect old products
		aArtBefore := {}
		re->(dbSetOrder( 1 ))
		re->(dbSeek( nts->Matchcode ))
		Do While re->Kunde == nts->Matchcode .AND. ! re->(eof())
			If re->Reposnr != 0 .AND. re->Rechdat < dDate
				If Ascan(aArtBefore,re->Matchcode) == 0
					Aadd(aArtBefore,re->Matchcode)
				Endif
			Endif
			re->(dbSkip())
		Enddo

                re->(dbSetOrder( 2 )) //Str(reposnr)+Kunde
		re->(dbSeek( Str(0,3)+nts->Matchcode ))

		nBefore := 0
		nAfter := 0

		nAfterNew := 0
		nAfterOld := 0
		hRech := {=>}
		Do While re->Kunde == nts->Matchcode .AND. re->Reposnr == 0 .AND. ! re->(eof())
			hRech[re->Rechnr] := re->Rechdat
			nValue := ( re->poswt - re->preis ) * Currate(re->Money,"V")  //netto
			If re->Rechdat >= dDate
				nAfter += nValue
			Elseif re->Rechdat >= dDate-365
				nBefore +=  nValue
			Endif
			re->(dbSkip())
		Enddo

		re->(dbSetOrder( 1 ))
		re->(dbSeek( nts->Matchcode ))

		Do While re->Kunde == nts->Matchcode .AND. ! re->(Eof())
			If re->Reposnr != 0
				If HHasKey(hRech,re->Rechnr) .AND. hRech[re->Rechnr] >= dDate
					If Ascan(aArtBefore,re->Matchcode) == 0  //neues Produkt
						nAfterNew += re->poswt
					Else
						nAfterOld += re->poswt
					Endif
				Endif
			Endif

			re->(dbSkip())
		Enddo
		nAufBef := 0
		nAufAft := 0
		nAufAftNew := 0
		nAufAftOld := 0
		auf->(dbSeek( nts->Matchcode+Dtos(dDate-365), .T. ))
		Do While auf->Kundma == nts->Matchcode .AND. auf->Besda >= dDate-365 .AND. ! auf->(Eof())
			nValue := If(auf->Bestat>=3,auf->gelqty, auf->vkqty ) * auf->vkpr/auf->pe*If(!Empty(auf->money),Currate(auf->Money,"V"),1)
			If auf->Besda >= dDate
				nAufAft += nValue
				If Ascan(aArtBefore,auf->Matchcode) == 0  //neues Produkt
					nAufAftNew += nValue
				Else
					nAufAftOld += nValue
				Endif
			Elseif auf->Besda >= dDate-365
				nAufBef += nValue
			Endif
			auf->(dbSkip())
		Enddo

		nQuoteMax := 0
		nQuoteAfter := 0
                ang->(dbSeek(nts->Matchcode))
		Do While ! ang->(Eof()) .AND. ang->Kundma == nts->Matchcode
			If ang->Besda >= dDate
				aValue := EnquiryAddUp(ang->angnr,.T.)
				//aTotal[1] += aValue[1]
				nQuoteMax += aValue[2]
				aValue := EnquiryAddUp(ang->angnr,.F.)
				nQuoteAfter += aValue[2]
			Endif
			nAngnr := ang->angnr
			While ang->angnr == nAngnr
				ang->(dbSkip())
			Enddo
		Enddo

		? HB_OemToAnsi(nts->Matchcode)+Chr(59)+HB_OemToAnsi(Trim(Buy(nBuy,.T.)))+Chr(59)+DtoC(dDate)+Chr(59)
		?? StrTran(Str(nVisits,12,2),".",",")+Chr(59)
		?? StrTran(Str(nBefore,12,2),".",",")+Chr(59)+StrTran(Str(nAfter,12,2),".",",")+Chr(59)
		?? StrTran(Str(nAfterOld,12,2),".",",")+Chr(59)+StrTran(Str(nAfterNew,12,2),".",",")+Chr(59)
                ?? StrTran(Str(nAufBef,12,2),".",",")+Chr(59)+StrTran(Str(nAufAft,12,2),".",",")+Chr(59)
                ?? StrTran(Str(nAufAftOld,12,2),".",",")+Chr(59)+StrTran(Str(nAufAftNew,12,2),".",",")+Chr(59)
                ?? StrTran(Str(nQuoteMax,12,2),".",",")+Chr(59)+StrTran(Str(nQuoteAfter,12,2),".",",")+Chr(59)
	Endif
	nts->(dbSkip())
Enddo

SET PRINTER TO (cFile)

//? "Kunde"

nB := 1
Do While nB <= Len(hHeads)
	nBuy := HGetKeyAt(hHeads,nB) //,.F.)
	// ["weeks"][CalWeek(nts->Date)
	? nBuy,Buy(nBuy,.T.)
	nW := 1
	Do While nW <= Len(hHeads[nBuy]["weeks"])
		cWeek := HGetKeyAt(hHeads[nBuy]["weeks"],nW)
		? NiceWeek(Val(cWeek))+Chr(59)+Str(Len(hHeads[nBuy]["weeks"][cWeek]),2)
		nK := 1
		Do While nK <= Len(hHeads[nBuy]["weeks"][cWeek])
			? hHeads[nBuy]["weeks"][cWeek][nK]["kunde"]+Chr(59)+DToc(hHeads[nBuy]["weeks"][cWeek][nK]["datum"])
			nK++
		Enddo
		nW++
	Enddo
nB++
Enddo
SET PRINTER TO
SET PRINTER OFF

WAPI_ShellExecute(,"open",cFile)
//Inkey(0)