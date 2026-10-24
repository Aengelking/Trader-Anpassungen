#include '\\ek-server4\data\hb34\include\hbclass.ch'
#include '\\ek-server4\data\hb34\contrib\hbcurl\hbcurl.ch'
CLASS Supabase FROM RestAPI
   METHOD New
   METHOD Login
   METHOD Execute

   DATA cToken
ENDCLASS

METHOD New(cBaseUrl, cKeyName, cApiKeyName) CLASS Supabase
   IF Empty(cBaseUrl)
      ::cBaseUrl := "https://dliworuqojsjkkxroeqz.supabase.co/"
   ELSE
      ::cBaseUrl := cBaseUrl
   ENDIF
   IF Empty(cKeyName)
      ::cKeyName := "LOV-INTERN"
   ELSE
      ::cKeyName := cKeyName
   ENDIF
   IF Empty(cApiKeyName)
      ::cApiKeyName := "LOV-INTAPI"
   ELSE
      ::cApiKeyName := cApiKeyName
   ENDIF
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
