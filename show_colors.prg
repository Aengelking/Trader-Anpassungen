
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
		Inkey(0)