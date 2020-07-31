CLS
Do While (nKey := Inkey(0)) != 27
	? nKey,NToC(KbdStat(),2,8,"0"),HB_BitIsSet(KbdStat(),6)
Enddo