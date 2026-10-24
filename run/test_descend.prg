NetUse("engabg","abg",.F.,0)
abg->(dbSeek(Descend("TEST3"),.T.))
cLast := ""
While abg->matchcode == Pad("TEST3",25)
	cThis := Descend(abg->matchcode+Str(Recno()))
	? Recno(),cThis
	if cThis > cLast
		?? " bigger"
	endif
	cLast := cThis
	abg->(dbSkip())
Enddo
Inkey(0)