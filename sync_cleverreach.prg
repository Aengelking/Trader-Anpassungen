//
// CleverReach OAuth 2.0 Integration
// Full authorization code flow with token management
//

PROC RUN_CleverReach_Sync()
   LOCAL cAccessToken
   
   // Try to load existing token
   cAccessToken := LoadToken()
   
   IF Empty(cAccessToken)
      // No valid token, start OAuth flow
      cAccessToken := StartOAuthFlow()
   ENDIF
   
   IF Empty(cAccessToken)
      Alert("Failed to authenticate with CleverReach")
      RETURN
   ENDIF
   
   // Use the access token to sync data
   SyncData(cAccessToken)
   
RETURN

FUNCTION StartOAuthFlow()
   LOCAL cAuthCode, cAccessToken
   
   // Step 1: Get authorization code
   cAuthCode := GetAuthorizationCode()
   
   IF Empty(cAuthCode)
      Alert("Authorization cancelled or failed")
      RETURN ""
   ENDIF
   
   // Step 2: Exchange authorization code for access token
   cAccessToken := GetAccessToken(cAuthCode)
   
RETURN cAccessToken

FUNCTION GetAuthorizationCode()
   LOCAL cUrl, cClientId, cRedirectUri, cAuthCode
   LOCAL oShell
   
   cClientId := "vsEk6fkAkc"
   cRedirectUri := "http://localhost:8080/callback"
   
   // Build authorization URL
   cUrl := "https://rest.cleverreach.com/oauth/authorize.php?" + ;
           "client_id=" + cClientId + ;
           "&response_type=code" + ;
           "&redirect_uri=" + UrlEncode(cRedirectUri)
   
   // Open browser for user authorization
   TRY
      oShell := CreateObject("WScript.Shell")
      oShell:Run(cUrl)
   CATCH
      Alert("Please open this URL in your browser:" + Chr(13) + Chr(10) + cUrl)
   END
   
   // Wait for user to authorize and enter the code
   Alert("Please authorize the application in your browser." + Chr(13) + Chr(10) + ;
         "After authorization, you will be redirected." + Chr(13) + Chr(10) + ;
         "Copy the 'code' parameter from the URL.")

   cAuthCode := GetBox(Space(50), "Enter the authorization code from the URL:")

RETURN cAuthCode

FUNCTION GetAccessToken(cAuthCode)
   LOCAL oRest, hFields, cResponse, hResponse
   LOCAL cClientId := "vsEk6fkAkc"
   LOCAL cClientSecret := "$PASSWORD$"  // Replace with actual secret
   LOCAL cRedirectUri := "http://localhost:8080/callback"
   
   oRest := RestAPI():New()
   oRest:cKeyName := "CLEVERREAC"
   oRest:cBaseUrl := "https://rest.cleverreach.com"
   
   // Prepare token request
   hFields := {=>}
   hFields["client_id"] := cClientId
   hFields["client_secret"] := cClientSecret
   hFields["grant_type"] := "authorization_code"
   hFields["code"] := cAuthCode
   hFields["redirect_uri"] := cRedirectUri
   
   // Request access token
   cResponse := oRest:Execute("/oauth/token.php", "POST", hFields)
   
   IF Empty(cResponse)
      Alert("Failed to get response from CleverReach")
      RETURN ""
   ENDIF
   
   // Parse JSON response
   TRY
      hResponse := hb_JsonDecode(cResponse)
      
      IF hb_HHasKey(hResponse, "access_token")
         // Store token with refresh token and expiry
         SaveToken(hResponse["access_token"], ;
                   hb_HGetDef(hResponse, "refresh_token", ""), ;
                   hb_HGetDef(hResponse, "expires_in", 3600))
         RETURN hResponse["access_token"]
      ELSE
         Alert("Error: " + hb_HGetDef(hResponse, "error_description", "Unknown error"))
      ENDIF
   CATCH
      Alert("Failed to parse token response:" + Chr(13) + Chr(10) + cResponse)
   END
   
RETURN ""

FUNCTION RefreshAccessToken(cRefreshToken)
   LOCAL oRest, hFields, cResponse, hResponse
   LOCAL cClientId := "vsEk6fkAkc"
   LOCAL cClientSecret := "$PASSWORD$"
   
   IF Empty(cRefreshToken)
      RETURN ""
   ENDIF
   
   oRest := RestAPI():New()
   oRest:cKeyName := "CLEVERREAC"
   oRest:cBaseUrl := "https://rest.cleverreach.com"
   
   hFields := {=>}
   hFields["client_id"] := cClientId
   hFields["client_secret"] := cClientSecret
   hFields["grant_type"] := "refresh_token"
   hFields["refresh_token"] := cRefreshToken
   
   cResponse := oRest:Execute("/oauth/token.php", "POST", hFields)
   
   TRY
      hResponse := hb_JsonDecode(cResponse)
      
      IF hb_HHasKey(hResponse, "access_token")
         SaveToken(hResponse["access_token"], ;
                   hb_HGetDef(hResponse, "refresh_token", cRefreshToken), ;
                   hb_HGetDef(hResponse, "expires_in", 3600))
         RETURN hResponse["access_token"]
      ENDIF
   CATCH
   END
   
RETURN ""

FUNCTION SaveToken(cAccessToken, cRefreshToken, nExpiresIn)
   LOCAL hToken, cFile := "x:\run\cleverreach_token.json"
   LOCAL tExpiry
   
   // Calculate expiry time (subtract 5 minutes for safety margin)
   tExpiry := hb_DateTime() + ((nExpiresIn - 300) / 86400)
   
   hToken := {=>}
   hToken["access_token"] := cAccessToken
   hToken["refresh_token"] := cRefreshToken
   hToken["expires_at"] := hb_TToC(tExpiry, "yyyy-mm-dd", "hh:mm:ss")
   hToken["expires_timestamp"] := tExpiry
   
   hb_MemoWrit(cFile, hb_JsonEncode(hToken, .T.))
   
RETURN .T.

FUNCTION LoadToken()
   LOCAL cFile := "x:\run\cleverreach_token.json"
   LOCAL hToken, tNow, tExpiry
   
   IF !File(cFile)
      RETURN ""
   ENDIF
   
   TRY
      hToken := hb_JsonDecode(MemoRead(cFile))
      
      IF Empty(hToken)
         RETURN ""
      ENDIF
      
      tNow := hb_DateTime()
      tExpiry := hToken["expires_timestamp"]
      
      // Check if token is still valid
      IF tExpiry > tNow
         RETURN hToken["access_token"]
      ELSE
         // Token expired, try to refresh
         IF hb_HHasKey(hToken, "refresh_token")
            RETURN RefreshAccessToken(hToken["refresh_token"])
         ENDIF
      ENDIF
   CATCH
      // Invalid token file
      RETURN ""
   END
   
RETURN ""

FUNCTION SyncData(cAccessToken)
   LOCAL oRest, hHeaders, cResponse, aGroups, hGroup
   LOCAL nCount := 0
   
   oRest := RestAPI():New()
   oRest:cKeyName := "CLEVERREAC"
   oRest:cBaseUrl := "https://rest.cleverreach.com/v3"
   
   // Set authorization header
   hHeaders := {=>}
   hHeaders["Authorization"] := "Bearer " + cAccessToken
   hHeaders["Content-Type"] := "application/json"
   
   // Example: Get groups
   cResponse := oRest:Execute("/groups.json", "GET", NIL, hHeaders)
   
   IF Empty(cResponse)
      Alert("Failed to get data from CleverReach")
      RETURN .F.
   ENDIF
   
   TRY
      aGroups := hb_JsonDecode(cResponse)
      
      IF ValType(aGroups) == "A"
         FOR EACH hGroup IN aGroups
            nCount++
            // Process each group here
            ? "Group:", hb_HGetDef(hGroup, "name", "Unknown"), ;
              "ID:", hb_HGetDef(hGroup, "id", 0)
         NEXT
         
         Alert("Successfully synced " + AllTrim(Str(nCount)) + " groups from CleverReach")
      ELSE
         Alert("Unexpected response format")
      ENDIF
   CATCH
      Alert("Failed to parse response:" + Chr(13) + Chr(10) + cResponse)
   END
   
RETURN .T.

FUNCTION UrlEncode(cString)
   LOCAL cResult := ""
   LOCAL i, cChar, nCode
   
   FOR i := 1 TO Len(cString)
      cChar := SubStr(cString, i, 1)
      nCode := Asc(cChar)
      
      DO CASE
         CASE (nCode >= 48 .AND. nCode <= 57) .OR. ;  // 0-9
              (nCode >= 65 .AND. nCode <= 90) .OR. ;  // A-Z
              (nCode >= 97 .AND. nCode <= 122) .OR. ; // a-z
              cChar $ "-_.~"
            cResult += cChar
         CASE cChar == " "
            cResult += "+"
         OTHERWISE
            cResult += "%" + Right("0" + hb_NumToHex(nCode), 2)
      ENDCASE
   NEXT
   
RETURN cResult

FUNCTION InputBox(cPrompt, cTitle, cDefault)
   LOCAL cResult := Space(200)
   
   // Simple input implementation - replace with your UI framework
   @ 10, 10 SAY cPrompt
   @ 11, 10 GET cResult PICTURE "@S50"
   READ
   
RETURN AllTrim(cResult)


