NetUse("engkund","ku",.F.,0)
ku->(dbSetOrder( 1 ))
ku->(dbSeek( Pad("TEST",8)+"K" ))

oRec := ku->(Record():New())
//oRec:cAlias := "ku"
//oRec:nRecno := ku->(Recno())
Alert(oRec:Name1)
oRec:Name1 := "Test Company"
Alert(oRec:Name1)
oRec:Save()