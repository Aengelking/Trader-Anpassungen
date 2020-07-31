
NetUse("engkund","ku",.F.,0)
ku->(dbSetOrder(2))
ku->(dbSeek("K",.T.))

Do While ku->Group == "K" .AND. ! ku->(EOF())
  If ! Empty(ku->vatnr) .AND. Upper(Left(ku->vatnr,2)) != "DE"
     nResult := CheckVatID(ku->vatnr)
    If nResult > 0
  		? ku->Kunde,HB_AnsiToOem("ungültig"),HB_AnsiToOem(getVATIDErrorName())
  	Endif
  Endif
	ku->(dbSkip())
Enddo
Inkey(0)