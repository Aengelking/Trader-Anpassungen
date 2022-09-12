FUNCTION HOOK_ADD_ARCHIVE_FILE( cTyp,nNo,cFileName,lAttached,oObject )

#include 'archive.ch'

LOCAL cPrefix := GetArchivePrefix(hTypes[cTyp],nNo) //standard length is 6, but can be set
LOCAL cNewFileName,cPath,cExtension,cSaveFileName,nAdd := 0,cAdd := ""
LOCAL dDate,cTime
LOCAL cDir,nPos
LOCAL oAgorum

Default(@lAttached,.T.)

HB_FNameSplit(cFileName,@cPath,@cNewFileName,@cExtension)
cPath := SubStr(cFileName,0,Rat("\",cFilename))
cNewFileName := SubStr(cFileName,Len(cPath)+1,Rat(".",cFileName)-Len(cPath)-1)
cExtension := SubStr(cFileName,Len(cPath)+Len(cNewFileName)+1)

dDate := FileDate(cFileName)
cDir := GetArchiveDir(hTypes[cTyp],dDate)
CreateArchiveDir(cDir)

IF (nPos := AT(cPrefix,cNewFileName)) != 0
   cNewFileName := SubStr(cNewFileName,nPos+Len(cPrefix))
ENDIF

IF cTyp == "ER" //in this case we always want a revision
   cAdd := "_0_"
ENDIF


DO WHILE /*cSaveFileName == NIL .OR.*/ File(HB_FNameMerge(cDir,cPrefix+cAdd)+"*") //.OR. File(cSaveFileName)
   nAdd ++
   cAdd := "_"+LTrim(Str(nAdd))+"_"
ENDDO

IF Empty(cAdd )
   cAdd := "_"
ENDIF

cSaveFileName := HB_FNameMerge(cDir,cPrefix+cAdd+cNewFileName,cExtension)


COPY FILE (cFileName) TO (cSaveFileName)
IF ! SetFDaTi(cSaveFileName,dDate,FileTime(cFileName))
ENDIF

IF ! lAttached .AND. Tr_getini(28) == 9  .AND. ! GetConfigValue("BATCHMODE")
   //IF Type("AGORUMCUSTOMAPI") == "U"; MBaseRun(Path("run\agorum")); ENDIF
   oAgorum := AgorumCustomApi():New()
   TxtBox("Archivierung...")
   IF ! oAgorum:AddFile(cTyp,nNo,cFilename,oObject)
      Alert("Nicht in Agorum archiviert;"+oAgorum:cErrorText)
   ELSE
      Alert("In Agorum erfolgreicharchiviert")
   ENDIF
   TxtClear()
ENDIF

RETURN cSaveFileName

#include 'archive.prg'
#include 'x:\run\agorum.prg'