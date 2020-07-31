CLS

NetUse("artikel","art")

? "Skipping in artikel"

DO WHILE Inkey() != 27   
   @ 00,00 SAY art->Matchcode
   art->(dbSkip())
   IF art->(EOF())
      art->(dbgoTop())
   ENDIF
ENDDO

//? "Looping"

/*DO WHILE Inkey() != 27
   //HB_IdleState()
ENDDO*/