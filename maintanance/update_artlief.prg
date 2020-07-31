NetUse("artikel","art",.F.,0)
NetUSe("artlief","ali",.F.,0)


art->(dbSetORder(2)) //artikelnr


nX := 1
Do While nX <= 2
	ali->(dbGoTop())
	Do While ! ali->(Eof())
		art->(dbSeek( Str(ali->artikelnr,6) ))
		ali->(Rec_Lock())
		ali->Matchcode := art->Matchcode
		ali->(dbUnLock())
		ali->(dbSkip())
	Enddo
	nX++
	ali->(dbCloseArea())
	NetUse("artkund","ali",.F.,0)
	
Enddo