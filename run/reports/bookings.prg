PROC Run_Reports_Bookings()
LOCAL nTotal  := 0
LOCAL nDue    := 0
LOCAL nPrepay := 0
LOCAL nCallOff := 0
LOCAL nCallThis := 0
LOCAL nThisYear := 0
LOCAL nThisMonthVal := 0
LOCAL hMonths := {=>}
LOCAL cPic := "@E 9,999,999"
LOCAL lPrepay
LOCAL nYear,nMonth,nAbnr,nOpen,nValue,nDiscount
LOCAL hCustomerCredit
LOCAL nCurWeek,nThisMonth
LOCAL nFromThisYear := 0
LOCAL nUnknown := 0
LOCAL hKunden := {=>}

NetUse("engauf","auf",.F.,0)
NetUse("engkund","ku",.F.,0)
NetUse("skontoa","ska",.F.,0)
NetUse("artikel","art",.F.,0)
//NetUse("cur","cur",.F.,0)
auf->(dbSetOrder(7)) //abnr+bestat+itmnr

nCurWeek := Val(CalWeek(Date()))
hCustomerCredit := {=>}

Head("Auftragsstruktur")

TxtBox("Bitte warten...")

auf->(dbSetFilter( {|| auf->Bestat < 3 },"bestat < 3"))
auf->(dbGoTop())

nYear := Year(Date())
nThisMonth := Month(Date())


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
  	
	Do While auf->abnr == nAbnr
		nOpen := If(auf->bestat<3,auf->vkqty-auf->gelqty,0)
		nDiscount := auf->vkpr-(auf->vkpr*auf->rabatt/100)

		nValue := ROUND( (nOpen*nDiscount/Max(auf->pe,1)) ,2)+Zuschlag(nOpen,auf->Basis)
      IF nValue != 0         
         nValue *= Currate(auf->money,"V")

         nTotal += nValue

         IF ! HHasKey(hKunden,auf->Kundma)
            hKunden[auf->Kundma] := 0
         Endif
         hKunden[auf->Kundma] += nValue

         IF Year(auf->Besda) == nYear
            nFromThisYear += nValue
         ENDIF

         If Right(Str(auf->dterm,4),2)=="99" //call off order
            nCallOff += nValue
            If Year(CalWD(auf->wterm)) <= nYear
               nCallThis += nValue
               //nThisYear += nValue
            Endif
         ELSEIF Right(Str(auf->dterm,4),2) $ {"97","98"}
            nUnknown += nValue
         ELSEIf Year(CalWd(auf->dterm)) <= nYear 
            nThisYear += nValue
            
            IF Year(CalWd(auf->dterm)) < nYear
               nMonth := 0
               
            ELSE
               nMonth := Month(CalWd(auf->dTerm))
            ENDIF
            IF ! HHasKey(hMonths,nMonth)
               hMonths[nMonth] := 0
            Endif
            hMonths[nMonth] += nValue

            If auf->dterm <= nCurWeek // due
               nDue += nValue
            ELSEIf Month(CalWd(auf->dTerm)) == nThisMonth
               nThisMonthVal += nValue
            Endif
         Endif
         If lPrepay
            nPrepay += nValue
         Endif
      ENDIF

		auf->(dbSkip())
	Enddo
Enddo

TxtClear()
@ 02,00 SAY "Insgesamt offen        "+Transform(nTotal,cPic)
@ 03,00 SAY "  Auftrag aus "+LTrim(Str(nYear,4))+"     "+Transform(nFromThisYear,cPic)
@ 04,00 SAY "  Vorauskasse          "+Transform(nPrepay,cPic)
@ 05,00 SAY "  dieses Jahr f„llig   "+Transform(nThisYear,cPic)
@ 06,00 SAY "    diesen Monat       "+Transform(nThisMonthVal,cPic)
@ 07,00 SAY "    bereits f„llig     "+Transform(nDue,cPic)
FOR nX := 0 TO Len(hMonths)
   IF HHasKey(hMonths,nX)
      nValue := hMonths[nX]
      ? "    "+Pad(IF(nX==0,"Vor "+Str(nYear,4),CMonth(StoD(Str(nYear,4)+StrZero(nX,2)+"01")) + " " + Str(nYear)),19) + "   "+Transform(nValue,cPic)
   ENDIF
NEXT
? "  Unbekannt            "+Transform(nUnknown,cPic)
? "  Abrufauftr„ge        "+Transform(nCallOff,cPic)
? "    mit Ende dieses J. "+Transform(nCallThis,cPic)

aKunden := {}
HEval(hKunden, {|cKundma,nValue| AAdd(aKunden,{cKundma,nValue})})

aKunden := ASort(aKunden,,,{|a,b| a[2] > b[2] })
? "Top 10 Kunden:"
FOR nX := 1 TO 10
   nValue := aKunden[nX][2]
   cKundma := aKunden[nX][1]

   ku->(dbSeek(cKundma+"K"))
   
   ? "  "+Pad(Trim(ku->Name1)+" "+ku->Name2,30)+" "+Transform(nValue,cPic)
NEXT   


Sinkey(0)



