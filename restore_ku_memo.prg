NetUse("engkund","ku",.F.,0)

ku->(dbGoTop())
Do While ! ku->(Eof())
	ku->(Rec_Lock(0))
	ku->Info := ""
	ku->(dbUnLock())

	ku->(dbSkip())
Enddo

Net_Use(Trim(Tr_Getini(1))+"\restore\engkund","ku_res",.F.,0,"DBFCDX")

ku_res->(dbGoTop())
Do While ! ku_res->(Eof())
	If ! Empty(ku_res->Info) .AND. ku->(dbSeek( ku_res->Kunde+ku_res->Group ))
		ku->(Rec_Lock(0))
		ku->Info := ku_res->Info
		ku->(dbUnLock())
		@ 24,00 SAY ku->Kunde
	Endif
	ku_res->(dbSkip())
Enddo
