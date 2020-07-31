Head("Inventur")
NetUse("artikel","art",.F.,0)
NetUse("werkauf","wer",.F.,0)
art->(dbGoTop())

nTotal := 0

//nType := TR_MsgBox("Preisbasis",,{"Letzte EK","D/S Preis"})
nType := 2 //D/S Preise
dDate := Date() //GetBox(Date(),"Datum","99.99.99")

cList := ""
cUnfert := ""
cVon := Space(25)
cTo := Replicate("X",25)
nVWert := 0
nTWert := 999999999.99

@ 02,00 SAY "Von Matchcode"
oGet := Get():new(02,21,{|xValue| IIf( xValue==NIL, cVon, cVon := xValue ) },"cVon")
oGet:Display()
AAdd(GetList,oGet)

@ 03,00 SAY "Bis Matchcode"
oGet := Get():new(03,21,{|xValue| IIf( xValue==NIL, cTo, cTo := xValue ) },"cTo")
oGet:Display()
AAdd(GetList,oGet)

@ 04,00 SAY "Von Wert"
oGet := Get():new(04,21,{|xValue| IIf( xValue==NIL, nVWert, nVWert := xValue ) },"nVWert")
oGet:Display()
AAdd(GetList,oGet)

@ 05,00 SAY "Bis Wert"
oGet := Get():new(05,21,{|xValue| IIf( xValue==NIL, nTWert, nTWert := xValue ) },"nTWert")
oGet:Display()
AAdd(GetList,oGet)


READ

CLS

art->(dbSeek( cVon, .T. ))
Do While ! art->(Eof())
	If art->Matchcode >= cVon .AND. art->Matchcode <= cTo .AND. art->Bestand > 0
		nBestand := art->Bestand
		nPreis := If(nType==2,art->avpreis,art->letzte_ek/art->pe*Currate(art->money,"E"))
		If art->Bezug >= 5
			nPreis := StCalc(art->artikelnr,If(nType==2,5,1),99,.T.)
		Endif
		nValue := nBestand*nPreis
		If nValue >= nVWert .AND. nValue <= nTWert
			?  art->Matchcode,Pad(Transform(nBestand,Me(art->Me)),12),Str(nValue,12,2)
			nTotal += nValue
    	Endif
	Endif
	art->(dbSkip())
Enddo
? Space(38),Replicate("=",12)
? Space(38),Str(nTotal,12,2)


SInkey(0)