FOR nR := 00 TO MaxRow()
   FOR nC := 00 TO MaxCol()
      @ nR,nC SAY Chr(nR+nC)
   NEXT
NEXT
Scroll(10,10,20,20,5)
Inkey(0,128)