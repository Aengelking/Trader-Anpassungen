Head("Reindexing")
/*aFile1 := {'atrans','artikel','artlief','angebot','cat','englsre','engbew','enras','engrech','engbes','engabg',"funktion",'werks','lagerne','lagent','werkauf','engkund','engauf','parts',"stats","tempstat","buyer","lists","lager",'fibu'}
aFile2 := {'muster','buyprice','artkund','contacts','ups','countrie','currency','folgeart','notes','kon1998','manufact','vat','opttext','lagrech','le','le_art','le_praef','group','stafprei','bipbl','rechpos','freigabe','ppf','ppfdat'}
aFile3 := {'ls','lspos','rep','option','printer','print','lock','lsbook','branch','lagerort'}

//the interpreter can only except a certain line length, semicolon does not work, so we have to do it the complicated way :-(
aFile := Array(Len(aFile1)+Len(aFile2)+Len(aFile3))
ACopy(aFile1,aFile,1,Len(aFile1),1)
ACopy(aFile2,aFile,1,Len(aFile2),Len(aFile1)+1)
ACopy(aFile3,aFile,1,Len(aFile3),Len(aFile1)+Len(aFile2)+1)*/
/*nX:= 1
Do While nX <= Len(aFile2)
	Aadd(aFile,aFile2[nX])
	nX++
Enddo*/


SET CONSOLE ON

nChoice := AMenu({"Reindex","Show","Reindex All"})
IF nChoice == 0
   RETURN
ENDIF

aDir := Directory(Trim(Tr_Getini(1))+"\*.dbf")
aFile := {}
AEval(aDir,{|x| cFile := StrTran(Upper(x[1]),".DBF"),IF(File(Trim(Tr_Getini(1))+"\ntx\"+cFile+".*"),Aadd(aFile,cFile),"") })

ASort(aFile)
IF nChoice != 3
   nI := AMenu(aFile)
ELSE
   nI := 1
   nI := AScan(aFile,{|x| AT("FOLGEART",x) == 1 })
   IF nI == 0
      Alert("Not Found")
      RETURN
   ENDIF
ENDIF

If ( nI > 0 )
   nEnd := IF(nChoice==3,Len(aFile),nI)
   FOR nI := nI TO nEnd
      cFile := aFile[ni]
   
   
   /*aFile := Directory(Trim(Tr_Getini(1))+"\*.dbf")
   Ni := AScan(aFile,{|x| AT("T",Upper(x[1])) == 1 })
   FOR nI := Ni TO Len(aFile)
   
   	cFile := StrTran(Upper(aFile[ni,1]),".DBF","")
   IF File(Trim(Tr_Getini(1))+"\obsolete\"+cFile+".NTX")
   */
   	If cFile == "CURRENCY" .AND. Select("cur") != 0
   		Alert("Close workarea")
   		cur->(dbCloseArea())
   	Endif
   		? cFile
           NetUse(cFile,cFile,If(nChoice==1 .OR. nChoice == 3,.T.,.F.),0)
   
           If ( nChoice == 1 .OR. nChoice == 3)
           	//PACK
           Endif
   		nOrd := 1
   	do while dbSetOrder(nOrd) != NIL .AND. nOrd == IndexOrd()
   		? '  '+StrZero(nOrd,2)+'. '+OrdKey(nOrd)
   		//ordCondSet(,,.T.,{||.T.},{||  SetPos(Row(),0),QQout(STR((RECNO()/LASTREC()) * 100,3,0)+'%') },10)
   		if ( nChoice == 1 .OR. nChoice == 3)
   			ordListRebuild()
   		Endif
   		nOrd++
   	enddo
   	dbCloseArea()
   NEXT

endif
//NEXT

? "Done"

inkey(0,128)





