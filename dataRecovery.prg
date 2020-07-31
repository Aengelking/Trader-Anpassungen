/**
  * This programm recovers missing data from a backup file placed in <cBakDir>
  * The recovery file(s) needs to be placed before starting this programm.
  **/

cBakDir := Trim(Tr_getini(1))+"\recovery\trader30\"

/*Net_Use(Trim(Tr_getini(1))+"\recovery\trader30\engauf","auf",.F.,0,"DBFCDX")
auf->(dbSetIndex(Trim(Tr_getini(1))+"\recovery\trader30\ntx\engauf.cdx"))
auf->(dbSetOrder( 1 ))

Auffo("",0,"")*/

aFiles := {"angebot","engauf","engkund","englsre"}
aAlias := {"ang","auf","ku","re"}
aIndexs :=  Array(4)
aIndexs[1] := {"angebot.001","angebot.002","angebot.003","angebot.004","angebot.005","angebot.006","angebot.007"}
aIndexs[2] := {"engauf.cdx"}
aIndexs[3] := {"engkund.cdx"}
aIndexs[4] := {"englsre.001","englsre.002","englsre.003","englsre.004","englsre.005","englsre.006","englsre.007","englsre.008","englsre.009","englsre.010"}
aSeek  := { {|| Str(&cBak->angnr,6)+Str(&cBak->Itmnr,3) },{|| Str(&cBak->Abnr,6)+Str(&cBak->Itmnr,3) }, {|| &cBak->Kunde + &cBak->Group }, {|| "" }  }
aOrder := {1,1,1,8}
aDriver := {"DBFNTX","DBFCDX","DBFCDX","DBFNTX"}

Head("Data recovery from backup file")

nC := AMenu(aFiles)

If nC != 0 
	If ! File(cBakDir+aFiles[nC]+".dbf")
		? "File not found: "+cBakDir+aFiles[nC]+".dbf"
		Inkey(0,128)
		Return
	Endif
	cBak := "__"+aAlias[nC]
	Net_Use(Trim(Tr_getini(1))+"\recovery\trader30\"+aFiles[nC],cBak,.F.,0,aDriver[nC])

	nI := 1
	Do While nI <= Len(aIndexs[nC])
		If ! File(cBakDir+"ntx\"+aIndexs[nC,nI])
			? "File not found: "+cBakDir+"ntx\"+aIndexs[nC,nI]
		Else
			&cBak->(dbSetIndex(cBakDir+"ntx\"+aIndexs[nC,nI]))
		Endif
		nI++
	Enddo

	cOri := aAlias[nC]
	NetUse(aFiles[nC],cOri,.F.,0)
	&cori->(dbSetOrder( aOrder[nC] ))


	&cBak->(dbGoTop())

	@ 01,00 SAY ""
	Do While ! &cBak->(Eof())
		nRow := Row()
		@ 01,00 SAY &cBak->(Recno())
		SetPos(nRow,00)
		If ! &cOri->(dbSeek( Eval(aSeek[nC]) ))
			? "Record not found",Eval(aSeek[nC])
			nX := 1
/*			&cOri->(Add_rec(0))
			Do While nX <= &cBak->(FCount())
				&cOri->(FieldPut( nX,&cBak->(FieldGet(nX)) ))
				nX++
			Enddo
			&cOri->(dbUnLock())*/
		Endif
		&cBak->(dbSkip())
	Enddo
Endif
? "done"
SInkey(0,128)
