//testing cXML Punchout with Amazon
LOCAL oXML
LOCAL cPayload
LOCAL cTimestamp

LOCAL cDateFormat

cHostname := "engelking.de"
nProcessID := 1234
cTimeZone := "+01:00"
cLang := "de-DE"
cUrl := "https://www.amazon.de/eprocurement/punchout"
oHttp := TIpClientHttp():new( cUrl )
oHttp:nConnTimeout := 20000
oHttp:hFields["Content-Type"] := "text/xml; charset=utf-8"

#define HBXML_TYPE_DOCUMENT       6

cPayLoad := Left(TtoS(DateTime()),13)+"."+LTrim(Str(nProcessID))+"."+LTrim(Str(HB_RandomInt(9999)))+"@"+cHostname
cDateFormat := Set(_SET_DATEFORMAT,"yy-dd-mm")
//cTimeFormat := Set(_SET_TIMEFORMAT","hh:mm:ss.cc")
//nTimeFormat := Set(??,
cTimestamp := DtoC(Date())+"T"+Right(TtoC(DateTime()),12)+cTimeZone
Set(_SET_DATEFORMAT,cDateFormat)

oRoot := TXmlNode():New(,"cXML",{"payloadID"=>cPayLoad,"timestamp"=>cTimeStamp,"xml:lang"=>cLang})
//oRoot:AddBelow(TXmlNode():New(,"cXML",{"payloadID"=>cPayLoad}))
oXml := TXmlDocument():New(oRoot)
? '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE cXML SYSTEM "http://xml.cxml.org/schemas/cXML/1.2.014/cXML.dtd">'
? oXml:toString()
Sinkey(0)
RETURN

cRequest := ;
'<?xml version="1.0" encoding="UTF-8"?>'+;
'<!DOCTYPE cXML SYSTEM "http://xml.cxml.org/schemas/cXML/1.2.014/cXML.dtd">'+;
'<cXML>'+;
'<Header>'+;
'    <From>'+;
'        <Credential domain="NetworkId">'+;
'                <Identity>EngelkingElektronikGmbH9191951881</Identity>'+;
'        </Credential>'+;
'   </From>'+;
'    <To>'+;
'        <Credential domain="NetworkId">'+;
'            <Identity>Amazon</Identity>'+;
'        </Credential>'+;
'    </To>'+;
'    <Sender>'+;
'        <Credential domain="NetworkId">'+;
'            <Identity>EngelkingElektronikGmbH9191951881</Identity>'+;
'            <SharedSecret>sO0rGXO1LvXtFhcCXEDNn6oUUgS5d9</SharedSecret>'+;
'        </Credential>'+;
'        <UserAgent>YourCompany.com</UserAgent>'+;
'    </Sender>'+;
'</Header>'+;
'<Request>'+;
'    <PunchOutSetupRequest operation="create">'+;
'      <Extrinsic name="UserEmail">amos.engelking@engelking.de</Extrinsic>'+;
'      <BrowserFormPost> '+;
'        <URL>http://192.168.2.208/trader/cxml_test.prg</URL>'+;
'      </BrowserFormPost> '+;
'    </PunchOutSetupRequest> '+;
'</Request>'+;
'</cXML>'

IF oHttp:open()
   oHttp:Post(cRequest)
   cData := oHttp:Readall()
   gtSetClipBoard(cData)
   Alert(cData)
   IF (nX := AT("<URL>",cData)) != 0
      cUrl := SubStr(cData,nX+5,AT("</URL>",cData)-nX-5)
      Alert(cUrl)
      Wapi_ShellExecute(,"open",cUrl)
   ENDIF
//   Alert(ValToPrg(oHttp:nReplyCode))
ENDIF
Alert("Done")
