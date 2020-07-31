nD := 1
aD := {Trim(Tr_getini(1)),Trim(Tr_getini(1))+"\ntx\"}
CLS
cCorr := ""

Do While nD <= Len(aD)
	cDir := aD[nD]
	aDir := Directory(cDir+"*.*")
	? cDir+", number of files to check "+LTrim(Str(Len(aDir)))+"/"
//	? "Files found:"
	nX := 1
	Do While nX <= Len(aDir)
		nCol := Col()
		@ Row(),Col() SAY LTrim(Str(nX))
		SetPos(Row(),nCol)
		If At(".exe",Lower(aDir[nX,1])) == 0
			cData := MemoRead(cDir+aDir[nX,1])
			If (nP := At("/CreationDate",cData)) > 0
				cCorr += aDir[nX,1]+" "+DToC(SToD(SubStr(cData,nP+17,8)))+" "+SubStr(cData,nP+17+8,2)+":"+SubStr(cData,nP+17+10,2)+":"+SubStr(cData,nP+17+12,2)+Chr(13)+Chr(10)
			Endif
		Endif
		nX++
	Enddo
	nD++
Enddo
? cCorr
? "check complete"
If ! Empty(cCorr)
	SendMail({{"amos.engelking@engelking.de","Amos Engelking"}},"Corruption detected","Corrupted file(s) found: "+Chr(13)+Chr(10)+cCorr)
Endif
SInkey(5)