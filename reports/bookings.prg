LOCAL nTotal  := 0
LOCAL nDue    := 0
LOCAL nPrepay := 0
LOCAL nCallOff := 0
LOCAL nCallThis := 0
LOCAL nThisYear := 0
LOCAL nThisMonth := 0
LOCAL cPic := "@E 9,999,999"

NetUse("engauf","auf",.F.,0)
NetUse("engkund","ku",.F.,0)
NetUse("skontoa","ska",.F.,0)
NetUse("artikel","art",.F.,0)
//NetUse("cur","cur",.F.,0)
auf->(dbSetOrder(7)) //abnr+bestat+itmnr

nCurWeek := Val(CalWeek(Date()))
hCustomerCredit := {=>}

Head("Auftragsstruktur")
cScreen := SaveScreen()
PWait()

auf->(dbGoTop())

nYear := Year(Date())
nMonth := Month(Date())


Do While ! auf->(Eof())
	nAbnr := auf->abnr


	ku->(dbSeek(auf->Kundma+"K"))
    ska->(dbGoTo(ku->skonto+1))
  	lPrepay := ska->(IsPrePay(ku->skonto))

  	If lPrepay
  		If ! HHasKey(hCustomerCredit,auf->Kundma)
  			hCustomerCredit[auf->Kundma] := GetCustomerCredit(auf->Kundma)
  		Endif
  	Endif
  	
  	auf->(dbSetFilter( {|| auf->Bestat < 3 },"bestat < 3"))

	Do While auf->abnr == nAbnr
		nOpen := If(auf->bestat<3,auf->vkqty-auf->gelqty,0)
		nDiscount := auf->vkpr-(auf->vkpr*auf->rabatt/100)

		nValue := ROUND( (nOpen*nDiscount/Max(auf->pe,1)) ,2)+Zuschlag(nOpen,auf->Basis)
		nValue *= Currate(auf->money,"V")
		nTotal += nValue
		If auf->dterm <= nCurWeek //due
			nDue += nValue
		ENDIF
      If Right(Str(auf->dterm,4),2)=="99" //call off order
			nCallOff += nValue
			If Year(CalWD(auf->wterm)) <= nYear
				nCallThis += nValue
				//nThisYear += nValue
			Endif
		ELSEIf Year(CalWd(auf->dterm)) <= nYear
			nThisYear += nValue
			If Month(CalWd(auf->dTerm)) <= nMonth
            nThisMonth += nValue
			Endif
		Endif
		If lPrepay
			nPrepay += nValue
		Endif

		auf->(dbSkip())
	Enddo
Enddo

RestScreen(,,,,cScreen)
@ 02,00 SAY "Insgesamt offen        "+Transform(nTotal,cPic)
@ 03,00 SAY "  Vorauskasse          "+Transform(nPrepay,cPic)
@ 04,00 SAY "  dieses Jahr f„llig   "+Transform(nThisYear,cPic)
@ 05,00 SAY "    diesen Monat       "+Transform(nThisMonth,cPic)
@ 06,00 SAY "    bereits f„llig     "+Transform(nDue,cPic)
@ 07,00 SAY "  Abrufauftr„ge        "+Transform(nCallOff,cPic)
@ 08,00 SAY "    mit Ende dieses J. "+Transform(nCallThis,cPic)
Sinkey(0)



