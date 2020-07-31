//find all files that could not be loaded via LETO
//if we move these files to a database directory then this could be protected with windows permissions that only the leto server could access them
//then we could also protect the leto server with a password
PROCEDURE Check_DBFiles
LOCAL aFiles,nX
LOCAL aIndex
LOCAL cFile
CLS
aFiles := Directory(Path("*.dbf"))
FOR nX := 1 TO Len(aFiles)
   cFile := SubStr(aFiles[nx,1],1,Len(aFiles[nX,1])-4)
   IF AT("FORM",Upper(cFile)) == 0
      aIndex := DIRECTORY(Path("ntx"+HB_OSPATHSEPARATOR()+cFile+".*"))
      IF Len(aIndex) >= 1 .AND. AScan(aIndex,{ |element| AT(".C",Upper(element[1]))!=0 })==0 .OR. File(Path(cFile+".dbt"))
         ? aFiles[nX,1]
      ENDIF
   ENDIF
NEXT
SiNkey(0)