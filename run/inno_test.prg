PROC INNO_TEST
LOCAL oInno := InnovaPhone():New("http://192.168.2.20/PBX0/user.soap","SOAP","vvjRJtTKXJ")
LOCAL cXML 
IF ! oInno:LoggedIn()
   Alert("Login failed")
   RETURN
ENDIF
Alert("Logged in")

cXML := '&lt;show&gt;&lt;user cn="amos.engelking" config="true"/&gt;&lt;/show&gt;'
Alert(oInno:oSOAP:Call("Admin",{SOAPParameter():New("session",cXML,{"xsi:type"=>"xsd:string"})},,.T.,.F.))