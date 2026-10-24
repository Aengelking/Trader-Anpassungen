NetUse("angebot","ang",.F.,0)
ang->(dbSetOrder(0))
ang->(dbGoTop())
NetUse("angebo1","an2",.F.,0)
@ 23,00 SAY ang->(Recno())
Do While ! ang->(Eof())
	@ 24,00 SAY ang->(Recno())
	ang->(dbSkip())
Enddo
