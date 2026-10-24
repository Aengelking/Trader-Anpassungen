PROCEDURE RUN_CREATE_INIT_ARCHIVE()
   LOCAL dStart := StoD("20190818")
   LOCAL dEnd   := StoD("20190825")
   //LOCAL dEnd   := dStart+6
   LOCAL dDate
   /*FOR dDate := dStart TO dEnd-6 STEP 6
     ? dDate
     __Run("powershell.exe Set-Date "+Str(Year(dDate+7),4)+"-"+StrZero(Month(dDate+7),2)+"-"+StrZero(Day(dDate+7)+1,2)+"T18:00")
      RUN_ARCHIVE_TO_WORM(dDate+6,dDate)
      Alert("Burn files")
   NEXT*/
   
     ? dStart
     __Run("powershell.exe Set-Date "+Str(Year(dend),4)+"-"+StrZero(Month(dEnd),2)+"-"+StrZero(Day(dEnd)+1,2)+"T18:00")
      RUN_ARCHIVE_TO_WORM(dEnd,dStart)
      //Alert("Burn files")
   
   /*FOR dDate := dStart TO Date()
      RUN_ARCHIVE_TO_WORM(dDate)
   NEXT*/

PROCEDURE RUN_ARCHIVE_TO_WORM(dToday,dLastRun)
   #include "x:\hooks\archive.ch"

   LOCAL aDrives := {"F:","G:","J:","K:"}
   

   LOCAL cDir,cFiles,aDir
   LOCAL nYear,nY,nX
   //LOCAL dLastRun := dToday-1 //StoD("20180106") //Date()-360 //we need to think of a way to save 
   //LOCAL dToday   := dLastRun+1 //Date() 
   LOCAL nFirstYear := 2015
   LOCAL nYearEnd   := Year(dToday)
   LOCAL nYearBegin := Max(nFirstYear,nYearEnd-1)
   LOCAL lFound
   LOCAL hType

   LOCAL cFilter
   LOCAL cKey
   LOCAL hCommands := {=>}
   LOCAL nFrom,nTo,nDig,nD
   LOCAL aCommands,cCommand,hCom,cDrive
   LOCAL cProto := ""

   Head("Writing archived files to WORM")

   IF nYearEnd < nFirstYear
      Alert("Nothing to be done")
      RETURN 
   ENDIF

   FOR EACH hType IN hTypes
      ? hType["NAME"]
      IF hType:__eNumKey() == "ER"
         
         FOR nYear := nYearBegin TO nYearEnd
            IF nYear >= 2017
               FOR nY := nYear TO nYearEnd
                  cDir := GetArchiveBaseDir(hType)+Str(nY,4)+"\"
                  cFiles := "ER"+Right(Str(nYear,4),2)+"*.*"
                  aDir := Directory(cDir+cFiles)
                  lFound := .F.
                  FOR nX := 1 TO Len(aDir)
                     IF aDir[nX,3] >= dLastRun
                        lFound := .T.
                     ENDIF
                  NEXT
                  IF lFound
                     cKey := _AddHash(hCommands,hType,nYear)
                     Aadd(hCommands[cKey],{"FROM"=>cDir,"TO"=>hType:Dir,"FILES"=>cFiles})
                  ENDIF,nX
               NEXT
            ELSEIF nYear == 2016
               cDir := GetArchiveBaseDir(hType)+Str(nYear,4)+"\"
               cKey := _AddHash(hCommands,hType,nYear)
               Aadd(hCommands[cKey],{"FROM"=>cDir,"TO"=>hType:Dir,"FILES"=>"*.*"})
            ENDIF
         NEXT
            
      ELSEIF hType:__eNumKey() == "RE"
         cDir := GetArchiveBaseDir(hType)
         NetUse("englsre","re")
         re->(dbSetOrder(4))
         FOR nYear := nYearBegin TO nYearEnd
            //cFilter := 'rechdat >= StoD("'+Str(nYear,4)+'0101") .AND. rechdat <= StoD("'+Str(nYear,4)+'1231")'
            cFilter := 'rechdat >= StoD("'+IF(nYear==nYearBegin,DtoS(dLastRun),Str(nYear,4)+'0101')+'") .AND. rechdat <= StoD("'+IF(nYear==nYearEnd,Dtos(dToday),Str(nYear,4)+'1231')+'")'
            re->(dbSetFilter( {|| re->(&(cFilter))},cFilter))
            re->(dbGoTop())
            IF ! re->(BOF())
               nFrom := re->Rechnr
            ELSE //no invoices found
               re->(dbClearFilter())
               LOOP
            ENDIF
            re->(dbGoBottom())
            IF ! re->(EOF())
               nTo := re->Rechnr
            ELSE
               nTo := 999999
            ENDIF
            //compressing number-ranges to wildcard file spec
            ? nYear,nFrom,nTo
            nDig := 0
            FOR nX := nFrom TO nTo                   
               IF nDig > 0
                  IF Val(Left(Str(nX,6),6-nDig)+Replicate("0",nDig))+10**nDig < nTo
                     cKey := _AddHash(hCommands,hType,nYear)
                     Aadd(hCommands[cKey],{"FROM"=>cDir,"TO"=>hType:Dir,"FILES"=>hType["PREFIX"]+Left(StrZero(nX,6),6-nDig)+"*.*"})

                     nX := Val(Left(Str(nX,6),6-nDig)+Replicate("0",nDig))+10**nDig
                     IF Right(Left(Str(nX,6),6-nDig),1) == "0"
                        nDig++
                     ENDIF
                  ELSE
                     nDig-- 
                     nX-=1   
                     IF nDig == 0
                        cKey := _AddHash(hCommands,hType,nYear)
                        Aadd(hCommands[cKey],{"FROM"=>cDir,"TO"=>hType:Dir,"FILES"=>hType["PREFIX"]+Left(StrZero(nX,6),6-nDig)+"*.*"})
                     ENDIF
                     LOOP
                  ENDIF
               ELSE
                  IF Right(Str(nX,6),1) == "0" //we have reached the next digit
                     nDig++                     
                     LOOP
                  ENDIF
                  cKey := _AddHash(hCommands,hType,nYear)
                  Aadd(hCommands[cKey],{"FROM"=>cDir,"TO"=>hType:Dir,"FILES"=>hType["PREFIX"]+Left(StrZero(nX,6),6-nDig)+"*.*"})

               ENDIF
            NEXT
            re->(dbClearFilter())
         NEXT
      ELSEIF ! HHasKey(hType,"DIV") //.AND. hType["KEEPFOR"] == 10
         FOR nYear := Max(nFirstYear,Year(dLastRun)) TO nYearEnd
            cDir := GetArchiveBaseDir(hType)
            aDir := Directory(cDir+"*.*")
            lFound := .F.
            FOR nX := 1 TO Len(aDir)
               IF aDir[nX,3] >= dLastRun .AND. Year(aDir[nX,3]) == nYear .AND. aDir[nX,3] <= dToday
                  lFound := .T.
               ENDIF
            NEXT
            ? nYear
            IF lFound
               cKey := _AddHash(hCommands,hType,nYear)

               Aadd(hCommands[cKey],{"FROM"=>cDir,"TO"=>hType:Dir,"FILES"=>"*.*","YEAR"=>nYear})
            ELSE
               ?? " no files "+DtoC(dLastRun)+"-"+DtoC(dToday)
            ENDIF
         NEXT
      ENDIF
   NEXT

   ? "Following Volumes required"
   FOR EACH aCommands IN hCommands
      IF Len(aCommands) > 0
         ? aCommands:__eNumKey()
         lFound := .F.
         cDrive := ""
         /*DO WHILE ! lFound
            FOR nD := 1 TO Len(aDrives)
               ? aDrives[nD],GetVolInfo(aDrives[nD]) 
               IF GetVolInfo(aDrives[nD]) == aCommands:__eNumKey()
                  cDrive := aDrives[nD]
                  lFound := .T.
                  EXIT
               ENDIF
            NEXT
            IF ! lFound
               Tr_MsgBox("Please insert Volume "+aCommands:__eNumKey())
               //EXIT
            ENDIF
         ENDDO*/
         cDrive := "C:\Archive-Temp\"+aCommands:__eNumKey()
         
         /*IF ! lFound
            Alert("Still not found")
         ELSE */
            //execute the commands and copy the files to the volume
            ? "copying files"
            FOR EACH hCom IN aCommands

               __RunProc("powershell.exe Set-Date -Date "+Str(Year(dToday),4)+"-"+StrZero(Month(dToday),2)+"-"+StrZero(Day(dToday),2)+"T"+Time())
               IF ! IsDirectory(cDrive+"\"+hCom:To)
                  __RunProc("cmd.exe /C mkdir "+cDrive+"\"+hCom:To)
                  __RunProc("powershell.exe (Get-Item "+hCom:From+").LastWriteTime = Get-Date")
               ENDIF

               cCommand :=  "C:\Windows\System32\robocopy "+hCom:From+" "+cDrive+"\"+hCom:To+"\ "+hCom:Files+" "
               IF HHasKey(hCom,"YEAR")
                  IF Year(dLastRun) != hCom:Year
                     cCommand += "/maxage:"+Str(hCom:Year,4)+"0101"
                  ELSE                  
                     cCommand += "/maxage:"+DtoS(dLastRun)
                  ENDIF

                  cCommand += " "
                  IF hCom:Year == nYearEnd
                     cCommand += "/minage:"+DTos(dToday)
                  ELSE
                     cCommand += "/minage:"+Str(hCom:Year+1,4)+"0101"
                  ENDIF
               ELSE
                  cCommand += "/maxage:"+Dtos(dLastRun)+" /minage:"+DTos(dToday)
                  //cCommand += "/maxage:"+Str(Year(dLastRun)-1,4)+"1231"+" "
                  //cCommand += " /minage:"+DTos(dToday+1)
               ENDIF
               cCommand += " /xc /xn /DCOPY:DAT"
               //? cCommand
               cProto += __RunProc(cCommand)
               //__Run(cCommand)
            NEXT
         //ENDIF
      ENDIF
   NEXT

   //MemoEdit(cProto)

   MemoWrit("C:\Archive\protokoll_"+TtoS(DateTime())+".txt",cProto)
   
   //Sinkey(0)

RETURN

STATIC FUNCTION _AddHash(hHash,hType,nYear)
   LOCAL cKey := Ltrim(Str(hType["KEEPFOR"]))+"J"+Str(nYear,4)
   IF ! HHasKey(hHash,cKey)
      hHash[cKey] := {}
   ENDIF
RETURN cKey

STATIC FUNCTION __RunProc(cCmd)
   LOCAL nProc,nStdOut,nStdErr,cData,cTxt := "",cStdErr := "",nErrBytes,nStdBytes
   LOCAL nRet
   nProc := HB_OpenProcess(cCmd,,@nStdOut,@nStdERR,.T.)
   
   IF nProc < 0
      ? "Error executing exe "+cCmd
      Sinkey(0)
      RETURN ""
   ENDIF

   ? cCmd
   nErrBytes := 1
   nStdBytes := 1
   nRet := -1
   DO WHILE nRet != -1 .OR. nStdBytes > 0 .OR. nErrBytes > 0
      nRet := HB_ProcessValue(nProc,.F.)
      cData := Space( 100 )
      nStdBytes := Fread( nStdOUT, @cData, Len(cData) )
      cData := HB_AnsiToOem(Left(cData,nStdBytes))
      ?? StrTran(cData,Chr(9),Space(5))
      cTxt += Trim(cData)
      cData := Space( 100 )
      nErrBytes := Fread( nStdERR, @cData, 1000 ) //Len(cData) )
      cStdErr += HB_AnsiToOem( Left( cData, nErrBytes ) )   

      //? nRet,nStdBytes,nErrBytes
      //Inkey(.1)   
      IF LastKey() == 27
         EXIT
      ENDIF
   ENDDO

   FClose(nStdERR)
   FClose(nStdOUT)

   ? cStdErr

   gtSetClipboard(cTxt)
   //Alert(cTxt)
RETURN cTxt

#include "x:\hooks\archive.prg"
   

