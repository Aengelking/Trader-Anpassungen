#define CRLF Chr(13)+Chr(10)

Head(HB_AnsiToOem("Indirekten Umsätze berechnen"))

aManu := GetManufacturerArray()
@ 01,00 SAY "Hersteller "
nManu := Achoice(01,12,14,50,aManu[2])
@ 01,12 SAY aManu[2][1]

nYear := GetBox(Year(Date()),"Jahr","9999")

If LastKey() == 27
	Return
Endif

lPrintPos := Tr_MsgBox("Bestellpositionen ausgeben?",,{"Nein","Ja"}) == 2

NetUse("folgeart","fol",.F.,0)
fol->(dbSetOrder(2))
NetUse("engbes","bes",.F.,0)
bes->(dbSetOrder(2))
NetUse("artikel","art",.F.,0)
art->(dbSetOrder(1))
NetUse("manufact","manu",.F.,0)
NetUse("engkund","ku",.F.,0)
ku->(dbSetOrder(8))
cManu := Space(8)
If manu->address != 0 .AND. ! ku->(dbSeek( Str(manu->address,6) ))
	Alert("Supplier not found")
Else
	cManu := ku->Kunde
Endif

/*nOrd := 1
do while dbSetOrder(nOrd) != NIL .AND. nOrd == IndexOrd()
	? '  '+Str(nOrd,1)+'. '+OrdKey(nOrd)
	nOrd++
enddo*/

StartPrint(,,"PDF")
oPrinter := GetCurrentPrinterObject()
oPdf := oPrinter:Data

oPdf:NewPage("A4","P",6)
oPdf:SetFont("Courier")
oPdf:Bold()
oPdf:AtSay( aManu[2][nManu]+" Bestellungen nach Lieferant "+Str(nYear,4) )
oPdf:Normal()

cSubHead :=  "Besnr  Datum    Matchcode                  Menge        EK bestellt  EK kalkuliert"
            //123456 00.00.00 12345678901234567890123455 123456789012 123456789012 123456789012


nI := 0
nTotalGBP := 0
nTotal := 0


bes->(dbGoTop())
do while ! bes->(Eof()) //nI <= len(aSup)

	//? aSup[ni],pr(4)
	cSup := bes->Liefma

	ku->(dbSetOrder(1))
    ku->(dbSeek( bes->liefma+"L" ))
    If ku->Nummer != manu->address
		//? "Besnr  Datum    Matchcode                  Menge  EK-Preis EUR      EK GBP"
		//bes->(dbSeek(aSup[nI],.T.))
		nCount := 0
		nBulCount := 0
		nValue := 0
		nReal := 0
		aList := {}
	    do while ( bes->liefma == cSup  ) //aSup[ni] )
	    	art->(dbSeek(bes->matchcode))
	    	//if ( At(cGrup,art->gruppe) == 1 .AND. Year(bes->besda) == nYear )
	        if art->Manufactur == aManu[1][nManu] .AND. Year(bes->besda) == nYear .AND. ! fol->(dbSeek( Str(art->artikelnr,6) ))
	    		nPreis := bes->ekpr/bes->pe*Currate(bes->money,"E",bes->Besda)
				nRealPreis := 0
				nPe := 0
				GetBuyPrice(cManu,art->Artikelnr,bes->beqty,@nRealPreis,@nPe,.T.)
				If nRealPreis == 0 .AND. ! Empty(art->vkpreis2) //Preis basis e.g. Bulgin
					nRealPreis := art->vkpreis2
					nPe := art->vkpe
				Endif
				If nPe == 0
					nPe := 1
				Endif
				nQty := If(bes->bestat < 3,bes->beqty,bes->gelqty)
				Aadd(aList,Str(bes->besnr,6)+" "+DToC(bes->besda)+" "+bes->matchcode+" "+Transform(nQty,Me(art->Me))+" "+Str(nPreis,12,2)+" "+Str(nRealPreis/nPe,12,2))
				nValue += nQty*nPreis
				nReal += nQty*nRealPreis/nPe
				nBulCount++
			endif
			nCount++
	    	bes->(dbSkip())
		enddo
		nTotalGBP += nReal
		nTotal += nValue
		If nBulCount > 0
	    	oPdf:NewLine()
	    	oPdf:AtSay( Replicate("-",80 )  )
	    	oPdf:Bold()
	    	oPdf:NewLine()
	    	oPdf:AtSay( "Lieferant: 		    "+cSup )
	    	oPdf:Normal()
	    	oPdf:NewLine()
			oPdf:AtSay( "Anzahl:              "+Str(nBulCount,12) )
	    	oPdf:NewLine()
			oPdf:AtSay( "Bestellwert:      EUR"+Str(nValue,12,2) )
	    	oPdf:NewLine()
			oPdf:AtSay("Berechneter Wert: GBP"+Str(nReal,12,2) )
			nX := 1
			If lPrintPos
				oPdf:NewLine()
				oPdf:AtSay(cSubHead)

				Do While nX <= Len(aList)
					oPdf:NewLine()
					oPdf:AtSay(aList[nX])
					nX++
				Enddo
			Endif
	//		? cSubHead
	//		? cList
		Endif
	Else
		bes->(dbSkip())
	Endif
    nI++
enddo

oPdf:NewLine()
oPdf:AtSay( Replicate("-",80) )
oPdf:NewLine()
oPdf:AtSay( "GESAMT            EUR"+Str(nTotal,12,2) )
oPdf:NewLine()
oPdf:AtSay( "GESAMT (berechnet)GBP"+Str(nTotalGBP,12,2) )

bes->(dbCloseArea())
? Chr(12)

CopyPrint()


//inkey(0)
