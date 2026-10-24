PROCEDURE CONVERTDBF
LOCAL aFiles,cNewDir,cFile,cTo,hDirs,cFrom
LOCAL nX,lDbt,Aends,nZ,aSubFiles,nY

Head("Convert all DBFs to CDX")

IF Tr_Getini(28) != 9
RETURN
ENDIF


aFiles := Directory(Path("*.dbf"))
cNewDir := Path("convert\")

FOR nX := 1 TO Len(aFiles)
   cFile := StrTran(Upper(aFiles[nX,1]),".DBF","")
   //cFile := "CURRENCY"

   IF (File(Path("NTX\"+cFile+".001")) .OR. File(Path("NTX\"+cFile+".NTX"))) .AND. ! File(Path(cFile+".DBT"))  .AND. cFile != "CURRENCY"
      ? cFile

      IF .T. //Upper(cFile) == "ENGABG"
      lDbt := File(Path(cFile+".DBT"))

      IF ! NetUse(cFile,"from",.T.,5)
         Alert("File cannot be opened exclusivly")
         RETURN
      ENDIF

      DBCreate(cNewDir+cFile,from->(DBStruct()),"DBFCDX",.T.,"to")

      DO WHILE from->(IndexOrd()) != 0
         to->(dbCreateIndex(cNewDir+"\ntx\"+cFile+".cdx",from->(OrdKey()),,from->(OrdIsUnique()),Upper(cFile)+StrZero(from->(IndexOrd()),2) ))
         from->(dbSetOrder(from->(IndexOrd())+1))
      ENDDO

      from->(dbCloseArea())

      IF lDbt //in case of dbt files we need the data too
         dbSelectArea("to")
         APPEND FROM (cFile)
      ENDIF
      to->(dbCloseArea())

      hDirs := {"ntx"=>"obsolete","convert\ntx"=>"ntx"}
      IF lDbt
         hDirs[""] := "obsolete"
         hDirs["convert"] := ""
      ENDIF

      aEnds := {"dbf","dbt","fpt","cdx","0*","ntx"}

      FOR EACH cTo IN hDirs
         cFrom := cTo:__enumKey()
         FOR nZ := 1 TO Len(aEnds)
            aSubFiles := Directory(Path(cFrom+"\"+cFile+"."+aEnds[nZ]))
            FOR nY := 1 TO Len(aSubFiles)
               ? Path(cFrom+"\"+aSubFiles[nY,1])+"=>"+Path(cTo+"\"+aSubFiles[nY,1]),":"
               ??  FileMove(Path(cFrom+"\"+aSubFiles[nY,1]),Path(cTo+"\"+aSubFiles[nY,1]))
            NEXT
         NEXT
      NEXT
      ENDIF
   ENDIF
//NEXT

Inkey(0,128)