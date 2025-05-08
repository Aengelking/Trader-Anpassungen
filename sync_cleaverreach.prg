//

PROC RUN_CleverReach_Sync()
   LOCAL oRest
   LOCAL hFields
   LOCAL cToken := "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiIsImtpZCI6IjIwMTYifQ.eyJpc3MiOiJyZXN0LmNsZXZlcnJlYWNoLmNvbSIsImlhdCI6MTc0NTU3MDcyOCwiZXhwIjoxNzQ4MTYyNzI4LCJjbGllbnRfaWQiOjMzMDQzMCwic2hhcmQiOiJzaGFyZDE1Iiwiem9uZSI6NCwidXNlcl9pZCI6MCwibG9naW4iOiJvYXV0aC12c0VrNmZrQWtjIiwicm9sZSI6InVzZXIiLCJzY29wZXMiOiJvYV9iYXNpYyBvYV9yZWNlaXZlcnMgb2FfcmVwb3J0cyIsImluZGVudGlmaWVyIjoic3lzdGVtIiwiY2FsbGVyIjo1fQ.UemHlWDHScM9mrbwzPOOBmY-_sZhDB3OTzACvhYygBE"

   oRest := RestAPI():New()
	oRest:cKeyName := "CLEVERREAC"
	oRest:cBaseUrl := ""

   //Prepare Fields for OAuth
   hFields := {=>}
   hFields["client_id"] := "vsEk6fkAkc"
   hFields["client_secret"] := "$PASSWORD$"
   hFields["grant_type"] := "authorization_code"
   //hFields["grant_type"] := "basic"
   //hFields["code"] := "1234567890"
   hFields["response_type"] := "code"
   hFields["redirect_uri"] := "*" //https://www.cleverreach.com"

   //Send Request to get Access Token   
   cResponse := oRest:Execute("https://rest.cleverreach.com/oauth/authorize.php","POST",hFields)

   Alert(cResponse)


