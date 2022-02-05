PROC Run_Test_colors
   LOCAL nRow, nCol, nColor, cColor

      nRow := 0
      nCol := 0

      FOR nColor := 0 TO 255
         cColor := NtoColor( nColor, .T. )

         @ nRow, nCol SAY PadC( cColor, 8 ) COLOR (cColor)

         IF ++nRow > MaxRow()
            nRow := 0
            nCol += 8
         ENDIF
      NEXT
/*
   LOCAL nCol
   FOR nCol := 1 TO 256
      SetColor("N/"+NToColor(nCol))
      @ (nCol-1)*3,00 CLEAR TO (nCol-1)*3+2,MaxCol()
      @ (nCol-1)*3,00 SAY nCol
   NEXT*/
   Sinkey(0)
RETURN