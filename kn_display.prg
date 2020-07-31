NetUse("kn","kn",.F.,0)

Do While LastKey() != 27
	cKn := GetBox(Space(10),"Warennummer","9999 99 99")
	If LastKey() != 27
		If ! kn->(dbSeek( Pad(StrTran(cKn," ",""),10) ))
			Alert("Warennummer nicht gefunden")
		Else
			Alert(kn->Self_Expla)
		Endif
	Endif
Enddo