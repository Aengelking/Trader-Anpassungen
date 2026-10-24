NetUse("engkund","ku")

NetUse("englsre","re")
re->(dbSetOrder(1))
re->(dbSeek( ku->Kunde ))

NetUse("skontoa","sk")

//LX_Start()
nTotal := 0
oPdf := GetCurrentPrinterObject():Data
IF ValTyp(oPdf) != "O"
	Alert("Dieser Drucker kann für diese Funktion nicht verwendet werden")
	RETURN NIl
ENDIF

oPdf:Bold()
oPdf:AtSay("Rechnung",,0,'R')
oPdf:RJust("Betrag",,50,'R')
oPdf:RJUst("Zahlung",,75,'R')
oPdf:AtSay("Rech. vom",,80,'R')
oPdf:AtSay("Eingang",,110,'R')
oPdf:AtSay("Skonto bis",,140,'R')
oPdf:RJust("Abzug",,180,'R')
oPdf:Normal()


DO WHILE re->Status < 3 .AND. re->Kunde == ku->Kunde
//	? re->Rechnr
	IF re->RePosNr == 0 .AND. re->Packed .AND. re->Code != 3 .AND. re->poswt != 0 .AND. re->AoQty != 0 //nur zum teil bezahlt
/*		LX_GetOffenerPosten(ku->Nummer,re->Rechnr,.T.)
		hZahl := NIL
		FOR EACH hZahl IN hOp:aZahlungen
			nRow++
			? DToC(hZahl:dDatum)+" "+hZahl:Text
			? Str(hZahl:nBetrag,12,2)
		NEXT*/
		sk->(dbGoto( re->Skonto+1 ))
		oPdf:NewLine()
		oPdf:AtSay(LTrim(Str(re->Rechnr,6)),,0,'R')
		oPdf:RJust(Str(re->PosWt,8,2),,50,'R')
		oPdf:RJust(Str(re->AoQty,8,2),,75,'R')
		oPdf:AtSay(DToC(re->Rechdat),,80,'R')
		oPdf:AtSay(DToC(re->PayDate),,110,'R')
		nZiel := 0
		IF ! sk->(HasSpecialPay( re->Skonto ))
   		nZiel := sk->Ziel1
   	ELSE
   	   cText := sk->(Skont(,,sk->Ziel1,sk->Ziel2,sk->Ziel3,sk->Rate1,sk->Rate2,sk->Rate3,"D",.F.))
   	   cText := SubStr(cText,At(": ",cText)+2)
//   	   Alert(cText)
//   	   Alert(Left(cText,At(" ",cText)))
         nZiel := Val(Left(cText,At(" ",cText)))
   	ENDIF
   	IF nZiel > 0
   	  oPdf:AtSay(DToC(re->Rechdat+nZiel),,140,'R')
   	ENDIF

		oPdf:RJust(Str(re->PosWt-re->AoQty,6,2),,180,'R')

		nTotal += re->PosWt-re->AoQty
	ENDIF
	re->(dbSkip())
ENDDO
//oPdf:NewLine()
oPdf:Bold()
//oPdf:RJust(oPdf:Underline(Space(8)),,180,'R')


oPdf:RJust(Replicate("_",6),,180,'R')
oPdf:NewLine()
oPdf:RJust(Str(nTotal,6,2),,180,'R')
oPdf:Normal()
