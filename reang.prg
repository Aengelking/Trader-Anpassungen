NetUse("angebot1","ang",.T.,0)
ang->(dbSetOrder(0))
/*aStruct := ang->(Dbstruct())
		 Alert("Start")
cNew := Trim(Tr_getini(1))+"\angebot2.dbf"
DbCreate(cnew,aStruct)*/
ang->(dbGoTop())
Do While ! ang->(eof())
@ 01,00 SAY ang->(Recno())
If empty(ang->Info)
	ang->(rec_lock(0))
	ang->Info := ""
	ang->(dbUnLock())
Else
	? ang->(Recno()),ang->Info
Endif
ang->(dbSkip())
Enddo
? "done"
Inkey(0,128)
