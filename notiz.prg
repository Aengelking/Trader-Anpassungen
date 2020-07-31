LOCAL cKunde := Space(8)
Head(t("Gesprächsnotiz"))

NetUse("engkund","ku")

@ 01,00 SAY "Kunde" GET cKunde PICTURE "@K !!!!!!!!" VALID Findad( cKunde, "K", 01, 40 )
READ
IF LastKey() == 27
   RETURN
ENDIF
ShowTalk()