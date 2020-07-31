aTest := Array(16)

nX := 1
Do While nX <= Len(aTest)
	aTest[nX] := Str(nX,2)
	nX++
Enddo
ASort(aTest,12,13,{|x,y| x > y})
AMenu(aTest)