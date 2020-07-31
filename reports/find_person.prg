LOCAL getlist := {}
LOCAL cName := Space(50)

Head("Adresse zu Person finden")

NetUse("contacts","conts",.F.,0)
NetUse("engkund","ku",.F.,0)

@ 01,00 SAY "Name" GET cName
READ

If LastKey() == 27 .OR. Empty(cName)
	Return
Endif

cName := Trim(Upper(cName))

ku->(dbSetOrder( 8 ))

conts->(dbGoTop())
dbSelectArea("conts")
LOCATE FOR At(cName,Upper(conts->Name)) != 0

SetPos(02,00)

Do While conts->(Found())

	? conts->Address
	ku->(dbSeek( Str(conts->Address,6) ))
	?? "",ku->Kunde,ku->Name1,Pad(conts->Name,30)
	dbSelectArea("conts")
	CONTINUE
Enddo

? "Suche beendet."
SInkey(0)
