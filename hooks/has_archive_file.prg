PARAMETERS cTyp,nNo,cFileName,dDate,cTime

#include 'archive.ch'

LOCAL cPrefix := GetArchivePrefix(hTypes[cTyp],nNo)
LOCAL cNewFileName,cPath,cExtension,cSaveFileName,nAdd := 0,cAdd := ""
LOCAL aDir,aDirs,cDir
//HB_FNameSplit(cFileName,@cPath,@cNewFileName,@cExtension)
cPath := SubStr(cFileName,0,Rat("\",cFilename))
cNewFileName := SubStr(cFileName,Len(cPath)+1,Rat(".",cFileName)-Len(cPath)-1)
cExtension := SubStr(cFileName,Len(cPath)+Len(cNewFileName)+1)

IF AT(cPrefix,cNewFileName) == 0
   cNewFileName := cPrefix+"_*"+cNewFileName
ELSE
   cNewFileName := cNewFileName
ENDIF


aDirs := GetArchiveDirList(hTypes[cTyp])

FOR EACH cDir IN aDirs
   aDir := Directory(HB_FNameMerge(cDir,cNewFileName+"*",cExtension))
   IF Len(aDir) > 0
      IF ValType(dDate) == "D" .AND. ValType(cTime) == "C"
         RETURN AScan(aDir,{|x| x[3] == dDate .AND. x[4] == cTime }) != 0
      ELSE
         IF Tr_Getini(28) == 9
            //Alert(ValType(cTime))
         ENDIF
         RETURN .T.
      ENDIF
   ENDIF
NEXT

RETURN .F.

#include 'archive.prg'