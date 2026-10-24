cFile := getenv("TEMP")+"\tracking_noerpel_"+LTrim(Str(Tr_Getini(28)))+".html"
SET PRINTER TO (cFile)
SET PRINTER ON
? "<HTML><HEAD></HEAD>"
? '<BODY BGCOLOR="#EEEEEE">' // onload="start()">'
? '<iframe src="http://www.cim-online.de/servlet/net.systemware.cim.Cim" onload="send()"></iframe>'
? '<h1>Verbindung zu Noerpel wird hergestellt...</h1>'

//TS=082748294&amp;
? '<form id="_form" name="LoginForm" action="http://www.cim-online.de/servlet/net.systemware.cim.Cim?DESIGN=ALHI&amp;COUNTRY=DE" method="POST">'
? '<INPUT type="hidden" size=35 name="ColliNr" value="'+StrTran(StrTran(Trim(mcBoxNumber),"(",""),")","")+'"><BR>'
? '<input type="hidden" value="COLLILOGIN" name="REQUEST">'

? '</FORM>'
? '</HTML>'

? "<script>"
? 'function start() { window.setTimeout("send()",500) }'
? 'function send() { document.getElementById("_form").submit() }'
? '</script>'

SET PRINTER OFF
SET CONSOLE ON
SET PRINTER TO

#ifdef __XHARBOUR__
ShellExecute(NIL,"open",cFile,"","")
#else
Wapi_ShellExecute(NIL,"open",cFile,"","")
#endif