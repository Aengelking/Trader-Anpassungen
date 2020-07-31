cFile := getenv("TEMP")+"\tnt_"+LTrim(Str(Tr_Getini(28)))+".html"
SET PRINTER TO (cFile)
SET PRINTER ON
//SET CONSOLE OFF
? "<HTML><HEAD></HEAD>"
? '<h1>Verbindung zu TNT wird hergestellt...</h1>'
? '<BODY BGCOLOR="#EEEEEE" onload="send()">'
? '<FORM id="_form" method="get" action ="http:/'+'/www.tnt.de/servlet/Tracking">'

? '<input type="hidden" value="de" name="respCountry"/>'
? '<input type="hidden" value="de" name="respLang"/>'
? '<input type="hidden" value="1" name="navigation"/>'
? '<input type="hidden" value="1" name="page"/>'
? '<input type="hidden" value="1" name="sourceID"/>'
? '<input type="hidden" value="ww" name="sourceCountry"/>'
? '<input type="hidden" value="" name="plazaKey"/>'
? '<input type="hidden" value="" name="refs"/>'
? '<input type="hidden" value="GEN" name="requesttype"/>'
? '<input type="hidden" name="genericSiteIdent" value=""/>'
? '<input id="rdoConsignment" type="hidden" value="CON" name="searchType"/>'
? '<input id="cons" class="textbox" type="hidden" title="Track" name="cons" value="'+mcBoxNumber+'"/>'

/*? '<INPUT type="hidden" size=35 name="InquiryNumber1" value="1Z774887'+mcBoxNumber+'"><BR>'
//? '<INPUT type="button" name="submitx" value="Track this package" onclick="send()">'
? '<INPUT type="hidden" name="UPS_HTML_License" value="7C24DC5788A0F734">'
? '<INPUT type="hidden" name="IATA" value ="de">'
? '<INPUT type="hidden" name="Lang" value ="ger">'
? '<INPUT type="hidden" name="UPS_HTML_Version" value="3.0">'
? '<INPUT type="hidden" name="TypeOfInquiryNumber" value="T">'
? '</FORM>'
? '</HTML>'
*/

? "<script>function send() { document.getElementById('_form').submit() }</script>"
SET PRINTER OFF
SET CONSOLE ON
SET PRINTER TO
//RUN(cFile)
#ifdef __XHARBOUR__
ShellExecute(NIL,"open",cFile,"","")
#else
Wapi_ShellExecute(NIL,"open",cFile,"","")
#endif