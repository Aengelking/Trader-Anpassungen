FUNC TEST
   LOCAL nKey := 0
   LOCAL nCount := 0
   CLS
   DO WHILE nKey != 27
      
      NetUse("artikel","art")
      DO WHILE ! art->(EOF()) .AND. nKey != 27
         nCount++
         @ 24,00 SAY nCount
         art->(dbSkip())
         nKey := Inkey(,128)
      ENDDO

      art->(dbCloseArea())
	ENDDO