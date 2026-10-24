Head("Varianten erstellen")

NetUse("Artikel","art",.F.,0)
getlist := {}
cOld := Space(25)
cNew := Space(25)
lRun := .T.
cBasis := GetBox(Pad("NZ/",25),"Basis")
If Empty(cBasis) .OR. LastKey() == 27
	Return
Endif
cBasis := Trim(cBasis)
nLength := Len(cBasis)

art->(dbSetOrder(1))
If ! art->(dbSeek( cBasis ))
	Tr_MsgBox("Basis nicht gefunden!")
	Return
Endif

cArtikel := art->Artikel

art->(dbSkip())

Do While At(cBasis,art->Matchcode) == 1 .AND. lRun
	//@ 02,00 SAY "Matchcode" GET cOld //VALID ValidVar(cOld,02,00,0,Space(25),0)

/*	cOld := GetBox(cOld,"Matchcode")
	If LastKey() == 27
		lRun := .F.
	Endif
	If lRun
		art->(dbSetOrder(1))
		If art->(dbSeek(cOld)) .AND. At(cBasis,cOld) == 1 .AND. Trim(cOld) != cBasis*/
			If art->Variant == "V" .and. art->Length > 0
			//art->Bezug == 8 .AND. art->Length > 0
				//@ 03,00 SAY
				? art->Matchcode+" ist bereits Variantenartikel!"
			Else
				//@ 03,00 SAY
				? art->Matchcode //Space(80)
				cOld := art->Matchcode
				nRow := Row()
				nCol := Col()
				nChoice := Tr_MsgBox(HB_AnsiToOem("In Variant ändern?"),art->Matchcode,{"Nein","Ja","Abbrechen"})
				SetPos(nRow,nCol)
				If nChoice == 2
					art->(dbSetOrder(1))
					art->(dbSeek(cOld))
					art->(Rec_Lock(0))
					//art->Bezug := 8
					art->Variant := "V"
					art->Length := nLength
					art->(dbUnLock(0))
				Elseif nChoice == 3
					lRun := .F.
				Endif
			Endif
		/*Else
			@ 03,00 SAY art->Matchcode+" nicht gefunden!"
		Endif*/
//	Endif
	art->(dbSkip())
Enddo
//@ 04,00 SAY cOld
//Inkey(0)