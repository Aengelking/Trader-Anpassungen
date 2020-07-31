cFile := "http:/"+"/nolp.dhl.de/nextt-online-public/set_identcodes.do?lang=de&idc="+mcBoxNumber+"&rfn=&extendedSearch=true"
#ifdef __XHARBOUR__
ShellExecute(NIL,"open",cFile,"","")
#else
Wapi_ShellExecute(NIL,"open",cFile,"","")
#endif