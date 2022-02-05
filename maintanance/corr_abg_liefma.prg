/*
Dieses Programm dient dazu den Matchcode von Lieferanten im Bewegungskonto zu korrigieren.
Durch einen Bug wurde beim Žndern eines Kundenmatchcodes alle Eintr„ge im Bewegungsstamm auch bei den Liefderanten ge„ndert.
03.08.2021
*/
PROC RUN_CORR_ABG
   LOCAL cWrong := Space(8)
   LOCAL cCorrect := Space(8)
   LOCAL getlist := {}
LOCAL nX
LOCAL aList := {}
   Head("Lieferanten Matchcode im Bewegungskonto korrigieren")
   NetUse("engabg","abg")

   @ 01,00 SAY "Falscher Matchcode " GET cWrong PICTURE "@!" VALID ! Empty(cWrong)
   @ 02,00 SAY "Richtiger Matchcode" GET cCorrect PICTURE "@!" VALID ! Empty(cCorrect)
   READ

   IF LastKey() == 27
      RETURN
   ENDIF

   IF ! Tr_MsgBox("Žnderung durchfhren",,{"Nein","Ja"}) == 2
      RETURN
   ENDIF

   abg->(dbSetOrder( 4 ))
   DO WHILE abg->(dbSeek( cWrong+"L" ))
      ? abg->Liefma,abg->Buart,abg->Beleg
      abg->(Rec_Lock(0))
      abg->Liefma := cCorrect
      abg->(dbUnLock())
   ENDDO

   ? "fertig"
   Sinkey(0)

RETURN