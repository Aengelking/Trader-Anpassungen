NetUse("lagerne","lne",.F.,0)
NetUse("werkauf","wer",.F.,0)

wer->(dbSetOrder( 8 )) //str(lagnum,6)

lne->(dbGoTop())

CLS

Do While ! lne->(EOF())
	@ 01,00 SAY lne->Nummer
	If lne->Werkstatt
        	If wer->(dbSeek( Str(lne->Nummer,6) ))
        		lne->(Rec_Lock(0))
        		lne->RefTyp := "WA"
        		lne->RefBeleg := wer->AufNo
        		lne->(dbUnlock())
        	Endif
	Endif
	lne->(dbSkip())
Enddo