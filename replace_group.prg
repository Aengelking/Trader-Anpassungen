NetUse("artikel","art",.F.,0)
art->(dbSetOrder(1))
art->(dbSeek("CS0",.T.))


Do While At("CS",art->matchcode) == 1
	? art->MAtchcode
	art->(Rec_Lock(0))
	art->Gruppe := "DISC"
	art->(dbUnLock())
	art->(dbSkip())
Enddo
SInkey(0)