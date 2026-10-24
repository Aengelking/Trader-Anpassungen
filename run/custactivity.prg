nLastMin := 0
nLast3Min := 2000

StartPrint()
SET PRINTER ON
NetUse("engkund","ku",.F.,0)
ku->(dbSetOrder(2)) //group+kunde
ku->(dbSeek("K",.T.))
? Pad("Kunde",8),Pad("Index",6),Pad("Tendenz",9),Pad("Umsatz VJ",12),"Umsatz pro Tag"
Do While ku->group == "K"
	hTurn := GetCustomerTurnover(ku->Kunde)

	If hTurn["last"] > 0 .AND. hTurn["last3"] > nLast3Min .AND. hTurn["last"]/365 > hTurn["current"]/(Date()-BoY(Date()))
		hAct := GetCustomerActivityIndex(ku->Kunde)
		If hAct["avg"] > 0.01 .AND. hAct["weighted"]<hAct["avg"]*0.9
			//(hAct["weighted"]>hAct["avg"]*1.1 .OR. hAct["weighted"]<hAct["avg"]*.9)
			? ku->Kunde,Str(hAct["avg"]*100,6,2),If(hAct["weighted"]>hAct["avg"]*1.5,"++",If(hAct["weighted"]>hAct["avg"]*1.1,"+ ",If(hAct["weighted"]<hAct["avg"]*.9,"- ",If(hAct["weighted"]<hAct["avg"]*.5,"--","0 "))))
			?? "",Str(hAct["weighted"]*100,6,2),hTurn["last"]/365,hTurn["current"]/(Date()-BoY(Date()))
		Endif
	Endif
	ku->(dbSkip())
Enddo
SET PRINTER OFF
EJECT
CopyPrint()
Inkey(0,128)

//Alert("Weighted: "+LTrim(Str(nTotWgAvg))+"; Avg: "+LTrim(Str(nTotAvg)))