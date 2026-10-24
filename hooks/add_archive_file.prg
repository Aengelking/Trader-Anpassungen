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

IF AT("IIS",HB_UserName()) != 0  //IIS cannot save to archive
   RETURN ""
ENDIF

IF (nPos := AT(cPrefix,cNewFileName)) != 0
   cNewFileName := SubStr(cNewFileName,nPos+Len(cPrefix)-1)
ENDIF

IF cTyp == "ER" //in this case we always want a revision
   cAdd := "_0_"
ENDIF


DO WHILE /*cSaveFileName == NIL .OR.*/ File(HB_FNameMerge(cDir,cPrefix+cAdd)+"*") //.OR. File(cSaveFileName)
   nAdd ++
   cAdd := "_"+LTrim(Str(nAdd))+"_"
ENDDO

IF Empty(cAdd ) .AND. ! Empty(cNewFileName)
   cAdd := "_"
ENDIF

cSaveFileName := HB_FNameMerge(cDir,cPrefix+cAdd+cNewFileName,cExtension)


COPY FILE (cFileName) TO (cSaveFileName)
IF ! SetFDaTi(cSaveFileName,dDate,FileTime(cFileName))
ENDIF

IF ! lAttached .AND. (Tr_getini(28) $ {9,45} .OR. cTyp $ {"RE"}) // .AND. ! GetConfigValue("BATCHMODE")
   LoadPrg(Path("run\agorum.prg"))
   //IF Type("AGORUMCUSTOMAPI") == "U"; MBaseRun(Path("run\agorum")); ENDIF
   oAgorum := HB_ExecFromArray({"AgorumCustomApi"}):New()
   TxtBox("Archivierung...")
   IF ! oAgorum:AddFile(cTyp,cFilename,oObject)
      SendMail({{"amos.engelking@engelking.de","Amos"}},"Dokument nicht in Agorum archiviert",cFileName+Chr(13)+Chr(10)+oAgorum:cErrorText)
   ENDIF
   TxtClear()
ENDIF

RETURN cSaveFileName

#include 'archive.prg'
//#include 'x:\run\agorum.prg'