Head("Kursrechner")
nPr1 := 0
nPr2 := 0
cW1 := " "
cW2 := " "

Do While ! lastKey() == 27
  GETLIST := {}
  @ 02,00 GET nPr1 PICTURE "999,999,999.99"
  @ 02,15 GET cW1 VALID Cur(cW1)
  @ 02,37 SAY "-->" GET cW2 VALID Cur(cW2)
  READ
  DevPos(02,63)
  DevOut(nPr1*Currate(cW1,"V")/Currate(cW2,"V"))
Enddo

