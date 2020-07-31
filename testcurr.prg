//Test to see where the corrupted files is comming from!!
CLS

/*If Select("test") != 0
 test->(dbCloseArea())
Endif*/
/*
? "testing creating 'no' file"
? nHandle := fcreate("")
? Ferror()
*/

/*? "testing printing to pdf and opening dbf"
StartPrint("",,"PDF")
oPdf := GetCurrentPrinterObject():Data
oPdf:NewPage()
Netuse("test","test",.F.,0)
oPdf:AtSay("Hello World")
CopyPrint()
*/

/*? "testing printing to pdf, changing file handle and opening a dbf"
StartPrint("",,"PDF")
oPdf := GetCurrentPrinterObject():Data
oPdf:NewPage()
Netuse("test","test",.F.,0)
oPdf:Handle := 0
//Netuse("test","test",.F.,0)
oPdf:AtSay("Hello World")
CopyPrint()
*/

/*? "testing printing to pdf and changing file handle"
StartPrint("",,"PDF")
oPdf := GetCurrentPrinterObject():Data
oPdf:NewPage()
//oPdf:Handle := 3
Netuse("test","test",.F.,0)
Alert(oPdf:Handle)
cLine := "-"
FSeek(oPdf:Handle,0)
HB_FReadLine(oPdf:Handle,@cLine)
Alert(cLine)
oPdf:AtSay("Hello World")
CopyPrint()
*/


StartPrint(2,,"PDF")
oPdf := GetCurrentPrinterObject():Data
oPdf:NewPage()
//test->(dbSelectArea())
/*nC := 0
Do While nC < 5024
	Netuse("test","test"+Ltrim(Str(nC)),.F.,0)
	NC++
Enddo */
//oPdf:Handle := 0
//Netuse("test","test",.F.,0)
oPdf:AtSay("Hello World")
CopyPrint()



/*
//THIS HANGS!!
? "attempting to find file handle of DBF file"
Netuse("test","test",.F.,0)
nX := 1
@ 02,00 SAY ""
Do While nX <= 100
	nRow := Row()
	@ 02,00 SAY nX
	SetPos(nRow,0)
	cLine := "-"
	FSeek(nX,0)
	HB_FReadLine(nX,@cLine)
	?? cLine
	nX++
Endif
? "done"
Inkey(0)
*/

/*

*/
/*? "Looking for corrupted PDF files"
cStart := "%PDF-1.3"+Chr(13)+Chr(10)+"2 0 obj"+Chr(13)+Chr(10)+"<<"
	cDir := Trim(Tr_getini(1))+"\pdf\"
	aDir := Directory(cDir+"*.pdf")
	? cDir+", number of files to check "+LTrim(Str(Len(aDir)))+"/"
	nRow := Row()
	nCol := Col()
	? "Files found:"
	nX := 1
	Do While nX <= Len(aDir) .AND. inkey() != 27
	nRow2 := Row()
		@ nRow,nCol SAY LTrim(Str(nX))
		SetPos(nRow2,00)
		If Year(aDir[nX,3]) == 2010 .AND. Month(aDir[nX,3]) == 9
			cData := MemoRead(cDir+aDir[nX,1])
			If At(cStart,cData) == 1 .AND. At("/CreationDate",cData) == 0
				? Trim(aDir[nX,1]),DToC(aDir[nX,3])
			Endif
		Endif
		nX++
	Enddo
*/

cData := MemoRead(Trim(Tr_getini(1))+"\test.dbf")
If (nP := At("/CreationDate",cData)) > 0
	? "FILE CORRUPTED!!!"
Endif


Inkey(0,128)