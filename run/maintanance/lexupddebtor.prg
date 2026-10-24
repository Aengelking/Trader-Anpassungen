NetUse("engkund","ku")
ku->(dbSetOrder( 2 ))
ku->(dbSeek( "K" ))
LX_Start()
DO WHILE ku->Group == "K" .AND. ! ku->(EOF())
	IF LX_HasAccountInCat(ku->Nummer,128) > 0
		? ku->Kunde,ku->Name1
		LX_CreateDebtor()
	ENDIF
	ku->(dbSkip())
ENDDO
Inkey(0,128)