#define CRLF Chr(13)+Chr(10)

Head(HB_AnsiToOem("Artikel nach Häufigkeit des Fremdkaufs"))

NetUse("folgeart","fol",.F.,0)
NetUse("engbes","bes",.F.,0)
NetUse("artikel","art",.F.,0)
NetUse("manufact","manu",.F.,0)
NetUse("engkund","ku",.F.,0)


aManu := GetManufacturerArray()
/*@ 01,00 SAY "Hersteller "
nManu := Achoice(01,12,14,50,aManu[2])
@ 15,12 SAY aManu[1][nManu]*/

aCheck := Array(Len(aManu[1]))
AFill(aCheck,.F.)
getlist := {}
nX := 1
Do While nX <= Len(aCheck)
	SetPos(nX,00 )
	bBlock := &("{|x| If(x!=NIL,aCheck["+LTrim(Str(nX))+"]:=X,aCheck["+LTrim(Str(nX))+"]) }")
	oGet := Get():New(nX,00,bBlock,"aCheck["+LTrim(Str(nX))+"]")           //SetPos(24,00),QQout(GetActive():Row),
	oGet:Control := HBCheckBox():New(nX,00,aManu[2][nX])
	oGet:Control:style := "[X ]"
	oGet:reader := { | a,b,c,d | GuiReader(a,b,c,d ) }
	oGet:Control:Display()

	oGet:Display()
	AAdd(GetList,oGet)
	nX++
Enddo
READ

aList := {}
nX := 1
Do While nX <= Len(aCheck)
	If aCheck[nX]
		Aadd(aList,aManu[1][nX])
	ENDIF
	nX++
Enddo

If LastKey() == 27
	Return
Endif

nI := 0
nTotalGBP := 0
nTotal := 0

hArt := {=>}

fol->(dbSetOrder(2))
bes->(dbSetOrder(2))
art->(dbSetOrder(1))
ku->(dbSetOrder(1))

bes->(dbGoTop())
do while ! bes->(Eof()) //.AND. nI <= 100
	@ 24,00 SAY nI
	art->(dbSeek(bes->matchcode))
	manu->(dbSeek( Str(art->Manufactur,5) ))
	ku->(dbSeek( bes->liefma+"L" ))

	If Ascan(aList,art->Manufactur) != 0 .AND. ku->Nummer != manu->address .AND. bes->Besda >= Date()-365
		If ! HHasKey(hArt,art->Matchcode)
			hArt[art->Matchcode] := {"matchcode"=>art->Matchcode,"qty"=>0,"count"=>0}
		Endif
                hArt[art->Matchcode]["qty"] += bes->BeQty
                hArt[art->Matchcode]["count"] ++

		nI++
	Endif
	bes->(dbSkip())
enddo



StartPrint(,,"PDF")
oPrinter := GetCurrentPrinterObject()
oPdf := oPrinter:Data

oPdf:NewPage("A4","P",6)
oPdf:SetFont("Courier")
oPdf:Bold()
//oPdf:AtSay( aManu[2][nManu]+" Bestellungen nach Lieferant "+Str(nYear,4) )
oPdf:AtSay( "Artikel sortiert nach Häufigkeit des Fremdkaufs in den letzten 12 Monaten "+DToC(Date()) )
oPdf:Normal()

oPdf:NewLine()
oPdf:AtSay( Replicate("-",80 )  )

oPdf:NewLine()
oPdf:AtSAy( "Hersteller:" )
nX := 1
Do While nX <= Len(aCheck)
	If aCheck[nX]
		oPdf:NewLine()
		oPdf:AtSay(aManu[2][nX])
	ENDIF
	nX++
Enddo

oPdf:NewLine()
oPdf:AtSay( Replicate("-",80 )  )
oPdf:NewLine()
oPdf:AtSay(Pad("Matchcode",25)+" "+Pad("Menge",12)+" "+"Häufigkeit")

art->(dbSetOrder( 1 ))
aArt := HGetValues(hArt)
ASort(aArt,,,{|x,y|x["count"]>y["count"]})
Do While nX <= Len(aArt)
	art->(dbSeek( aArt[nX,"matchcode"] ))
	oPdf:NewLine()
	oPdf:AtSay(aArt[nX,"matchcode"]+" "+Pad(Transform(aArt[nX,"qty"],Me(art->me)),12)+" "+Str(aArt[nX,"count"]))
	nX++
Enddo

/*oPdf:NewLine()
oPdf:AtSay( Replicate("-",80) )
oPdf:NewLine()
oPdf:AtSay( "GESAMT            EUR"+Str(nTotal,12,2) )
oPdf:NewLine()
oPdf:AtSay( "GESAMT (berechnet)GBP"+Str(nTotalGBP,12,2) )
*/
bes->(dbCloseArea())
? Chr(12)

CopyPrint()
*/

//inkey(0)
