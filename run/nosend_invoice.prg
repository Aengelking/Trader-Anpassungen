PROC RUN_NOSEND_INVOICE
LOCAL nNr := 0

DO WHILE .T.
   Head("Rechnung als intern markieren")

   @ 01,00 SAY "Rechnungsnummer" GET nNr PICTURE "999999"
   READ

   IF LastKey() == 27
      RETURN
   ENDIF

   IF ! reh->(dbSeek( Str(nNr,6) ))
      @ 01,23 SAY "Rechnung nicht gefunden"
      LOOP
   ELSEIF post->(dbSeek( "RE"+Str(nNr,6) ))
      @ 01,23 SAY "Rechnung bereits verschickt"
      LOOP
   ENDIF
   @ 01,23 CLEAR

   IF Tr_MsgBox("Rechnung markieren?",,{"Nein","Ja"}) == 2

      post->(Add_Rec(0))
      post->Typ := "RE"
      post->Via := "INT"
      post->Nummer := nNr
      post->DateTime := TtoS(DateTime())
      post->(dbUnLock())
   ENDIF
ENDDO                  