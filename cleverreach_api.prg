//----------------------------------------------------------------------------
// Shared CleverReach REST client + OAuth 2.0 token handling.
//
// Meant to be #included at the BOTTOM of a runnable script
// (sync_cleverreach.prg for setup, export_contacts_cleverreach.prg for the
// address push). All functions are STATIC so each .hrb gets its own private
// copy - no dynamic-symbol clashes when several scripts are loaded together.
//
// Auth: OAuth 2.0 authorization-code flow. The client secret is stored
// encrypted in the keychain under "CLEVERREAC" (RestApi cKeyName), the tokens
// are cached in x:\run\cleverreach_token.json and auto-refreshed on expiry.
//----------------------------------------------------------------------------

STATIC FUNCTION CR_ClientId()
RETURN "vsEk6fkAkc"

STATIC FUNCTION CR_RedirectUri()
RETURN "http://localhost:8080/callback"

STATIC FUNCTION CR_TokenFile()
RETURN "x:\run\cleverreach_token.json"

STATIC FUNCTION CR_BaseV3()
RETURN "https://rest.cleverreach.com/v3"

STATIC FUNCTION CR_BaseAuth()
RETURN "https://rest.cleverreach.com"

// Current local time as a unix epoch (seconds).
STATIC FUNCTION CR_Now()
RETURN (Date() - SToD("19700101")) * 86400 + Int(Seconds())

// Hash value with default (avoids hb_HGetDef, which may be unregistered).
STATIC FUNCTION CR_HDef(hHash,cKey,xDef)
   IF ValType(hHash) == "H" .AND. HHasKey(hHash,cKey)
      RETURN hHash[cKey]
   ENDIF
RETURN xDef

// Safe stringify - CleverReach may return ids/numbers as JSON strings, so
// never call Str() on a value whose type is not guaranteed numeric.
STATIC FUNCTION CR_Str(xVal)
   DO CASE
   CASE ValType(xVal) == "C"
      RETURN xVal
   CASE ValType(xVal) == "N"
      RETURN AllTrim(Str(xVal))
   CASE ValType(xVal) == "D"
      RETURN DToC(xVal)
   ENDCASE
RETURN ""

//----------------------------------------------------------------------------
// Token storage / lifecycle
//----------------------------------------------------------------------------
STATIC FUNCTION CR_SaveToken(cAccess,cRefresh,nExpiresIn)
   LOCAL hToken := {=>}
   hToken["access_token"]  := cAccess
   hToken["refresh_token"] := cRefresh
   hToken["expires_epoch"] := CR_Now() + nExpiresIn - 300   // 5 min safety margin
   MemoWrit(CR_TokenFile(),HB_JsonEncode(hToken))
RETURN .T.

// Return a currently valid access token, refreshing if needed, else "".
STATIC FUNCTION CR_Token()
   LOCAL hToken, nExp
   IF ! File(CR_TokenFile())
      RETURN ""
   ENDIF
   hToken := HB_JsonDecode(MemoRead(CR_TokenFile()))
   IF ValType(hToken) != "H" .OR. ! HHasKey(hToken,"access_token")
      RETURN ""
   ENDIF
   nExp := CR_HDef(hToken,"expires_epoch",0)
   IF ValType(nExp) == "N" .AND. nExp > CR_Now()
      RETURN hToken["access_token"]
   ENDIF
   // expired -> try refresh
   IF HHasKey(hToken,"refresh_token") .AND. ! Empty(hToken["refresh_token"])
      RETURN CR_Refresh(hToken["refresh_token"])
   ENDIF
RETURN ""

STATIC FUNCTION CR_GetAccessToken(cAuthCode)
   LOCAL oRest := RestAPI():New()
   LOCAL hFields := {=>}, cResponse, hResponse
   oRest:cKeyName := "CLEVERREAC"      // client secret pulled from keychain
   oRest:cBaseUrl := CR_BaseAuth()
   hFields["client_id"]     := CR_ClientId()
   hFields["client_secret"] := "$PASSWORD$"
   hFields["grant_type"]    := "authorization_code"
   hFields["code"]          := cAuthCode
   hFields["redirect_uri"]  := CR_RedirectUri()
   cResponse := oRest:Execute("/oauth/token.php","POST",hFields)
   IF Empty(cResponse)
      RETURN ""
   ENDIF
   hResponse := HB_JsonDecode(cResponse)
   IF ValType(hResponse) == "H" .AND. HHasKey(hResponse,"access_token")
      CR_SaveToken(hResponse["access_token"], ;
                   CR_HDef(hResponse,"refresh_token",""), ;
                   CR_HDef(hResponse,"expires_in",3600))
      RETURN hResponse["access_token"]
   ENDIF
   IF ValType(hResponse) == "H"
      Alert("CleverReach: " + CR_HDef(hResponse,"error_description","Unbekannter Fehler"))
   ENDIF
RETURN ""

STATIC FUNCTION CR_Refresh(cRefresh)
   LOCAL oRest := RestAPI():New()
   LOCAL hFields := {=>}, cResponse, hResponse
   IF Empty(cRefresh)
      RETURN ""
   ENDIF
   oRest:cKeyName := "CLEVERREAC"
   oRest:cBaseUrl := CR_BaseAuth()
   hFields["client_id"]     := CR_ClientId()
   hFields["client_secret"] := "$PASSWORD$"
   hFields["grant_type"]    := "refresh_token"
   hFields["refresh_token"] := cRefresh
   cResponse := oRest:Execute("/oauth/token.php","POST",hFields)
   IF Empty(cResponse)
      RETURN ""
   ENDIF
   hResponse := HB_JsonDecode(cResponse)
   IF ValType(hResponse) == "H" .AND. HHasKey(hResponse,"access_token")
      CR_SaveToken(hResponse["access_token"], ;
                   CR_HDef(hResponse,"refresh_token",cRefresh), ;
                   CR_HDef(hResponse,"expires_in",3600))
      RETURN hResponse["access_token"]
   ENDIF
RETURN ""

// Full interactive authorization-code flow (opens a browser).
STATIC FUNCTION CR_Authorize()
   LOCAL cUrl, cAuthCode, oShell
   cUrl := CR_BaseAuth() + "/oauth/authorize.php?" + ;
           "client_id=" + CR_ClientId() + ;
           "&response_type=code" + ;
           "&redirect_uri=" + CR_UrlEncode(CR_RedirectUri())
   BEGIN SEQUENCE
      oShell := CreateObject("WScript.Shell")
      oShell:Run(cUrl)
   RECOVER
      Alert("Bitte diese URL im Browser oeffnen:" + Chr(13) + Chr(10) + cUrl)
   END SEQUENCE
   Alert("Bitte die Anwendung im Browser autorisieren." + Chr(13) + Chr(10) + ;
         "Danach den Wert des 'code'-Parameters aus der URL kopieren.")
   cAuthCode := Trim(GetBox(Space(80),"Autorisierungs-Code eingeben","@S80"))
   IF Empty(cAuthCode)
      RETURN ""
   ENDIF
RETURN CR_GetAccessToken(cAuthCode)

// Return a usable token: cached/refreshed, else run the interactive flow.
STATIC FUNCTION CR_EnsureToken()
   LOCAL cToken := CR_Token()
   IF Empty(cToken)
      cToken := CR_Authorize()
   ENDIF
RETURN cToken

STATIC FUNCTION CR_UrlEncode(cString)
   LOCAL cResult := "", i, cChar, nCode
   LOCAL cHex := "0123456789ABCDEF"
   FOR i := 1 TO Len(cString)
      cChar := SubStr(cString,i,1)
      nCode := Asc(cChar)
      DO CASE
      CASE (nCode >= 48 .AND. nCode <= 57) .OR. (nCode >= 65 .AND. nCode <= 90) .OR. ;
           (nCode >= 97 .AND. nCode <= 122) .OR. cChar $ "-_.~"
         cResult += cChar
      CASE cChar == " "
         cResult += "+"
      OTHERWISE
         cResult += "%" + SubStr(cHex,Int(nCode/16)+1,1) + SubStr(cHex,(nCode % 16)+1,1)
      ENDCASE
   NEXT
RETURN cResult

//----------------------------------------------------------------------------
// REST core
//----------------------------------------------------------------------------
// Perform an authenticated v3 call. Returns the decoded response (H/A) or NIL.
STATIC FUNCTION CR_Call(cToken,cPath,cMethod,xBody)
   LOCAL oRest := RestAPI():New()
   LOCAL aHeader := {"Authorization: Bearer " + cToken, ;
                     "Content-Type: application/json", ;
                     "Accept: application/json"}
   LOCAL cResp
   oRest:cBaseUrl := CR_BaseV3()
   cResp := oRest:Execute(cPath,cMethod,xBody,aHeader,.T.)
   IF Empty(cResp)
      RETURN NIL
   ENDIF
RETURN HB_JsonDecode(cResp)

// Error text if the decoded response is a CleverReach error object, else "".
STATIC FUNCTION CR_ErrorText(xResp)
   LOCAL xErr
   IF ValType(xResp) == "H" .AND. HHasKey(xResp,"error")
      xErr := xResp["error"]
      IF ValType(xErr) == "H"
         RETURN CR_HDef(xErr,"message",CR_HDef(xErr,"code","Fehler"))
      ELSEIF ValType(xErr) == "C"
         RETURN xErr
      ELSEIF ValType(xErr) == "N"
         RETURN AllTrim(Str(xErr))
      ENDIF
      RETURN "Fehler"
   ENDIF
RETURN ""

// All receiver groups (mailing lists). Returns an array of hashes.
STATIC FUNCTION CleverReachGroups(cToken)
   LOCAL xResp := CR_Call(cToken,"/groups.json","GET",NIL)
   IF ValType(xResp) == "A"
      RETURN xResp
   ENDIF
RETURN {}

// Resolve a group id by (case-insensitive) name. Returns 0 if not found.
STATIC FUNCTION CleverReachFindGroupId(cToken,cName)
   LOCAL aGroups := CleverReachGroups(cToken), hG
   FOR EACH hG IN aGroups
      IF ValType(hG) == "H" .AND. HHasKey(hG,"name") .AND. ;
         Upper(Trim(hG["name"])) == Upper(Trim(cName))
         RETURN CR_Str(CR_HDef(hG,"id",""))   // id may be a string in the JSON
      ENDIF
   NEXT
RETURN ""

// Build a CleverReach receiver object.
//   hGlobal - standard fields (firstname,lastname,salutation,company,...)
//   hAttr   - custom group attributes
//   lActive - .T. activated, .F. deactivated (activated = 0)
STATIC FUNCTION CleverReachReceiver(cEmail,hGlobal,hAttr,lActive)
   LOCAL hR := {=>}
   Default(@lActive,.T.)
   hR["email"]      := Lower(Trim(cEmail))
   hR["source"]     := "Trader"
   hR["registered"] := CR_Now()
   hR["activated"]  := IF(lActive,CR_Now(),0)
   IF ValType(hGlobal) == "H" .AND. ! Empty(hGlobal)
      hR["global_attributes"] := hGlobal
   ENDIF
   IF ValType(hAttr) == "H" .AND. ! Empty(hAttr)
      hR["attributes"] := hAttr
   ENDIF
RETURN hR

// Insert-or-update a batch of receivers into a group ("Aktualisieren und
// Hinzufuegen"). Returns .T. on success; on failure fills @cError.
STATIC FUNCTION CleverReachUpsert(cToken,nGroupId,aReceivers,cError)
   LOCAL xResp, cPath
   cError := ""
   IF Empty(aReceivers)
      RETURN .T.
   ENDIF
   IF Empty(nGroupId)
      cError := "Keine Gruppen-ID"
      RETURN .F.
   ENDIF
   cPath := "/groups.json/" + CR_Str(nGroupId) + "/receivers/upsert"
   xResp := CR_Call(cToken,cPath,"POST",aReceivers)
   IF xResp == NIL
      cError := "Keine Antwort von CleverReach"
      RETURN .F.
   ENDIF
   cError := CR_ErrorText(xResp)
RETURN Empty(cError)
