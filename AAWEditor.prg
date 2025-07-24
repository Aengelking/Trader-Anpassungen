#define HB_CALL_FUNC_DIRECT      1     // e.g. hb_memoread( "text.txt" )               --> &'hb_memoread("text.txt")'
#define AAW_PATH "V:\Engelking Elektronik GmbH\Prozessdokumentation\Arbeitsanweisungen\"
#define LOCAL_CACHE_PATH "Y:\Technik\Prozessdoku\Arbeitsanweisungen\"
THREAD STATIC nAWNr
STATIC pMutex
PROC RUN_AAWEditor(nNr)
  LOCAL nW
   IF ValType(nNr) != "N"
      Alert("UngÅlitge Arbeitsanweisung Nummer")
      RETURN
   ENDIF

   

   BEGIN SEQUENCE
      hb_threadStart({|nNr|         
         
         LOCAL cError
         HB_gtSelect(HB_GTCREATE("gtcgi"))  //this avoids any problems with things being displayed on the screen
         nW := hb_webview_create(.T.)

         ErrorBlock({|oError| 
            LOCAL cError := ErrorMessage(oError)
            hb_webview_eval(nW, 'window.alert("'+cError+'")')            
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
         hb_webview_navigate(nW,"file:///"+Path("www/AAWEditor/editor.html"))
         hb_webview_run(nW)
         UnLockEntity("AW",nNr)

         hb_webview_destroy(nW)
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
   
   cFileName := AAW_PATH+LTrim(Str(nAWNr))+".json"
   
   IF File(cFileName)
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
      IF ! MemoWrit( cFileName, HB_JsonEncode(hData) )
         lSuccess := .F.
         cError := "Error saving file "+cFileName
      ELSE
         //also save the locally cached file
         cFileName := LOCAL_CACHE_PATH+"\"+LTrim(Str(nAWnr))+".json"
         IF ! MemoWrit( cFileName, HB_JsonEncode(hData) )
            lSuccess := .F.
            cError := "Error saving local cache file "+cFileName
         ENDIF
      ENDIF
   ELSE
      lSuccess := .F.
      cError := "Invalid data"
   ENDIF

RETURN { "success" => lSuccess, "error" => cError }