#define HB_CALL_FUNC_DIRECT      1
THREAD STATIC nAWNr
THREAD STATIC nW
STATIC pMutex
PROC RUN_WEP()
  //LOCAL nW
  LOCAL nNr := 0 //dummy parameter to match function signature

   BEGIN SEQUENCE
      hb_threadStart({|nNr|         
         
         LOCAL cError
         HB_gtSelect(HB_GTCREATE("gtcgi"))  //this avoids any problems with things being displayed on the screen
         nW := hb_webview_create(.T.)

         /*ErrorBlock({|oError| 
            LOCAL cError := ErrorMessage(oError)
            hb_webview_eval(nW, 'window.alert("'+cError+'")')            
         })*/

         IF LETO_Connect(getConfigValue("leto_server"),HB_UserName()) < 0 
            hb_webview_eval(nW, 'window.alert("Could not connect to Leto server")')   
            hb_webview_run(nW)    
            hb_webview_destroy(nW)     
            RETURN .T.
         ENDIF
         
         LoadPrg(Path("run\wep.prg")) //make sure the functions are available in this thread
         nAwNR := nNr
         hb_webview_set_title(nW,"Wareneingangsprfung") // Nr. "+LTrim(Str(nAWNr)))   
         hb_webview_bind2(nW,"saveRefreshTokenToTrader",HB_CALL_FUNC_DIRECT)
         //hb_webview_bind2(nW,"aawEditorSave",HB_CALL_FUNC_DIRECT)
//tip_URLEncode(cMessage)

         //Die Pruefungen legt inzwischen der Wareneingang selbst an (Hook
         //GET_WE_QM_NUMBER / AFTER_BOOK_WE -> run\qm_we_register). Deshalb
         //oeffnet dieser Aufruf die LISTE der Pruefungen und nicht mehr die
         //Neuanlage mit einem fest verdrahteten Artikel.
         cUrl := "https://preview--engelking-qm.lovable.app/auth/token"
         cUrl += "?token="+Trim(SystemUser():oSettings:QmRefresh)
         cUrl += "&redirect=/wareneingangspruefungen"

         hb_webview_navigate(nW,cUrl)
         hb_webview_run(nW)

         hb_webview_destroy(nW)
         RETURN NIL
      },nNr)
   RECOVER      
   ENDSEQUENCE

RETURN

FUNC saveRefreshTokenToTrader(cEmail,cRefreshToken)
   LOCAL oExtra
   //hb_webview_eval(nW, 'console.log("saveToken")')   
   //hb_webview_eval(nW, 'console.log("'+cUserID+'")')   
   NetUse("buyer","buy")
   buy->(dbSetOrder(4))
   IF buy->(dbSeek(cEmail))
      oExtra := buy->(ExtraData():New(buy->(Recno())))
      oExtra:QmRefresh := cRefreshToken
      oExtra:Save()
   ELSE
      MemoWrit(GetEnv("temp")+"\user.txt","USER NOT FOUND")
   ENDIF
   //MemoWrit(GetEnv("temp")+"\user.txt",cRefreshToken)
RETURN .T.