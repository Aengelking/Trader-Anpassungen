NetUse("engbew","bew",.F.,0)
bew->(dbGoTop())
aDelNotes := {}
Do While ! bew->(Eof())
	If Trim(bew->Buart) == "WE" 
		If Ascan(aDelNotes,bew->Liefma+bew->Beleg) != 0
			? "Delete "+bew->Liefma+bew->Beleg
			bew->(Rec_Lock())
			bew->(dbDelete())
			bew->(dbUnlock())
		Else
			Aadd(aDelNotes,bew->Liefma+bew->Beleg)
		Endif
	Endif
	bew->(dbSkip())
Enddo