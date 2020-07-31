FUNCTION HOOK_ADD_ARCHIVE_FILE( cTyp,nNo,cFileName )

#include 'archive.ch'

LOCAL cPrefix := GetArchivePrefix(hTypes[cTyp],nNo) //standard length is 6, but can be set
LOCAL cNewFileName,cPath,cExtension,cSaveFileName,nAdd := 0,cAdd := ""
LOCAL dDate,cTime
LOCAL cDir
HB_FNameSplit(cFileName,@cPath,@cNewFileName,@cExtension)
cPath := SubStr(cFileName,0,Rat("\",cFilename))
cNewFileName := SubStr(cFileName,Len(cPath)+1,Rat(".",cFileName)-Len(cPath)-1)
cExtension := SubStr(cFileName,Len(cPath)+Len(cNewFileName)+1)

dDate := FileDate(cFileName)
cDir := GetArchiveDir(hTypes[cTyp],dDate)
CreateArchiveDir(cDir)

IF (nPos := AT(cPrefix,cNewFileName)) != 0
   //cNewFileName := cPrefix+"_"+cNewFileName
   cNewFileName := SubStr(cNewFileName,nPos+Len(cPrefix))
//ELSE
//   cNewFileName := cNewFileName
ENDIF

IF cTyp == "ER" //in this case we always want a revision
   cAdd := "_0_"
ENDIF


DO WHILE /*cSaveFileName == NIL .OR.*/ File(HB_FNameMerge(cDir,cPrefix+cAdd)+"*") //.OR. File(cSaveFileName)
   nAdd ++
   cAdd := "_"+LTrim(Str(nAdd))+"_"
   //? cAdd,HB_FNameMerge(cDir,cPrefix+cAdd)+"*"
   //Alert(cSaveFileName+" "+IF(File(cSaveFileName),"yes","no"))
ENDDO

cSaveFileName := HB_FNameMerge(cDir,cPrefix+cAdd+cNewFileName,cExtension)

//cTime := Time()

COPY FILE (cFileName) TO (cSaveFileName)
IF ! SetFDaTi(cSaveFileName,dDate,FileTime(cFileName))
  // Alert("Timestamp not set")
ENDIF

RETURN cSaveFileName

#include 'archive.prg'