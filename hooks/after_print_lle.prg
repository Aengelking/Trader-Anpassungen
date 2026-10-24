PARAMETERS cKunde,dVon,dBis,nCountPreaf,nCountNoPreaf

If nCountPreaf > 0
	dDate := NIL
	lLoop := .T.
	lQuit := .F.
	Do While lLoop
	   dDate := GetBox(dBis-60,"Wiedervorlage")
	   If LastKey() == 27 .AND. Tr_MsgBox("Abbrechen?",,{"Nein","Ja"}) == 2
	   	lLoop := .F.
	   	lQuit := .T.
	   Elseif dDate >= Date()+1
	   	lLoop := .F.
	   Endif
	Enddo
	If ! lQuit
		AddWiedervorlage(dDate,"Wiedervorlage LLE "+cKunde,"Gedruckt "+DToC(Date())+" "+Time(),"LLE:"+cKunde)
	Endif
Endif
