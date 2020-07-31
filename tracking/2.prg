
/*cFile := getenv("TEMP")+"\ups_"+LTrim(Str(Tr_Getini(28)))+".html"
SET PRINTER TO (cFile)
SET PRINTER ON
SET CONSOLE OFF
? "<HTML><HEAD></HEAD>"
? '<h1>Verbindung zu UPS wird hergestellt...</h1>'
? '<BODY BGCOLOR="#EEEEEE" onload="send()">'
? '<FORM id="_form" method="post" action ="http:/'+'/wwwapps.ups.com/WebTracking/OnlineTool">'
? '<INPUT type="hidden" size=35 name="InquiryNumber1" value="'+If(At("1Z",mcBoxNumber)==0,'1Z774887','')+mcBoxNumber+'"><BR>'
//? '<INPUT type="button" name="submitx" value="Track this package" onclick="send()">'
? '<INPUT type="hidden" name="UPS_HTML_License" value="7C24DC5788A0F734">'
? '<INPUT type="hidden" name="IATA" value ="de">'
? '<INPUT type="hidden" name="Lang" value ="ger">'
? '<INPUT type="hidden" name="UPS_HTML_Version" value="3.0">'
? '<INPUT type="hidden" name="TypeOfInquiryNumber" value="T">'
? '</FORM>'
? '</HTML>'

? "<script>function send() { document.getElementById('_form').submit() }</script>"
SET PRINTER OFF
SET CONSOLE ON
SET PRINTER TO*/
//RUN(cFile)
cFile := "https://www.ups.com/WebTracking/track?trackNums="+Trim(If(At("1Z",mcBoxNumber)==0,'1Z774887','')+mcBoxNumber)+"&loc=de_de"

Wapi_ShellExecute(NIL,"open",cFile,"","")
