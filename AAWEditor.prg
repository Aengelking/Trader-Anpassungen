#define HB_CALL_FUNC_DIRECT      1     // e.g. hb_memoread( "text.txt" )               --> &'hb_memoread("text.txt")'
#define AAW_PATH "V:\Engelking Elektronik GmbH\Prozessdokumentation\Arbeitsanweisungen\"
#define LOCAL_CACHE_PATH "Y:\Technik\Prozessdoku\Arbeitsanweisungen\"
THREAD STATIC nAWNr
STATIC pMutex

PROC RUN_AAWEditor(nNr)
  //LOCAL nW
   IF ValType(nNr) != "N"
      Alert("UngÅlitge Arbeitsanweisung Nummer")
      RETURN
   ENDIF

   

   BEGIN SEQUENCE
      hb_threadStart({|nNr|         
         
         LOCAL cError
         MEMVAR nW
         PUBLIC nW         

         HB_gtSelect(HB_GTCREATE("gtcgi"))  //this avoids any problems with things being displayed on the screen
         nW := hb_webview_create(.T.)

         ErrorBlock({|oError| 
            LOCAL cError := ErrorMessage(oError)
            hb_webview_eval(nW, 'window.alert("'+cError+'")')    
            RETURN .T.        
         })         

         IF LETO_Connect(getConfigValue("leto_server"),HB_UserName()) < 0 
            hb_webview_eval(nW, 'window.alert("Could not connect to Leto server")')   
            hb_webview_run(nW)    
            hb_webview_destroy(nW)     
            RETURN .T.
         ENDIF
         IF ! LockEntity("AW",nNr,@cError,.F.)      
            hb_webview_eval(nW, 'window.alert("'+cError+'")')
            hb_webview_run(nW)
            hb_webview_destroy(nW)
            RETURN .T.
         ENDIF
         
         LoadPrg(Path("run\AAWEditor.prg")) //make sure the functions are available in this thread
         nAwNR := nNr
         hb_webview_set_title(nW,"Arbeitsanweisung Nr. "+LTrim(Str(nAWNr)))   
         //RUN_AAWEDitor_SetAWNr(nNr)
         hb_webview_bind2(nW,"aawEditorLoad",HB_CALL_FUNC_DIRECT)
         hb_webview_bind2(nW,"aawEditorSave",HB_CALL_FUNC_DIRECT)
         hb_webview_bind2(nW,"aawEditorCopy",HB_CALL_FUNC_DIRECT)
         hb_webview_navigate(nW,"file:///"+Path("www/AAWEditor/editor.html"))
         hb_webview_run(nW)
         UnLockEntity("AW",nNr)

         hb_webview_destroy(nW)
         RETURN .T.
      },nNr)
   RECOVER      
   ENDSEQUENCE

RETURN

FUNC RUN_AAWEDITOR_SetAWNr(nAWnr2)
   nAWNR := nAWnr2   
RETURN .T.

FUNC aawEditorLoad()
   LOCAL hReturn
   LOCAL cFileName

   MEMVAR nW
   
   cFileName := AAW_PATH+LTrim(Str(nAWNr))+".json"
   
   IF File(cFileName)
      hb_webview_eval(nW, 'console.log("Loading: '+StrTran(cFileName,"\","\\")+'")')
      hReturn := HB_JsonDecode(fileStr(cFileName))
      IF ValType(hReturn) != "H"
         hReturn := { "success" => .F., "error" => "Invalid file format" }
      ELSE
         hReturn := { "success" => .T., "data" => hReturn }
      ENDIF
   ELSE
      hReturn := { "success" => .F., "error" => "File not found" }
   ENDIF

RETURN hReturn

FUNC aawEditorSave(hData)
   LOCAL cFileName
   LOCAL lSuccess := .T., cError := "" 

   IF ValType(hData) == "H" .AND. HHAsKey(hData,"sections")
      cFileName := AAW_PATH+LTrim(Str(nAWnr))+".json"
      lSuccess := .F.
      cError := "Error saving file "+cFileName
      IF ! MemoWrit( cFileName, HB_JsonEncode(hData), .T. )
         lSuccess := .F.
         cError := "Error saving file "+cFileName
      ELSE
         //also save the locally cached file
         cFileName := LOCAL_CACHE_PATH+"\"+LTrim(Str(nAWnr))+".json"
         IF ! MemoWrit( cFileName,HB_JsonEncode(hData), .T.)
            lSuccess := .F.
            cError := "Error saving local cache file "+cFileName
         ELSE
            //verify by reading it back
            /*IF HB_JsonDecode(StrFile(cFileName)) != hData
               lSuccess := .F.
               cError := "Verification error saving file "+cFileName
            ENDIF*/
         ENDIF
      ENDIF

      
   ELSE
      lSuccess := .F.
      cError := "Invalid data"
   ENDIF

RETURN { "success" => lSuccess, "error" => cError }

FUNC aawEditorCopy()
   LOCAL nNewNr := 0
   LOCAL cError := ""
   LOCAL hSourceData
   LOCAL cSourceFile
   LOCAL cNewFile
   LOCAL aEnv := SaveEnv()
   LOCAL cNewDesc := ""
   LOCAL hNewData
   
   // Load source data
   cSourceFile := AAW_PATH+LTrim(Str(nAWnr))+".json"
   IF ! File(cSourceFile)
      RETURN { "success" => .F., "error" => "Source file not found" }
   ENDIF
   
   hSourceData := HB_JsonDecode(fileStr(cSourceFile))
   IF ValType(hSourceData) != "H"
      RETURN { "success" => .F., "error" => "Invalid source file format" }
   ENDIF
   
   // Get next AW number
   NetUse("aw","aw",.F.,0)
   aw->(dbGoBottom())
   nNewNr := aw->Nummer + 1
   
   IF aw->(Eof()) .AND. aw->(Bof())
      nNewNr := 1 // First record
   ENDIF
   
   // Create new database record
   aw->(dbAppend())
   IF NetErr()
      RestEnv(aEnv,.F.)
      RETURN { "success" => .F., "error" => "Could not create new database record" }
   ENDIF
   
   aw->(Rec_Lock(0))
   aw->Nummer := nNewNr
   aw->Datum := Date()
   
   // Get description from source data
   IF HHasKey(hSourceData,"title")
      cNewDesc := AllTrim(hSourceData["title"]) + " (Kopie)"
   ELSE
      cNewDesc := "Arbeitsanweisung (Kopie)"
   ENDIF
   
   aw->Beschreibu := cNewDesc
   aw->Genehmig := .F.
   aw->Veraltet := .F.
   aw->Kommentar := ""
   aw->(dbUnlock())
   
   RestEnv(aEnv,.F.)
   
   // Prepare new data with reset revision info
   hNewData := hb_hClone(hSourceData)
   hNewData["title"] := cNewDesc
   hNewData["revision"] := "1.0"
   hNewData["revisionHistory"] := {}
   
   // Save JSON files for the new work order
   cNewFile := AAW_PATH+LTrim(Str(nNewNr))+".json"
   IF ! MemoWrit( cNewFile, HB_JsonEncode(hNewData), .T. )
      RETURN { "success" => .F., "error" => "Could not save new file: "+cNewFile }
   ENDIF
   
   // Also save to local cache
   cNewFile := LOCAL_CACHE_PATH+LTrim(Str(nNewNr))+".json"
   IF ! MemoWrit( cNewFile, HB_JsonEncode(hNewData), .T. )
      RETURN { "success" => .F., "error" => "Could not save local cache file: "+cNewFile }
   ENDIF
   
   // Launch new editor with new number
   MBaseRun(Path("run\AAWEditor"),{nNewNr})
   
RETURN { "success" => .T., "newNumber" => nNewNr }