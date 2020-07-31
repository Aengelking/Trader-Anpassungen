cFile := GetBox(Space(20),"File")
aTest := {}
cBase := Trim(Tr_getini(19))+"\"+Trim(cFile)
If ! File(cBase+".arr")
	Alert("File "+cBase+".arr not found")
Else
	If File(cBase+".prg")
		Alert("PRG "+cBAse+".prg found!")
	Else
		RestArray(cBase+".arr",@aTest)
		nX := 1
		nH := FCreate(cBase+".prg")
		while nx < Len(aTest)
			? aTest[nX]
			Fwrite(nH,aTest[nX]+Chr(13))
			nX++
		enddo
		FClose(nH)
		/*while Inkey(0) != 27
		enddo*/
		Inkey(0)
	Endif
endif