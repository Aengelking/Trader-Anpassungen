PROC RUN_REINDEX
   LOCAL nChoice,aDir,aFile
   LOCAL cFile,nI,nEnd,nOrd

   Head("Reindexing")

   /*IF ! SystemUser():CheckPermission("U","SYSTEM_DATABASE")
      RETURN
   ENDIF*/

   SET CONSOLE ON

   nChoice := AMenu({"Reindex","Show","Reindex All"})
   IF nChoice == 0
      RETURN
   ENDIF
   
   IF ! Empty(GetConfigValue("LETO_SERVER"))
      aDir := Leto_Directory("*.dbf") //Trim(Tr_Getini(1))+"\*.dbf")
   ELSE
      Alert(Path("\*.dbf","DB"))
      aDir := Directory(Path("\*.dbf","DB"))
   ENDIF
   aFile := {}   
   AEval(aDir,{|x|       
      cFile := StrTran(Upper(x[1]),".DBF")      
      Aadd(aFile,cFile)
      
      RETURN .T.
   })
   ? Len(aFile)
   ASort(aFile)
   IF nChoice != 3
      nI := AMenu(aFile)
   ELSE      
      dbCloseAll()
      //nI := AScan(aFile,{|x| AT("FOLGEART",x) == 1 })
      nI := 1
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
      BEGIN SEQUENCE
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
         RECOVER
            dbCloseArea()
         END
      NEXT
      

   endif
   //NEXT

   ? "Done"

   inkey(0,128)





