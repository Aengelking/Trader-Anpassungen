PROCEDURE BackupDB
LOCAL aDir := Directory(Path(,"DB")+"\*.dbf")
LOCAL cBackDir := "Y:\Backup\Trader\"
LOCAL nRow := 0
LOCAL cLog := ""
LOCAL lError := .F.
LOCAL bErrorBlock
LOCAL dBackupDate,dFileDate
LOCAL nSkipped := 0
LOCAL cFile
LOCAL aExclude := {".*\.bak(\..*)?","TEMPSTAT.DBF",".*\.zip"}
LOCAL nX,cRegex
LOCAL lExclude := .F.,cDriver
LOCAL oErr
LOCAL aFiles := {}
LOCAL aEndings := {"DBF","FPT","CDX","JSON"},cEnd,cFileName
LOCAL cServer := GetConfigValue("LETO_SERVER")
LOCAL cStructure

cStructure := MBaseRun(Path("run\getdbstructure"))

IF ! Empty(cServer)
   IF Empty(Path(,"DB"))
      cLog := "Backup only works locally"
      lError := .T.
      aDir := {}
   ELSE
      SetConfigValue("LETO_SERVER","") //deactivate LETO
   ENDIF
ENDIF

Head("Database Backup")
//this prog is used to backup the dbf files to a directory (even if they are in use), LETO opens files exclusively

dbCloseAll()

FOR nX := 1 TO Len(aDir)
   dFileDate := FileDate(Path(,"DB")+aDir[nX,1])
   dBackupDate := FileDate(cBackDir+aDir[nX,1])
   FOR EACH cRegex IN aExclude
      lExclude := HB_RegexMatch(cRegex,aDir[nX,1])
      IF lExclude
         EXIT
      ENDIF
   NEXT

   IF ! lExclude //if it is not excluded we add to the files to be zipped
      FOR EACH cEnd IN aEndings
         cFileName := SubStr(aDir[nX,1],1,RAT(".",aDir[nX,1]))+cEnd         
         IF File(cBackDir+cFileName)            
            Aadd(aFiles,cBackDir+cFileName)
         ENDIF
      NEXT
      
   ENDIF
          
   IF ! lExclude .AND.  dBackupDate < dFileDate .OR. (dBackupDate == dFileDate .AND. FileTime(cBackDir+aDir[nX,1]) < FileTime(Path(,"DB")+aDir[nX,1]) ) //.OR. FileSize(cBackDir+aDir[nX,1]) != FileSize(Trim(Tr_Getini(1))+"\"+aDir[nX,1])
      IF nRow >= MaxRow()
         Scroll(01,00,MaxRow(),MaxCol(),1)
         nRow := MaxRow()
      ELSE
         nRow++
      ENDIF
      @ nRow,00 SAY aDir[nX,1]

      IF nX > 1
         cLog += Chr(13)+Chr(10)
      ENDIF
      cLog += aDir[nX,1]
      cFile := StrTran(Upper(aDir[nX,1]),".DBF")

      bErrorBlock := ErrorBlock({|e| Break(e) })

      BEGIN SEQUENCE
         IF Select("backup") != 0
            backup->(dbCloseArea())
         ENDIF
         cDriver := "DBFCDX"
         IF File(Path(,"DB")+cFile+".dbt")
            cDriver := "DBFNTX"
         ENDIF

         NetUse(cFile,"backup",,,cDriver)
         backup->(dbSetOrder(0)) //keep current order

         COPY TO (cBackDir+aDir[nX,1]) VIA cDriver
         cLog += " success) , Driver:"+cDriver
         ErrorBlock(bErrorBlock)
      RECOVER USING oErr
         ErrorBlock(bErrorBlock)
         lError := .T.
         ?? " !! ERROR !!",oErr:description
         cLog += " **** ERROR: "+oErr:description //n+" Driver: "+cDriver
         
         IF ( !Empty(oErr:osCode) )
            ?? " (DOS Error " + LTRIM(Str(oErr:osCode)) + ") "
            cLog += " (DOS Error " + LTRIM(Str(oErr:osCode)) + ") "
         ENDIF
         cLog += " "+ Path(,"DB")+cFile  
         IF File(Path(,"DB")+cFile+".dbt")
            cLog += " DBT Found"
         ENDIF
   
         //lCdx := (nFileCount == 0 .OR. File(cIdxDir+FILE+".cdx")) .AND. ! File(Path(,"DB")+file+".dbt")


      END

   ELSE
      nSkipped ++
//      ?? " skipped"
//      cLog += " skipped"
   ENDIF

NEXT

//cStructure := MBaseRun(Path("run\getdbstructure"))
MemoWrit(cBackDir+"dbstructure.json",cStructure)

HB_ZipFile(cBackDir+"trader_"+Left(TtoS(DateTime()),14)+".zip",aFiles,4,,.T.,.F.,.F.)

cLog := "Files skipped: "+LTrim(Str(nSkipped))+Chr(13)+Chr(10)+cLog
//cLog := "Directory: "+GetConfigValue("PATHS_DB")+Chr(13)+Chr(10)+cLog

SendMail({{"amos.engelking@engelking.de","Amos"}},"DB Backup "+IF(lError,"FAILED","success"),cLog)