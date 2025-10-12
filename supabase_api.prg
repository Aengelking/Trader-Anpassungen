#include '\\ek-server4\data\hb34\include\hbclass.ch'
#include '\\ek-server4\data\hb34\contrib\hbcurl\hbcurl.ch'
CLASS Supabase FROM RestAPI
   METHOD New
   METHOD Login
   METHOD Execute

   DATA cToken
ENDCLASS

METHOD New 
   ::cBaseUrl := "https://dliworuqojsjkkxroeqz.supabase.co/"
   ::cKeyName := "LOV-INTERN"
   ::cApiKeyName  := "LOV-INTAPI"
RETURN ::Super():New()

METHOD Login
   LOCAL hLogin

   hLogin := HB_JsonDecode(::Execute("auth/v1/token?grant_type=password","POST",{"email"=>"$USERNAME$","password"=>"$PASSWORD$"},,.T.))
   IF "access_token" $ hLogin
      ::cToken := hLogin["access_token"]
   ELSE
      Alert(ValToPrg(hLogin))
      RETURN .F.
   ENDIF
RETURN .T.

METHOD Execute(cUrl,cMethod,hData,aMoreHeader)
   LOCAL lPostJson := .F.
   LOCAL aHeader,nX

   IF Empty(aHeader)
      aHeader := {}
   ENDIF

   //Aadd(aHeader,"apikey: "+"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRsaXdvcnVxb2pzamtreHJvZXF6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDAxNjkzMjMsImV4cCI6MjA1NTc0NTMyM30.RfTWO9-R7N840CFhLvSPM0ANMeZTyrn_v9jCcjrG9Hk")
   Aadd(aHeader,"apikey: $APIKEY$")
   IF ! Empty(::cToken)
      Aadd(aHeader,"Authorization: Bearer "+::cToken)
   ENDIF
   IF ! cMethod $ {"GET"} .AND. ! Empty(hData)
      lPostJson := .T.
      Aadd(aHeader,"content-type: application/json")
   ENDIF

   IF ! Empty(aMoreHeader)
      FOR nX := 1 TO Len(aMoreHeader)
         Aadd(aHeader,aMoreHeader[nX])
      NEXT
   ENDIF
   

RETURN ::Super():Execute(cUrl,cMethod,hData,aHeader,lPostJson) //,nResponse,cResponse,cFile)
