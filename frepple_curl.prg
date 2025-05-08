#include 'y:\hb34\contrib\hbcurl\hbcurl.ch'
//#include 'hbcurl.ch'
#include 'hbclass.ch'

FUNCTION RUN_FREPPLE_CURL
   LOCAL cCmd,cDir,aFiles,nX,nProc,cLine,cData,nBytes,nStdOut
   LOCAL aBucket,aBuckets := {}
   LOCAL oFrepple
   LOCAL aOldBuckets ,aOldBucket        

   oFrepple := GetFreppleApi()  

   Head("Update frePPLe")

   //? "Deleting calendar buckets "
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

   ? "Clear existing data. "
   IF ! oFrepple:waitEndOfTask(oFrepple:Empty(),Row(),Col())
      IF ! GetConfigValue("BATCHMODE") 
         Tr_MsgBox("failed")
      ENDIF
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
      RETURN .F.
   ENDIF
   DO WHILE HB_ProcessValue(nProc,.F.) == -1
      cLine := Space( 1000 )
      nBytes := Fread( nStdOUT, @cLine, Len(cLine) )
      cData += SubStr(cLine,1,nBytes)
   ENDDO
   ? " ",StrTran(StrTran(StrTran(cData,"<strong>",""),"</strong>",""),"<br>",Chr(13)+Chr(10)+"  ")
   
   ? "Importing data. "
   IF ! oFrepple:waitEndOfTask(oFrepple:ImportFromFolder(),Row(),Col())  
      IF ! GetConfigValue("BATCHMODE") 
         Tr_MsgBox("failed")
      ENDIF
      RETURN .F.    
   ENDIF

   ? "Executing plan. "
   DO WHILE ! oFrepple:waitEndOfTask(oFrepple:RunPlan(),Row(),Col())
      IF GetConfigValue("BATCHMODE") .OR. Tr_MsgBox("Executing plan failed",,{"try again","cancel"}) != 1
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
         RETURN .F.
      ELSE
         ?? " OK"
      ENDIF
   NEXT
   
   IF ! GetConfigValue("BATCHMODE")
      Alert("done")
   ENDIF

   

   //curl_easy_setopt(pCurl, HB_CURLOPT_POSTFIELDS, BuildPostMessage({"symbol"=>Trim(IF(!Empty(cArtLief),cArtLief,cMatch)),"brutto"=>"","similars"=>{20523,188368,81144,92165,92145} }))
   


RETURN .T.

FUNCTION GetFreppleApi()
   LOCAL cBaseUrl := "https://engelking.frepple.com/"
   LOCAL cUser := "API"
   LOCAL cPW   := "zDiHTeiN54HyrPE"
   LOCAL cScenario := GetValue("FREPPLE_SCENARIO","scenario2","Scenarion to upload to")
   LOCAL oFrepple := FreppleApi():New(cBaseUrl,cUser,cPW,cScenario)

   oFrepple:nTimeout := GetValue("FREPPLE_UPLOAD_TIMEOUT",240,"Cancel task after x seconds")
RETURN oFrepple

   CLASS FreppleApi
      METHOD New
         
      METHOD runPlan
      METHOD Empty
      METHOD DeleteUploads
      METHOD UploadToFolder
      METHOD taskStatus
      METHOD ImportFromFolder
      METHOD ExportToFolder
      METHOD DownloadFromFolder
      METHOD waitEndOfTask
         //methods based on the REST API
      METHOD getCalendarBuckets
      METHOD deleteCalendarBucket
      METHOD getManufacturingOrders
      METHOD patchManufacturingOrder

      DATA nTimeout INIT 240 //Timeout in seconds
      

      //HIDDEN:
      DATA pCurl
      DATA cBaseUrl
      DATA cScenario INIT ""
      DATA cScenarioUrl INIT ""
      DATA cUser
      DATA cPW

      METHOD Execute
   ENDCLASS

   METHOD New(cBaseUrl,cUser,cPW,cScenario)
      ::cBaseUrl := cBaseUrl
      ::cUser := cUser
      ::cPW := cPW
      ::cScenario := cScenario
      IF Upper(::cScenario) != "DEFAULT" .OR. Empty(::cScenario)
         ::cScenarioUrl := ::cScenario+"/"
      ELSE
         ::cScenarioUrl := ""
      ENDIF

      /*::pCurl := Curl_Easy_Init()

      curl_easy_setopt(::pCurl, HB_CURLOPT_SSL_VERIFYPEER,0)
      curl_easy_setopt(::pCurl, HB_CURLOPT_USERNAME, cUser )
      curl_easy_setopt(::pCurl, HB_CURLOPT_PASSWORD, cPW )
      curl_easy_setopt(::pCurl, HB_CURLOPT_POST, 1)
      curl_easy_setopt(::pCurl, HB_CURLOPT_DL_BUFF_SETUP )*/
   RETURN self

   METHOD RunPlan
   RETURN ::Execute(::cScenarioUrl+"/execute/api/runplan/?constraint=13&plantype=1&env=supply")["taskid"]

   METHOD Empty()
      LOCAL cUrl := ::cScenarioUrl+"/execute/api/empty/?models="
      LOCAL aModels := {}
      
      Aadd(aModels,"input.demand") //Sales - Sales orders
      Aadd(aModels,"input.deliveryorder") //Sales - delivery orders
      Aadd(aModels,"forecast.forecast") //Sales - Forecast
      Aadd(aModels,"input.operationplanmaterial") //Inventory - Inventory detail
      Aadd(aModels,"input.operationplanresource") //Capacity - Resource detail
      Aadd(aModels,"input.operationdependency") //
      Aadd(aModels,"input.purchaseorder") //Purchasing - Purchase orders
      Aadd(aModels,"input.manufacturingorder") //Manufacturing - Manufacturing orders
      Aadd(aModels,"input.itemsupplier") //Purchasing - Item suppliers
      Aadd(aModels,"input.itemdistribution")  //Inventory - Item distributions
      Aadd(aModels,"input.operationmaterial")  //Manufacturing - Operation Material
      Aadd(aModels,"input.operationresource") //Manufacturing - Operation resources
      Aadd(aModels,"input.suboperation") //Manufacturing - Suboperation
      Aadd(aModels,"input.operation") //Manufacturing - Operations
      Aadd(aModels,"input.buffer") //Inventory - Buffers
      Aadd(aModels,"input.calendarbucket")
      

      AEval(aModels,{|x,n| cUrl += IF(n>1,",","")+x })

      
   RETURN ::Execute(cUrl)["taskid"]

   METHOD DeleteUploads
   RETURN ::Execute("execute/deletefromfolder/0/AllFiles/","DELETE",,.F.) == "OK"

   METHOD UploadToFolder(hFiles)
   RETURN ::Execute("execute/uploadtofolder/0/",,hFiles,.F.)         

   METHOD ImportFromFolder
   RETURN ::Execute(::cScenarioUrl+"/execute/api/importfromfolder/")["taskid"]

   METHOD ExportToFolder
   RETURN ::Execute(::cScenarioUrl+"/execute/api/exporttofolder/")["taskid"]

   METHOD DownloadFromFolder(cFile)
   RETURN ::Execute("execute/downloadfromfolder/1/"+cFile+"/","GET",,.F.)

   METHOD waitEndOfTask(nTaskid,nRow,nCol)
      LOCAL cStatus
      LOCAL nTime      
      LOCAL lOut := Valtype(nRow) == "N" .AND. ValType(nCol) == "N"
      
      FOR nTime := 0 TO ::nTimeout STEP 5
         cStatus := ::taskStatus(nTaskId)
         IF lOut
            @ nRow,nCol SAY Space(15)
            @ nRow,nCol SAY cStatus
         ENDIF
         IF cStatus == "Done" .OR. cStatus == "100%"
            RETURN .T.
         ELSEIF cStatus == "Failed" .OR. cStatus == "Canceled"
            RETURN .F.
         ENDIF
         //HB_IdleSleep(5)
         Inkey(5,128)
      NEXT
      //Timeout reached, we attempt to cancel the task
      //::cancelTask(nTaskid)

   RETURN .F.

   

   METHOD taskStatus(nTaskId)
      LOCAL cUrl := ::cScenarioUrl+"/execute/api/status/?id="+LTrim(Str(nTaskid))
      LOCAL cStatus := ::Execute(cUrl)[LTrim(Str(nTaskId))]["status"]
      
   RETURN cStatus

   METHOD getCalendarBuckets()
   RETURN HB_JSonDecode(::Execute(::cScenarioUrl+"api/input/calendarbucket/","GET",,.F.))

   METHOD deleteCalendarBucket(nId)
   RETURN ::Execute(::cScenarioUrl+"api/input/calendarbucket/"+LTrim(Str(nId))+"/","DELETE",,.F.)

   METHOD getManufacturingOrders()
   RETURN HB_JSonDecode(::Execute(::cScenarioUrl+"api/input/manufacturingorder/","GET",,.F.))

   METHOD patchManufacturingOrder(cId,hData)
   //RETURN HB_JSonDecode(::Execute(::cScenarioUrl+"api/input/manufacturingorder/"+cId+"/","PATCH",hData,.F.))
RETURN ::Execute(::cScenarioUrl+"api/input/manufacturingorder/"+cId+"/","PATCH",hData,.F.)


   METHOD Execute(cUrl,cMethod,hData,lJson)
      LOCAL cData
      LOCAL aReturn
      LOCAL cPostData
      LOCAL oErr
      

      Default(@cMethod,"POST")
      Default(@lJson,.T.)

      ::pCurl := Curl_Easy_Init()

      curl_easy_setopt(::pCurl, HB_CURLOPT_SSL_VERIFYPEER,0)
      curl_easy_setopt(::pCurl, HB_CURLOPT_USERNAME, ::cUser )
      curl_easy_setopt(::pCurl, HB_CURLOPT_PASSWORD, ::cPW )
      IF cMethod == "POST" 
         curl_easy_setopt(::pCurl, HB_CURLOPT_POST, 1)
      ELSEIF cMethod != "GET"
         curl_easy_setopt(::pCurl, HB_CURLOPT_CUSTOMREQUEST, cMethod)  
         curl_easy_setopt(::pCurl, HB_CURLOPT_HTTPHEADER, {"Content-Type: application/json"})       
      ENDIF
      curl_easy_setopt(::pCurl, HB_CURLOPT_DL_BUFF_SETUP )
      curl_easy_setopt(::pCurl, HB_CURLOPT_URL, ::cBaseUrl+cUrl )

      /*IF ValType(hFiles) == "H"
         //curl_easy_setopt(::pCurl, HB_CURLOPT_HTTPHEADER, {'Content-Type: multipart/form-data;boundary="boundary"'})
         FOR EACH cFileData IN hFiles
            
         NEXT
      ENDIF*/
      IF ! Empty(hData)
         cPostData := HB_JsonEncode(hData)                       
         curl_easy_setopt(::pCurl, HB_CURLOPT_POSTFIELDS, cPostData)         
      ENDIF
      
          
      //nErr := 
      //Curl_Easy_Perform(::pCurl)
      /*IF ! Empty(cPostData) .AND. cMethod != "POST"
         curl_easy_setopt( ::pCurl, HB_CURLOPT_CONNECT_ONLY, .T. )
         Curl_Easy_Perform(::pCurl)
         
         Str(curl_easy_send(::pCurl,cPostData,@nSent))
         IF nSent < Len(cPostData)
            Alert("ERROR Sending data")
         ENDIF
         curl_easy_recv(::pCurl,@cData)
         //Alert(cError)
      ELSE*/
         Curl_Easy_Perform(::pCurl)
         curl_easy_setopt( ::pCurl, HB_CURLOPT_DL_BUFF_GET, @cData )
      //ENDIF
      
      
      /*
      Alert(::cBaseUrl+cUrl)
      Alert( "Curl: "+Str(nErr) )
      Alert( "HTTP Response: "+Str(curl_easy_getinfo(::pCurl,HB_CURLINFO_RESPONSE_CODE)) )
      Alert( cData )*/

      
      Curl_Easy_CleanUp(::pCurl)

      IF ! lJson
         RETURN cData
      ENDIF

      aReturn := HB_JSonDecode(cData)      
      IF Empty(aReturn) .OR. Len(aReturn) == 0
         oErr := ErrorNew()
         oErr:SubSystem   := "frePPLe-API"
         oErr:Description := "Error executing command."
         oErr:Args        := {cUrl,cData}
         Throw(oErr)   
      ELSEIF ! HHasKey(aReturn,"taskid") .AND. HHasKey(aReturn,"message")
         oErr := ErrorNew()
         oErr:SubSystem   := "frePPLe-API"
         oErr:Description := aReturn["message"]
         oErr:Args        := {cUrl,cData}
         Throw(oErr)
      ENDIF
   RETURN aReturn

   FUNCTION Frep_StoT(cDate)
      IF Empty(cDate)
         RETURN STOT("")
      ENDIF
   RETURN StoT(StrTran(StrTran(StrTran(StrTran(cDate,"-",""),":","")," ",""),"T",""))
