dLastDate := CToD("01.01.80")
nTime := 1

/*NetUse("engabg","abg",.F.,0)
abg->(dbSetOrder( 3 ))
abg->(dbGoTop())
*/

 //Alert("Task completed on 04.12.09")
/*Do While ! abg->(Eof())
	If abg->TransDate != dLastDate
		nTime := 1
	Else
		nTime ++
	Endif

	abg->(Rec_Lock(0))
	abg->Transtime := TString(nTime)
	abg->(dbUnLock())
//	@ 24,00 SAY DToC(abg->Transdate)+TString(nTime)
	abg->(dbSkip())
Enddo */

NetUse("engbew","bew",.F.,0)
bew->(dbGoTop())

Do While ! bew->(Eof())
	If bew->Transdate != dLastDate
		nTime := 1
	Else
		nTime ++
	Endif
	bew->(Rec_Lock(0))
	bew->Transtime := TString(nTime)
	bew->(dbUnlock())
	
	bew->(dbSkip())
Enddo

