#include 'y:\hb34\contrib\hbcurl\hbcurl.ch'
#include 'hbclass.ch'

FUNCTION RUN_FREPPLE_CURL
   //LOCAL pCurl := Curl_Easy_Init()
   LOCAL cBaseUrl := "https://engelking.frepple.com/scenario2/execute/"
   LOCAL cUser := "API"
   LOCAL cPW   := "zDiHTeiN54HyrPE"
   LOCAL cCmd,cDir,aFiles,nX,nProc,cLine,cData,nBytes,nStdOut

   //LOCAL cScenario := "scenario2"  

   LOCAL oFrepple := FreppleApi():New(cBaseUrl,cUser,cPW)

   Head("Update frePPLe")
   
   ? "Clear existing data. "
   IF ! oFrepple:waitEndOfTask(oFrepple:Empty(),Row(),Col())
      Alert("failed")
      RETURN NIL
   ENDIF

   ? "Remove any old files. "   
   IF oFrepple:DeleteUploads()
      ?? "done"
   ELSE
      ?? "failed"
      Alert("failed")
      RETURN NIL
   ENDIF

   ? "Upload files"
   //this is easier over the cmd line
   cCmd := "C:\Curl\bin\curl -u "+cUser+":"+cPW+" -X POST -k"
   cDir := "x:\export\frepple\"
   aFiles := {"item.csv","supplier.csv","buffer.csv","customer.csv","sales order.csv","item supplier.csv","purchase order.csv","manufacturing order.csv","operation material.csv","operation.csv","item distribution.csv","operation resource.csv"}

   FOR nX := 1 TO Len(aFiles)
      cCmd += ' -F "'+aFiles[nX]+"=@"+cDir+aFiles[nX]+'"'
   NEXT
   cCmd += " "+cBaseUrl+" "+'"https://engelking.frepple.com/scenario2/execute/uploadtofolder/0/"'
   cData := ""
   nProc := HB_OpenProcess(cCmd,,@nStdOut,,.T.)
   DO WHILE HB_ProcessValue(nProc,.F.) == -1
      cLine := Space( 1000 )
      nBytes := Fread( nStdOUT, @cLine, Len(cLine) )
      cData += SubStr(cLine,1,nBytes)
   ENDDO
   ? cData 
   gtSetClipboard(cCmd)
   
   ? "Importing data. "
   IF ! oFrepple:waitEndOfTask(oFrepple:ImportFromFolder(),Row(),Col())  
      Alert("failed")
      RETURN NIL    
   ENDIF

   ? "Executing plan. "
   IF ! oFrepple:waitEndOfTask(oFrepple:RunPlan(),Row(),Col())
      Alert("failed")
      RETURN NIL
   ENDIF

   ? "Executing plan a second time (until the bug with the manufacturing orders is solved). "
   IF ! oFrepple:waitEndOfTask(oFrepple:RunPlan(),Row(),Col())
      Alert("failed")
      RETURN NIL
   ENDIF
   //oFrepple:taskStatus(544)
   //curl_mime_addpart()

   Alert("done")

   //curl_easy_setopt(pCurl, HB_CURLOPT_POSTFIELDS, BuildPostMessage({"symbol"=>Trim(IF(!Empty(cArtLief),cArtLief,cMatch)),"brutto"=>"","similars"=>{20523,188368,81144,92165,92145} }))
   


RETURN NIL

   CLASS FreppleApi
      METHOD New
      METHOD runPlan
      METHOD Empty
      METHOD DeleteUploads
      METHOD UploadToFolder
      METHOD taskStatus
      METHOD ImportFromFolder
      METHOD waitEndOfTask

      DATA nTimeout INIT 60 //Timeout in seconds
      

      HIDDEN:
      DATA pCurl
      DATA cBaseUrl
      DATA cUser
      DATA cPW

      METHOD Execute
   ENDCLASS

   METHOD New(cBaseUrl,cUser,cPW)
      ::cBaseUrl := cBaseUrl
      ::cUser := cUser
      ::cPW := cPW

      /*::pCurl := Curl_Easy_Init()

      curl_easy_setopt(::pCurl, HB_CURLOPT_SSL_VERIFYPEER,0)
      curl_easy_setopt(::pCurl, HB_CURLOPT_USERNAME, cUser )
      curl_easy_setopt(::pCurl, HB_CURLOPT_PASSWORD, cPW )
      curl_easy_setopt(::pCurl, HB_CURLOPT_POST, 1)
      curl_easy_setopt(::pCurl, HB_CURLOPT_DL_BUFF_SETUP )*/
   RETURN self

   METHOD RunPlan
   RETURN ::Execute("api/runplan/?constraint=13&plantype=1&env=supply")["taskid"]

   METHOD Empty()
      LOCAL cUrl := "api/empty/?models="
      LOCAL aModels := {}
      
      Aadd(aModels,"input.demand") //Sales - Sales orders
      Aadd(aModels,"input.deliveryorder") //Sales - delivery orders
      Aadd(aModels,"forecast.forecast") //Sales - Forecast
      Aadd(aModels,"input.operationplanmaterial") //Inventory - Inventory detail
      Aadd(aModels,"input.operationplanresource") //Capacity - Resource detail
      Aadd(aModels,"input.purchaseorder") //Purchasing - Purchase orders
      Aadd(aModels,"input.manufacturingorder") //Manufacturing - Manufacturing orders
      Aadd(aModels,"input.itemsupplier") //Purchasing - Item suppliers
      Aadd(aModels,"input.itemdistribution")  //Inventory - Item distributions
      Aadd(aModels,"input.operationmaterial")  //Manufacturing - Operation Material
      Aadd(aModels,"input.operationresource") //Manufacturing - Operation resources
      Aadd(aModels,"input.suboperation") //Manufacturing - Suboperation
      Aadd(aModels,"input.operation") //Manufacturing - Operations
      Aadd(aModels,"input.buffer") //Inventory - Buffers
      

      AEval(aModels,{|x,n| cUrl += IF(n>1,",","")+x })

   RETURN ::Execute(cUrl)["taskid"]

   METHOD DeleteUploads
   RETURN ::Execute("deletefromfolder/0/AllFiles/","DELETE",,.F.) == "OK"

   METHOD UploadToFolder(hFiles)
   RETURN ::Execute("uploadtofolder/0/",,hFiles,.F.)         

   METHOD ImportFromFolder
   RETURN ::Execute("api/importfromfolder/")["taskid"]

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
         HB_IdleSleep(5)
      NEXT

   RETURN .F.

   METHOD taskStatus(nTaskId)
      LOCAL cUrl := "api/status/?id="+LTrim(Str(nTaskid))
      LOCAL cStatus := ::Execute(cUrl)[LTrim(Str(nTaskId))]["status"]
      
   RETURN cStatus



   METHOD Execute(cUrl,cMethod,hFiles,lJson)
      LOCAL cData
      LOCAL aReturn
      LOCAL cFileData
      LOCAL oErr

      Default(@cMethod,"POST")
      Default(@lJson,.T.)

      ::pCurl := Curl_Easy_Init()

      curl_easy_setopt(::pCurl, HB_CURLOPT_SSL_VERIFYPEER,0)
      curl_easy_setopt(::pCurl, HB_CURLOPT_USERNAME, ::cUser )
      curl_easy_setopt(::pCurl, HB_CURLOPT_PASSWORD, ::cPW )
      IF cMethod == "POST"
         curl_easy_setopt(::pCurl, HB_CURLOPT_POST, 1)
      ELSEIF cMethod == "DELETE"
         curl_easy_setopt(::pCurl, HB_CURLOPT_CUSTOMREQUEST, "DELETE")
      ENDIF
      curl_easy_setopt(::pCurl, HB_CURLOPT_DL_BUFF_SETUP )
      curl_easy_setopt(::pCurl, HB_CURLOPT_URL, ::cBaseUrl+cUrl )

      IF ValType(hFiles) == "H"
         //curl_easy_setopt(::pCurl, HB_CURLOPT_HTTPHEADER, {'Content-Type: multipart/form-data;boundary="boundary"'})
         FOR EACH cFileData IN hFiles
            
         NEXT
      ENDIF
      
      
      //nErr := 
      Curl_Easy_Perform(::pCurl)
      curl_easy_setopt( ::pCurl, HB_CURLOPT_DL_BUFF_GET, @cData )
      
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
      ENDIF
   RETURN aReturn