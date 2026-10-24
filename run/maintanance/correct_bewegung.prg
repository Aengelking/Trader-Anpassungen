NetUse("engbew","bew",.F.,0)
NetUse("engkund","ku",.F.,0)
ku->(dbSetOrder( 2 ))

ku->(dbSeek("K",.F.))

Do While ! ku->(Eof()) .AND. ku->Group == "K"  .AND. ku->Kunde < "C"
	bew->(dbSeek( Str(ku->Nummer,6) ))
	Do While bew->Kundennr == ku->Nummer
		If bew->Liefma != ku->Kunde
			? ku->Kunde,bew->Liefma,ku->Nummer,bew->Kundennr
			bew->(REc_Lock(0))
			bew->(dbDelete())
			bew->(dbUnlock())
		Endif
		bew->(dbSkip())
	Enddo
	ku->(dbSkip())
Enddo