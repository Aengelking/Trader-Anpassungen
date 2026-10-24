
LOCAL lNurDeutsch := .T.

nCount := 0
	NetUse("contacts","conts",.F.,0)
	NetUse("engkund","ku",.F.,0)
	NetUse("anrede","an",.F.,0)
	ku->(dbsetOrder(8)) //nummer

	Head("Export Email Addresses")
	@ 01,00 SAY "Nur deutsche Kunden" GET lNurDeutsch PICTURE "Y"
	READ

	IF LastKey() == 27
	  RETURN
	ENDIF

	SET PRINTER TO (Trim(Tr_Getini(1))+"\export\email_kunden.csv")
	SET PRINTER ON

   conts->(dbSetFilter({|| ! Empty(conts->Email) .AND. conts->Active .AND. conts->Anrede > 0 .AND. conts->Anrede <= IF(lNurDeutsch,2,3)},'! Empty(Email) .AND. Active .AND. Anrede > 0 .AND. Anrede <= '+IF(lNurDeutsch,'2','3')))
   conts->(dbGoTop())

	Do While ! conts->(Eof())  //.AND. nCount < 20
		cIndKey := Str(conts->Address,6)+Str(conts->Number,4)
		ku->(dbSeek(Str(conts->Address,6)))

		IF ku->Group == "K" .AND. ! Trim(ku->Kunde) $ "TEST SELF" //nur deutsche kunden
			nCount++

			If nCount > 1
				? ""
			Endif

			?? Trim(HB_OemToAnsi(StrTran(StrTran(conts->Name,Chr(13),""),Chr(10),"")))+Chr(59)
			an->(dbGoto(conts->Anrede))
			?? Trim(an->Anrede)+Chr(59)
//			?? GetContactAnrede(conts->Number)+Chr(59)
			?? Trim(HB_OemToAnsi(StrTran(StrTran(ku->Name1,Chr(13),""),Chr(10),"")))+Chr(59)
			?? HB_OemToAnsi(StrTran(StrTran(conts->Email,Chr(13),""),Chr(10),""))
			//?? HB_OemToAnsi("bullshit"+LTrim(Str(nCount))+"@engelking.de")
		ENDIF

	  conts->(dbSkip())

	Enddo
	
	conts->(dbClearFilter())

	SET PRINTER TO
	SET PRINTER OFF
