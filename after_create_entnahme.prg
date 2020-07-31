PARAMETERS nVorg,lVersand
//engrepr("ENGREAB",0,nRenr)
If Tr_MsgBox("Entnahme zum "+If(lVersand,"Versand","Richten")+" freigeben?",,{"Ja","Nein"}) == 1
	UpdateLNEStatus(nVorg,1)
Endif
