NetUse("artikel","art",.F.,0)
NetUse("option","op",.F.,0)

Head(t("Artikel auf Variantenartikel ändern"))

cArt := Space(25)
cGType := Space(25)
lLoop := .T.

Do While lLoop
	cGType := GetBox(cGType,t("Gerätetyp"))

	If LastKey() == 27
		lLoop := .F.
	ElseIf ! art->(dbSeek( cGType, .F. )) .OR. art->Matchcode != cGType
	    Alert("Artikel nicht gefunden!")
	Elseif ! op->(dbSeek( cGType, .F. ))
	    Alert("Kein Variantenartikel!")
	Else
		lLoop := .F.
	Endif
Enddo
If LastKey() == 27
	Return
Endif

cGType := Trim(cGType)

lLoop := .T.

Do While lLoop
	cArt := GetBox(cArt,"Matchcode")

	art->(dbSetOrder(1))
	If LastKey() == 27
		lLoop := .F.
	ElseIf cGType != Left(cArt,Len(cGType))
		Alert(t("Matchcode beginnt nicht mit dem Gerätetyp "+cGType))
	Elseif ! art->(dbSeek( cArt )) .OR. art->Matchcode != cArt
		Alert("Artikel nicht gefunden!")
	Else
		art->(Rec_Lock())
		//art->Bezug := 8
		art->Variant := "V"
		art->Length := Len(cGType)
		art->Table := op->Table
		art->(dbUnLock())
		@ 13,30 SAY t("Artikel erfolgreich geändert!") COLOR c_five
		Inkey(5)
		@ 13,30 CLEAR
	Endif
Enddo

