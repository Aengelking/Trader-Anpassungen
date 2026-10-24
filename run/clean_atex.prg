NetUse("engauf","auf",.F.,0)
NetUse("atex","at",.F.,0)
at->(dbGoTop())
Do While ! at->(Eof())
	If ! auf->(dbSeek(Str(at->AbNr,6),.T.))
		? "Deleting text for non existent order "+Ltrim(Str(at->Abnr))
		at->(Rec_Lock())
		at->(dbDelete())
		at->(dbUnLock())
	Endif
	at->(dbSkip())
Enddo