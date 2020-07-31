
NetUse("engkund","ku",.F.,0)
ku->(dbGoTop())
aTurn := {}
nMax := 100
cHead := LTrim(Str(nMax))+" Umsatzstaerksten Kunden "

Head(HB_AnsiToOem("Umsatzstärksten Kunden"))

aChoice := {Str(Year(Date()),4)+" mit Umsatz und Anteil",Str(Year(Date()),4)+" mit Anteil",Str(Year(Date())-1,4)+" mit Umsatz und Anteil",Str(Year(Date())-1,4)+" mit Anteil",Str(Year(Date())-2,4)+" mit Umsatz und Anteil",Str(Year(Date())-2,4)+" mit Anteil"}

nChoice := AMenu(aChoice)

//nYear := MsgBox("Jahr?",,{Str(Year(Date()),4),Str(Year(Date())-1,4)})
//If nYear == 2

nYear := Year(Date())
If nChoice >= 5
	nYear := Year(Date())-2
Elseif nChoice >= 3
	nYear := Year(Date())-1
Endif
cYear := Str(nYear,4)

Head(cHead+cYear)

//lPrint :=  (MsgBox("Drucken?",,{"Nein","Ja"}) == 2)
lPrint := .T.
@ 01,00 SAY "Daten werden gesammelt..."
nCount := 0
nTotal := 0
/*nForeign := 0
nForeignAk := 0*/
Do While ! ku->(Eof())
	If ku->Group == "K"
		nCount++
		/*If ! Empty(ku->Country) .AND. Upper(ku->Country) != "DEUTSCHLAND"
        	nForeign++
        Endif*/
		hTurn := GetCustomerTurnover(ku->Kunde)
		If HHasKey(hTurn["years"],nYear) .AND. hTurn["years"][nYear] > 0
			Aadd(aTurn,{ku->Kunde,hTurn["years"][nYear]})
			nTotal += hTurn["years"][nYear]
			/*If ! Empty(ku->Country) .AND. Upper(ku->Country) != "DEUTSCHLAND"
	        	nForeignAk++
    	    Endif*/
		Endif
	Endif
	ku->(dbSkip())
Enddo
aTurn := ASort(aTurn,,,{|x,y| x[2] > y[2] })
@ 01,00 SAY Space(70)
@ 00,00 SAY ""
//If lPrint
	StartPrint(,"Kundenliste_"+DToC(Date()),"PDF")
	SET DEVICE TO PRINTER
	SET PRINTER ON
	oPrinter := getCurrentPrinterObject()
	oPdf := oPrinter:Data

	oPdf:NewPage("A4","P",6)
	oPdf:Image(Trim(Tr_Getini(1))+"\images\eklogo_bw.jpg",1,170,'R',3,33)

	oPdf:SetFont("Helvetica",,16); oPdf:Bold()
	oPdf:AtSay("Kundenbestandsliste "+cYear,1,0,'R')
	oPdf:SetFont("Helvetica",,11); oPdf:Normal()
	oPdf:AtSay("erstellt am "+DToC(Date()),1,80,'R')


//	?p cHead+cYear
//Endif
nX := 1
nTotalPerc := 0
oPdf:NewLine()
oPdf:NewLine()

While nX <= Min(Len(aTurn),nMax)
	ku->(dbSeek(aTurn[nX,1]+"K"))
	oPdf:NewLine()
	oPdf:AtSay(HB_OemtoAnsi( Str(nX,2)+"." ))
	oPdf:AtSay(HB_OemtoAnsi( ku->Kunde),,07,"R" )
	oPdf:AtSay(HB_OemtoAnsi( ku->Name1),,40,"R" )

    nPerc := aTurn[nX,2]/nTotal*100
	nTotalPerc += nPerc
	oPdf:AtSay(HB_OemtoAnsi( Str( nPerc  ,12,2)+"%"),,125 ,"R" )
	If nChoice == 1 .OR. nChoice == 3 .OR. nChoice == 5
	    oPdf:AtSay(HB_OemtoAnsi( Str(aTurn[nX,2],12,2)),,150,"R" )
 	Endif

	nX++
Enddo
oPdf:NewLine();oPdf:AtSay(HB_OemtoAnsi( Str( nTotalPerc  ,12,2)+"%"),,125,"R" )
/*Alert("Anzahl aktive Kunden: "+Trim(Str(Len(aTurn))))
Alert("Anzahl Kunden: "+LTrim(Str(nCount)))
Alert("Anzahl Ausland: "+LTrim(Str(nForeign)))
Alert("Anzahl Ausland aktiv: "+LTrim(Str(nForeignAk)))*/
//Alert("Unter 5K: "+Trim(Str(nSmall)))
If lPrint
	EJECT
	CopyPrint()
	SET DEVICE TO SCREEN
	SET PRINTER OFF
Endif
If ! lPrint
	SInkey(0,128)
Endif