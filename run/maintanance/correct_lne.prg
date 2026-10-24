NetUSe("lagerne","lne",.F.,0)
lne->(dbSetOrder(8))
lne->(dbSeek( "1" )) //packed
Do While ! lne->(Eof()) .AND. lne->Packed
	@ 24,00 SAY lne->Nummer
	nRec := lne->(Recno())
	nNr := lne->Nummer
	lne->(dbSetOrder( 1 ))
	Do While ! lne->(Eof()) .AND. lne->Nummer == nNr
		lne->(Rec_Lock())
		lne->packed := .T.
		lne->(dbUnLock())
		lne->(dbSkip())
	Enddo
	lne->(dbSetORder( 8 ))
	lne->(dbGoto( nRec ))
	lne->(dbSkip())
Enddo
