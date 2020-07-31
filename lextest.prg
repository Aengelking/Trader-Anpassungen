LX_Start()
//hOP := LX_GetOffenerPosten(18949,28938)
hOP := LX_GetOffenerPosten(20585,28936)

? "Beleg: ",hOP:cBelegNr
? "Betrag:",hOP:nBetrag
? "Rest:  ",hOP:nRest
? "Datum: ",hOP:dLetzteZahlung

Inkey(0,128)