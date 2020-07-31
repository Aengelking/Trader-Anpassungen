FUNCTION GetArchiveDir(hType,dDate)
   LOCAL cDir := GetArchiveBaseDir(hType)

   IF ValType(dDate) == "D" .AND. HHasKey(hType,"DIV") .AND. ValType(hType["DIV"]) == "C"
      IF "Y" $ hType["DIV"]
         cDir += Str(Year(dDate),4)+"\"
      ENDIF
      IF "M" $ hType["DIV"]
         cDir += StrZero(Month(dDate),2)+"\"
      ENDIF
   ENDIF

RETURN cDir

FUNCTION CreateArchiveDir(cDir)
   LOCAL cBase := GetConfigValue("ARCHIVE_DIR")+"\"
   LOCAL aDir := HB_Atokens(cDir,"\")
   LOCAL cCreated := "",nX
   FOR nX := 1 TO Len(aDir)
      cCreated += IF(nX>1,"\","")+aDir[nX]
      IF ! IsDirectory(cCreated)
         MakeDir(cCreated)
      ENDIF
//      ? cCreated
   NEXT
RETURN .T.

FUNCTION GetArchiveDirList(hType)
   LOCAL aDir := {}
   LOCAL cDir := GetArchiveBaseDir(hType)

   IF HHasKey(hType,"DIV")
      _RecurseGetArchiveDirList(hType,cDir,aDir)
   ELSE
      Aadd(aDir,cDir)
   ENDIF
RETURN aDir

STATIC FUNCTION _RecurseGetArchiveDirList(hType,cDir,aDir)
   LOCAL aTemp,nX
   LOCAL nCount := 0,cSubDir
   aTemp := Directory(cDir+"*.*","D")
   FOR nX := 1 TO Len(aTemp)
      IF AT(".",aTemp[nX,1]) != 1 .AND. "D" $ aTemp[nX,5]
         cSubDir := cDir+aTemp[nX,1]+"\"
         IF _RecurseGetArchiveDirList(hType,cSubDir,aDir) == 0 //no sub-directories found, so now we add this one
            nCount++
            Aadd(aDir,cSubDir)
         ENDIF
      ENDIF
   NEXT
RETURN nCount


FUNCTION GetArchiveBaseDir(hType)
RETURN GetConfigValue("ARCHIVE_DIR")+"\"+hType:Dir+"\"

FUNCTION GetArchivePrefix(hType,nNo)
RETURN hType:Prefix+StrZero(nNo,IF(HHasKey(hType,"NUMLEN"),hType:NumLen,6)) //standard length is 6, but can be set