#include 'y:\hb34\contrib\hbcurl\hbcurl.ch'
//#include 'hbcurl.ch'
#include 'hbclass.ch'

FUNCTION RUN_FREPPLE_CURL
   LOCAL cCmd,cDir,aFiles,nX,nProc,cLine,cData,nBytes,nStdOut
   LOCAL aBucket,aBuckets := {}
   LOCAL oFrepple
   LOCAL aOldBuckets ,aOldBucket        
   LOCAL cScreen,aOpPlan

   oFrepple := GetFreppleApi()  

   Head("Update frePPLe")

   NetUse("restime","rst")
   NetUse("watime","wat")
   NetUse("werkauf","wer")
   NetUSe("jobs","job")

   IF ! LockEntity("PPLUP",0)  //make sure it is not run in parallel
      RETURN .F.
   ENDIF


   //? "Deleting calendar buckets "
   IF ! File(Path("export\frepple\calendar buckets.csv"))
      ? "Downloading existing calendar buckets "
      aOldBuckets := oFrepple:getCalendarBuckets()
      IF ValType(aOldBuckets) == "A" .AND. Len(aOldBuckets) > 0
         aBucket := {}
         FOR nX := 1 TO Len(aOldBuckets[1])         
            Aadd(aBucket,HGetKeyAT(aOldbUckets[1],nX))
         NEXT
         Aadd(aBuckets,aBucket)
         FOR EACH aOldBucket IN aOldBuckets
            IF ":" $  aOldBucket["calendar"] //supplier buckets
               //@ Row(),27 SAY aOldBucket["id"]
               //oFrepple:deleteCalendarBucket(aOldBucket["id"])
            ELSE
               //@ Row(),27 SAY "Save"+Str(aOldBucket["id"])
               //? ""
               aBucket := {}
               FOR nX := 1 TO Len(aOldBucket)
                  IF HGetKeyAT(aOldbUcket,nX) $ {"startdate","enddate"} .AND. ValType(HGetValueAt(aOldBucket,nX)) == "C"
                     //? ValType(HGetValueAt(aOldBucket,nX)),HGetValueAt(aOldBucket,nX)
                     Aadd(aBucket,StrTran(HGetValueAt(aOldBucket,nX),"T"," "))
                  ELSEIF ValType(HGetValueAt(aOldBucket,nX)) == "L"
                     Aadd(aBucket,IF(HGetValueAt(aOldBucket,nX),"true","false"))
                  ELSE
                     Aadd(aBucket,HGetValueAt(aOldBucket,nX))   
                  ENDIF
                  
               NEXT
               Aadd(aBuckets,aBucket)
            ENDIF      
         NEXT
      ENDIF
      ?? "DONE"
      SaveAsCSV(Path("export\frepple\calendar buckets.csv"),aBuckets,.T.,.T.)
   ELSE
      ? "Using existing calendar buckets"
   ENDIF

   ? "Clear existing data. "
   IF ! oFrepple:waitEndOfTask(oFrepple:Empty(),Row(),Col())
      IF ! GetConfigValue("BATCHMODE") 
         Tr_MsgBox("failed")
      ENDIF
      UnLockEntity("PPLUP",0)
      RETURN .F.
   ENDIF

   ? "Remove any old files. "   
   IF oFrepple:DeleteUploads()
      ?? "done"
   ELSE
      ?? "failed"
      IF ! GetConfigValue("BATCHMODE") 
         Tr_MsgBox("failed")
      ENDIF
      UnLockEntity("PPLUP",0)
      RETURN .F.
   ENDIF

   ? "Upload files"
   //this is easier over the cmd line
   cCmd := "C:\Curl\bin\curl -u "+oFrepple:cUser+":"+oFrepple:cPW+" -X POST -k"
   cDir := "x:\export\frepple\"
   aFiles := {"item.csv","supplier.csv","buffer.csv","customer.csv","sales order.csv","item supplier.csv",;
               "purchase order.csv","manufacturing order.csv","operation material.csv","operation.csv","item distribution.csv",;
               "operation resource.csv","resource.csv","calendar.csv","calendar buckets.csv","calendar bucket.csv","resource detail.csv"}

   FOR nX := 1 TO Len(aFiles)
      cCmd += ' -F "'+aFiles[nX]+"=@"+cDir+aFiles[nX]+'"'
   NEXT
   cCmd += ' "'+oFrepple:cBaseUrl+'/execute/uploadtofolder/0/"'
   cData := ""
   nProc := HB_OpenProcess(cCmd,,@nStdOut,,.T.)
   IF nProc <= 0
      Alert("Failed to start process.;"+cCmd)
      UnLockEntity("PPLUP",0)
      RETURN .F.
   ENDIF
   DO WHILE HB_ProcessValue(nProc,.F.) == -1
      cLine := Space( 1000 )
      nBytes := Fread( nStdOUT, @cLine, Len(cLine) )
      cData += SubStr(cLine,1,nBytes)
   ENDDO
   ? " ",StrTran(StrTran(StrTran(cData,"<strong>",""),"</strong>",""),"<br>",Chr(13)+Chr(10)+"  ")

   ? "Syncing absences to frePPLe "
   cScreen := SaveScreen()
   Run_TimeButler(.F.,.F.,.T.,.F.) //re-sync timebutler calendars with frepple
   RestScreen(,,,,cScreen)
   ?? "completed"
   
   ? "Importing data. "
   IF ! oFrepple:waitEndOfTask(oFrepple:ImportFromFolder(),Row(),Col())  
      IF ! GetConfigValue("BATCHMODE") 
         Tr_MsgBox("failed")
      ENDIF
      UnLockEntity("PPLUP",0)
      RETURN .F.    
   ENDIF
   ?? "done"

   /*? "Update time of current tasks "
   rst->(dbSetOrder( 6 ))
   wat->(dbSetOrder( 4 ))
   job->(dbSetOrder( 1 ))
   aOpPlan := {}
   Select("wer")
   SET FILTER TO Empty(wer->Liefma) .AND. wer->Status == 3 .AND. wer->Qty-wer->PlanBad > 0 .AND. Right(Str(wer->TerminFrue,4),2) != "99"
   wer->(dbGoTop())
   DO WHILE ! wer->(EOF())         
      IF rst->(dbSeek( "WA "+Str(wer->Aufno,6) )) .AND. wat->(dbSeek( Str(wer->Aufno,6)+Str(rst->Job,6) )) //look for first entry in watime      
         job->(dbSeek( Str(rst->Job) ))
         ? rst->No, " ", rst->Type, " ", rst->Start, " ", rst->End
         Aadd(aOpPlan,{"id"=>"FA"+LTrim(Str(wer->Aufno))+"-"+Trim(job->Name),"startdate"=>FREP_StoT(rst->Start)})
         rst->(dbSkip())
      ENDIF
      wer->(dbSkip())
   ENDDO
   ? oFrepple:updateOperationPlan(aOpPlan)
   ?? "done"
   Sinkey(0)
   wer->(dbClearFilter())*/

   ? "Executing plan. "
   DO WHILE ! oFrepple:waitEndOfTask(oFrepple:RunPlan(),Row(),Col())
      IF GetConfigValue("BATCHMODE") .OR. Tr_MsgBox("Executing plan failed",,{"try again","cancel"}) != 1
         UnLockEntity("PPLUP",0)
         RETURN .F.         
      ENDIF
   ENDDO

   

   /*? "Executing plan a second time (until the bug with the manufacturing orders is solved). "
   IF ! oFrepple:waitEndOfTask(oFrepple:RunPlan(),Row(),Col())
      Alert("failed")
      RETURN NIL
   ENDIF*/

   /*? "Exporting results "
   IF ! oFrepple:waitEndOfTask(oFrepple:ExportToFolder(),Row(),Col())
      Alert("failed")
      RETURN NIL
   ENDIF*/

   ? "Downloading file"
   cDir := "x:\import\frepple\"
   aFiles := {"manufacturingorder.csv"}
   FOR nX := 1 TO Len(aFiles)
      ? Space(5),aFiles[nX]
      cData := oFrepple:DownloadFromFolder(aFiles[nX])
      //Alert(cData)
      IF ! MemoWrit(cDir+aFiles[nX],cData)
         ?? " failed"
         UnLockEntity("PPLUP",0)
         RETURN .F.
      ELSE
         ?? " OK"
      ENDIF
   NEXT

   /*? "Deleting tempory calendar buckets file. "
   IF FErase(Path("export\frepple\calendar buckets.csv")) == 0
      ?? "done"
   ELSE
      ?? "failed"
      IF ! GetConfigValue("BATCHMODE")
         Tr_MsgBox("Could not delete temporary calendar buckets file")
      ENDIF
   ENDIF*/
   
   
   IF ! GetConfigValue("BATCHMODE")
      Alert("done")
   ENDIF

   

   //curl_easy_setopt(pCurl, HB_CURLOPT_POSTFIELDS, BuildPostMessage({"symbol"=>Trim(IF(!Empty(cArtLief),cArtLief,cMatch)),"brutto"=>"","similars"=>{20523,188368,81144,92165,92145} }))
   UnLockEntity("PPLUP",0)


RETURN .T.

#include 'x:\run\timebutler_sync.prg'