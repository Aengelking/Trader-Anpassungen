#include 'y:\hb34\contrib\hbcurl\hbcurl.ch'
//#include 'hbcurl.ch'
#include 'hbclass.ch'

FUNCTION RUN_FREPPLE_CURL
   LOCAL cCmd,cDir,aFiles,nX,nProc,cLine,cData,nBytes,nStdOut,nStdErr
   LOCAL aBucket,aBuckets := {}
   LOCAL oFrepple
   LOCAL aOldBuckets ,aOldBucket        
   LOCAL cScreen,aOpPlan
   LOCAL nSecs,oErr

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
               "operation resource.csv","resource.csv","calendar.csv","calendar buckets.csv","calendar bucket.csv","resource detail.csv","resourceskill.csv","skill.csv"}

   FOR nX := 1 TO Len(aFiles)
      cCmd += ' -F "'+aFiles[nX]+"=@"+cDir+aFiles[nX]+'"'
   NEXT
   cCmd += ' "'+oFrepple:cBaseUrl+oFrepple:cScenarioUrl+'execute/uploadtofolder/0/"'
   //? cCmd
   cData := ""
   nProc := HB_OpenProcess(cCmd,,@nStdOut,@nStdErr,.T.)
   IF nProc <= 0
      Alert("Failed to start process.;"+cCmd)
      UnLockEntity("PPLUP",0)
      RETURN .F.
   ENDIF
   nSecs := Seconds()
   ? " "
   DO WHILE HB_ProcessValue(nProc,.F.) == -1      
      cLine := Space( 1000 )
      nBytes := Fread( nStdOUT, @cLine, Len(cLine) )
      ?? StrTran(StrTran(StrTran(cLine,"<strong>",""),"</strong>",""),"<br>",Chr(13)+Chr(10)+"  ")
      
      cLine := Space( 1000 )
      nBytes := Fread( nStdERR, @cLine, Len(cLine) )
      cData += SubStr(cLine,1,nBytes)
      
      IF Seconds() - nSecs > 30 //timeout after 30 seconds
         HB_CloseProcess(nProc)
         oErr := ErrorNew()
         oErr:SubSystem   := "frePPLe-Upload"
         oErr:Description := "Upload process timed out"+Chr(13)+Chr(10)+"StdErr:"+cData
         oErr:Args        := {}
         Throw(oErr)          
      ENDIF
   ENDDO
   HB_CloseProcess(nProc)
   //? " ",StrTran(StrTran(StrTran(cData,"<strong>",""),"</strong>",""),"<br>",Chr(13)+Chr(10)+"  ")
   
   ? "Syncing absences to frePPLe "
   cScreen := SaveScreen()
   nRow := Row()
   nCol := Col()
   Run_TimeButler(.F.,.F.,.T.,.F.) //re-sync timebutler calendars with frepple
   RestScreen(,,,,cScreen)
   SetPos(nRow,nCol)
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


   ? "Executing plan. "
   DO WHILE ! oFrepple:waitEndOfTask(oFrepple:RunPlan(),Row(),Col())
      IF GetConfigValue("BATCHMODE") .OR. Tr_MsgBox("Executing plan failed",,{"try again","cancel"}) != 1
         UnLockEntity("PPLUP",0)
         RETURN .F.         
      ENDIF
   ENDDO


   ? "Update time of current tasks "
   rst->(dbSetOrder( 6 ))
   wat->(dbSetOrder( 4 ))
   job->(dbSetOrder( 1 ))
   aOpPlan := {}
   Select("wer")
   SET FILTER TO Empty(wer->Liefma) .AND. wer->Status == 3 .AND. wer->Qty-wer->PlanBad > 0 .AND. Right(Str(wer->TerminFrue,4),2) != "99"
   wer->(dbGoTop())
   DO WHILE ! wer->(EOF())             
      IF rst->(dbSeek( "WA "+Str(wer->Aufno,6) )) 
        DO WHILE rst->No == wer->Aufno .AND. Trim(rst->Type) == "WA" .AND. rst->Complete .AND. ! rst->(EOF())  //look for first uncompleted entry in restime            
            rst->(dbSkip())
         ENDDO
         IF rst->No == wer->Aufno .AND. Trim(rst->Type) == "WA" .AND. wat->(dbSeek( Str(wer->Aufno,6)+Str(rst->Job,6) )) .AND. ! Empty(wat->Start)
            
            job->(dbSeek( Str(rst->Job) ))

            cTime := SubStr(wat->Start,9,6)

            cSec  := Right ( cTime, 2 )
            cMin  := SubStr( cTime, 3, 2 )
            cHour := Left  ( cTime, 2 )

            nSecs := TimeToSec(cHour+":"+cMin+":"+cSec) //Val( cHour ) * 3600 + Val( cMin ) * 60 + Val( cSec )
            nSecs += 10 //add one second to retrigger the planning

            //? cHour+":"+cMin+":"+cSec,nSecs,SecToTime(nSecs)

            cDateTime := SubStr(wat->Start,1,4)+"-"+SubStr(wat->Start,5,2)+"-"+SubStr(wat->Start,7,2)+" "+SecToTime(nSecs) //add one second to retrigger the planning
            
            ? "FA"+LTrim(Str(wer->Aufno))+"-"+Trim(job->Name),rst->No, " ", rst->Type, " ", wat->Start, " ", cDateTime
            Aadd(aOpPlan,{"id"=>"FA"+LTrim(Str(wer->Aufno))+"-"+Trim(job->Name),"startdate"=>cDateTime})
            rst->(dbSkip())
         ENDIF
      ENDIF
      wer->(dbSkip())
   ENDDO
   IF Len(aOpPlan) == 0
      ?? "no updates needed"
   ELSE
      ? ValToPrg(oFrepple:updateOperationPlan(aOpPlan))
   ENDIF
   ?? "done"
   
   wer->(dbClearFilter())

   ? "Executing plan second time. "
   DO WHILE ! oFrepple:waitEndOfTask(oFrepple:RunPlan(),Row(),Col())
      IF GetConfigValue("BATCHMODE") .OR. Tr_MsgBox("Executing plan failed",,{"try again","cancel"}) != 1
         UnLockEntity("PPLUP",0)
         RETURN .F.         
      ENDIF
   ENDDO
   ?? "done"   
   

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