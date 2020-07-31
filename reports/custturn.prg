PROCEDURE RUN_REPORT_CUSTTURN
//number of months to compare the 12-month average with
LOCAL nMonths := 3
LOCAL nAvgTime := 12
LOCAL cVPlz  := Space(8)
LOCAL cTPlz  := Replicate("X",8)
LOCAL aTypes := {"Alle","Nur Positive","Nur Negative"}
LOCAL nType  := 1
LOCAL aMark  := {"Alle","Nur Hervorgehobene"}
LOCAL nMark  := 1
LOCAL nAuf   := 4
LOCAL nVal   := 50
LOCAL getlist := {}
LOCAL hCustomers,hCust
LOCAL dStartDate,nDays,dStDateShort,nDaysShort
LOCAL nCur,stat_val,nValue,nX,nDiff,nPerc
LOCAL oPrinter,oPdf
LOCAL cBlack,cMinus1,cMinus2,cMinus3,cPlus,cColor

MEMVAR c_five

NETUSE( "englsre","re",.F.,5 )
NETUSE( "engauf","auf",.F.,5 )
NetUse( "engkund","ku",.F.,5 )

hCustomers := {=>}

Head("Umsatzentwicklung Kunden")

@ 01,00 SAY t("Anzahl Monate")
Aadd(getlist,Get():new( 01,16,{|x| If(x!=NIL,nMonths:=x,nMonths)},"nMonths","99"))
ATail(getlist):Display()

@ 02,00 SAY t("Vergleich mit")
@ 02,19 SAY "Monate"
Aadd(getlist,Get():new( 02,16,{|x| If(x!=NIL,nAvgTime:=x,nAvgTime)},"nAvgTime","99"))

ATail(getlist):Display()

@ 03,00 SAY "Von PLZ "
Aadd(getlist,Get():new( 03,16,{|x| If(x!=NIL,cVPLZ:=x,cVPLZ)},"cVPLZ"))
ATail(getlist):Display()

@ 04,00 SAY "Bis PLZ "
Aadd(getlist,Get():new( 04,16,{|x| If(x!=NIL,cTPLZ:=x,cTPLZ)},"cTPLZ"))
ATail(getlist):PostBlock := {|| cTPlz > cVPlz }
ATail(getlist):Display()

@ 05,00 SAY "Ausdruck"
@ 05,16,10,35 GET nType LISTBOX aTypes DROPDOWN
@ 06,16,11,35 GET nMark LISTBOX aMark DROPDOWN

@ 07,00 SAY "Markieren ab"
@ 08,00 SAY "  Aufträgen"
Aadd(getlist,Get():new( 08,16,{|x| If(x!=NIL,nAuf:=x,nAuf)},"nAuf"))
ATail(getlist):Display()
@ 09,00 SAY " Wert/Monat"
Aadd(getlist,Get():new( 09,16,{|x| If(x!=NIL,nVal:=x,nVal)},"nVal"))
ATail(getlist):Display()

READ

If LastKey() == 27
	Return
Endif

SetColor(c_five)
@ 07,05 CLEAR TO 10,56
@ 07,05 TO 10,56
@ 08,06 SAY "Ausgangsrechnungen"
@ 09,06 SAY HB_AnsiToOem("Aufträge")


dStartDate := AddMonth(Date(),-nAvgTime)
dStartDate := SToD(Str(Year(dStartDate),4)+StrZero(Month(dStartDate),2)+"01")
nDays := Date()-dStartDate
dStDateShort := AddMonth(Date(),nMonths*-1)
dStDateShort := SToD(Str(Year(dStDateShort),4)+StrZero(Month(dStDateShort),2)+"01")
nDaysShort := Date()-dStDateShort

nCur := 1
re->(dbSetOrder(2))
re->(dbGoTop())
ku->(dbSetOrder( 1 ))
DO while ! RE->(eof()) .AND. re->reposnr == 0
	ku->(dbSeek( re->Kunde+"K" ))
	If Between(ku->PLZ,cVPLZ,cTPlz)
	  	If ! HHasKey(hCustomers,re->Kunde)
	  		hCustomers[re->Kunde] := {"last12"=>0,"comp"=>0,"count12"=>0,"last12-auf"=>0,"comp-auf"=>0,"count12-auf"=>0}
	  	Endif

	    nCur ++
	//    If Int(nCur/100) == nCur/100
			@ 08,26 SAY Str(nCur,12)
	//	Endif

	    stat_val := ( re->poswt - re->preis ) * Currate(re->Money,"V")     // NET VALUE

	    IF re->code > 0	.AND. re->rechdat >= dStartDate // ONLY PRINTED INVOICES AND last 12 months
		  	hCustomers[re->Kunde]["last12"] += stat_val
		  	hCustomers[re->Kunde]["count12"]++
		  	If re->rechdat >= dStDateShort
		  		hCustomers[re->Kunde]["comp"] += stat_val
		  	Endif
	//	    nReVal := ( currate( re->money,"V" ) * ( re->poswt - re->preis ) )
	    ENDIF
	Endif
    re->(dbSkip( 1 ))
ENDDO

nCur := 1
auf->(dbSetOrder(9))
auf->(dbGoTop())
Do While ! auf->(Eof()) .AND. LastKey() != 27
	ku->(dbSeek( auf->Kundma+"K" ))
	If Between(ku->PLZ,cVPLZ,cTPlz)
	  	If ! HHasKey(hCustomers,auf->Kundma)
	  		hCustomers[auf->Kundma] := {"last12"=>0,"comp"=>0,"count12"=>0,"last12-auf"=>0,"comp-auf"=>0,"count12-auf"=>0}
	  	Endif
	
	  	nCur++
		@ 09,26 SAY Str(nCur,12)
	
		nValue := If(auf->Bestat>=3,auf->gelqty, auf->vkqty ) * auf->vkpr/auf->pe*If(!Empty(auf->money),Currate(auf->Money,"V"),1)
		If auf->besda >= dStartDate
	    	hCustomers[auf->Kundma]["last12-auf"] += nValue
	    	hCustomers[auf->Kundma]["count12-auf"]++
	    	If auf->Besda >= dStDateShort
	    		hCustomers[auf->Kundma]["comp-auf"] += nValue
	    	Endif
		Endif
	Endif

	auf->(dbSkip())
Enddo

//Print the results to a PDF
StartPrint(,"TurnoverDevelopment","PDF")
oPrinter := GetCurrentPrinterObject()
oPdf := oPrinter:Data
oPdf:NewPage("A4","P",6)
oPdf:SetFont("HELVETICA",0,12)
oPdf:AtSay("Umsatzentwicklung letzte "+Ltrim(Str(nMonths))+" Monate, "+DtoC(Date()))
oPdf:NewLine()
oPdf:AtSay("Von PLZ "+cVPlz+" bis PLZ "+cTPLZ)
oPdf:NewLine()
oPdf:SetFont("HELVETICA",0,10)
oPdf:AtSay("Die angegebene Werte sind durchschnittliche Monatswerte.")
oPdf:SetFont("COURIER")

oPdf:NewLine()
oPdf:AtSay("Umsatz",,30)
oPdf:AtSay("| Aufträge",,100)
oPdf:NewLine()
oPdf:AtSay("Kunde",,10)
oPdf:AtSay("Anz  "+LTrim(Str(nAvgTime))+" Mon. "+Str(nMonths,2)+" Mon.  %",,30)
oPdf:AtSay("| Anz  "+LTrim(Str(nAvgTime))+" Mon. "+Str(nMonths,2)+" Mon.  %",,100)

cBlack := Chr(0)+Chr(0)+Chr(0)
cMinus1 := Chr(255)+Chr(0)+Chr(0)
cMinus2 := Chr(200)+Chr(0)+Chr(0) //Chr(255)+Chr(160)+Chr(80)
cMinus3 := Chr(170)+Chr(0)+Chr(0) //Chr(255)+Chr(210)+Chr(80)
cPlus   := Chr(0)+Chr(150)+Chr(0)

nX := 1
Do While nX <= Len(hCustomers)
	hCust := HGetValueAt(hCustomers,nX)
	//? HGetKeyAt(hCustomers,nX),hCust["last12"]/nDays*30,hCust["comp"]/nDaysShort
	If hCust["last12"] > 0 .OR. hCust["last12-auf"] > 0 //.AND. hCust["count12"] > 3
		nDiff := hCust["comp"]/nDaysShort - hCust["last12"]/nDays
		nPerc := If(hCust["last12"]>0,nDiff/(hCust["last12"]/nDays),0)
		//If hCust["last12"]/nDays > hCust["comp"]/nDaysShort



			cColor := cBlack
			If hCust["count12"] > nAuf .AND. hCust["comp"]/nDaysShort*30 > nVal
				If nPerc < 0
					cColor := cMinus3
				Endif
				If nPerc <= -0.2
					cColor := cMinus2
				Endif
				If nPerc <= -0.5
					cColor := cMinus1
				Endif
				If nPerc >= 0.5
					cColor := cPlus
				Endif
			Endif
		If nMark == 1 .OR. cColor != cBlack
        	If nType == 1 .OR. (nPerc > 0 .AND. nType == 2) .OR. (nPerc < 0 .AND. nType == 3)
        		oPdf:NewLine()

			   oPdf:AtSay(chr(253)+cBlack+HB_OemToAnsi(HGetKeyAt(hCustomers,nX)),,10)
            oPdf:AtSay(" "+Str(hCust["count12"],3),,30)
			   oPdf:AtSay(" "+chr(253)+cColor+Str(hCust["last12"]/nDays*30,8,2))
			   oPdf:AtSay(" "+Str(hCust["comp"]/nDaysShort*30,8,2))
			   oPdf:AtSay(" "+Str(nPerc*100,7,2)	)

			   nDiff := hCust["comp-auf"]/nDaysShort - hCust["last12-auf"]/nDays
			   nPerc := If(hCust["last12-auf"]>0,nDiff/(hCust["last12-auf"]/nDays),0)

			cColor := cBlack
			If hCust["count12-auf"] > 4
				If nPerc < 0
					cColor := cMinus3
				Endif
				If nPerc <= -0.2
					cColor := cMinus2
				Endif
				If nPerc <= -0.5
					cColor := cMinus1
				Endif
				If nPerc >= 0.5
					cColor := cPlus
				Endif
			Endif

			//oPdf:AtSay(chr(253)+cBlack+HB_OemToAnsi(HGetKeyAt(hCustomers,nX)),,10)
            		oPdf:AtSay(chr(253)+cBlack+"| "+Str(hCust["count12-auf"],3),,100)
			oPdf:AtSay(" "+chr(253)+cColor+Str(hCust["last12-auf"]/nDays*30,8,2))
			oPdf:AtSay(" "+Str(hCust["comp-auf"]/nDaysShort*30,8,2))
			oPdf:AtSay(" "+Str(nPerc*100,7,2)	)
		//Endif
		Endif
		Endif
	Endif
	nX++
Enddo
CopyPrint()
