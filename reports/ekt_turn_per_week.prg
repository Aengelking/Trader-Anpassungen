#define CRLF Chr(13)+Chr(10)

Head(HB_AnsiToOem("Durschnittlicher Monatsumsatz Elektron"))


dStart := Date()-365

NetUse("engbes","bes",.F.,0)
bes->(dbSetOrder(2))
bes->(dbSeek("BULGIN"))

nTotal := 0

do while ! bes->(Eof()) .AND. Trim(bes->Liefma) == "BULGIN"
	If bes->besda >= dStart //.AND. bes->besda <= dEnd
		nQty := If(bes->bestat < 3,bes->beqty,bes->gelqty)

		nPreis := bes->ekpr/bes->pe*Currate(bes->money,"E")
		nTotal += nQty*nPreis
	Endif
	bes->(dbSkip())

enddo

? "Gesamt : ",Ltrim(Str(nTotal,12,2))
? "Pro Tag: ",LTrim(Str(nTotal/365,12,2))

Inkey(0,128)

//inkey(0)
