
#define HB_CALL_FUNC_DIRECT      1

PROC RUN_REPortER_webview
   LOCAL nW := hb_webview_create(.T.)
   LOCAL cJS
   //hb_webview_set_title(nW,"Arbeitsanweisung Nr. "+LTrim(Str(nAWNr)))   
         
   /*hb_webview_bind2(nW,"aawEditorLoad",HB_CALL_FUNC_DIRECT)
   hb_webview_bind2(nW,"aawEditorSave",HB_CALL_FUNC_DIRECT)
   hb_webview_bind2(nW,"aawEditorCopy",HB_CALL_FUNC_DIRECT)*/

   cJS := MemoRead(Path("run\reporter_webview_bootstrap.js"))
   
   /*cJS += "  context: {"
   cJS += "    documentUrl: 'https://services.cp.cloud-security.net/reporter/id/5ea3cb6b401cd3981496961de53dc7/static/index.html',"
   cJS += "    user: {"
   cJS += "      displayName: '"+Trim(pusr->Name)+"',"
   cJS += "      email: '"+Trim(pusr->Email)+"'"
   cJS += "    },"
   cJS += "    mailbox: {"
   cJS += "      diagnostics: {"
   cJS += "        hostName: '"+GetHostName()+"',"
   cJS += "        ipAddress: '"+GetHostIP()+"'"
   cJS += "      }"
   cJS += "    }"
   cJS += "  },"
   cJS += "  onReady: function(callback) { callback(); },"
   cJS += "  onDocumentSelectionChanged: function(callback) { },"
   cJS += "  onDocumentStateChanged: function(callback) { },"
   cJS += "  onAppThemeChanged: function(callback) { }"
   cJS += "};"*/

   //cJS := "window.alert('Office.js is not supported in this environment, some features may not work as expected.');"
   
   hb_webview_init( nW, cJS )

   hb_webview_navigate(nW,"https://services.cp.cloud-security.net/reporter/id/5ea3cb6b401cd3981496961de53dc7/static/index.html")
   hb_webview_run(nW)
         

   hb_webview_destroy(nW)
RETURN