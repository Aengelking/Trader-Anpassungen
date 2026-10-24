#include 'inkey.ch'
PROC RUN_TEST_SIZE
   LOCAL nKey := 0
   LOCAL nHeight := MaxRow()+1
   LOCAL nWidth := MaxCol()+1
   LOCAL nX,nY
   LOCAL cScreen := SaveScreen()
   DO WHILE nKey != K_ESC
      CLS
      FOR nX := 0 TO 2
         FOR nY := 4 TO nWidth-1
            @ nX,nY SAY SubStr(Str(nY,3),nX+1,1)
         NEXT
      NEXT
      FOR nX := 4 TO nHeight-1
         @ nX,00 SAY Str(nX,3)
         FOR nY := 4 TO nWidth-1
            @ nX,nY SAY Chr(HB_Random(64,90))
         NEXT
      NEXT
      @ nHeight/2-1,nWidth/2-10 SAY Space(25)
      @ nHeight/2,nWidth/2-10 SAY Space(25)
      @ nHeight/2,nWidth/2-6 SAY Str(nHeight,3)+"x"+Str(nWidth,3)
      @ nHeight/2+1,nWidth/2-10 SAY Space(25)
      //@ nHeight/2+1,nWidth/2-6 SAY Str(MaxRow()+1,3)+"x"+Str(MaxCol()+1,3)
      @ nHeight/2+2,nWidth/2-10 SAY Space(25)

      nKey := Inkey(0,128)
      IF nKey == K_UP
         nHeight++
      ELSEIF nKey == K_DOWN   
         nHeight--
      ELSEIF nKey == K_LEFT
         nWidth--
      ELSEIF nKey == K_RIGHT
         nWidth++
      ENDIF
      
      @ nHeight/2+1,nWidth/2-6 SAY IF( SetMode(nHeight,nWidth),"SUCCESS","FAILED ")
      
   ENDDO