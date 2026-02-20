//#include "x:\run\product_data\channel_config.ch"

#define DIGIKEY_PROVIDER "digikey"
#define DIGIKEY_KEYCHAIN "DIGIKEY"

FUNCTION DigiKey_UploadOffersV2(aPriceData, cChannel)
   LOCAL cEnv := GetChannelSettingWithDefault("upload_settings.digikey_api.environment", "sandbox")
   LOCAL cBaseUrl := GetChannelSettingWithDefault("upload_settings.digikey_api.base_url", "https://sandbox-api.digikey.com")
   LOCAL cSupplierId := GetChannelSetting("upload_settings.digikey_api.supplier_id")
   LOCAL cFileOrigin := GetChannelSettingWithDefault("upload_settings.digikey_api.file_origin", "API")
   LOCAL cUploadVersion := GetChannelSettingWithDefault("upload_settings.digikey_api.upload_version", "V2")
   LOCAL lExcludeDk := GetChannelSettingWithDefault("upload_settings.digikey_api.excludes_dk_article_id", .F.)
   LOCAL cClientId := GetChannelSetting("upload_settings.digikey_api.client_id")
   LOCAL cCurl := GetChannelSettingWithDefault("upload_settings.digikey_api.curl_path", "c:\\curl\\bin\\curl")
   LOCAL cToken
   LOCAL cFile
   LOCAL cUrl
   LOCAL cCmd
   LOCAL cData := ""
   LOCAL nStdOUT := 0
   LOCAL nProc
   LOCAL nSecond
   LOCAL cLine
   LOCAL nBytes
   LOCAL hResponse
   LOCAL lSuccess := .F.

   IF Empty(cSupplierId)
      Alert("DigiKey supplier id is missing in channel config")
      RETURN .F.
   ENDIF

   IF Empty(cClientId)
      Alert("DigiKey client id is missing in channel config")
      RETURN .F.
   ENDIF

   cToken := DigiKey_GetAccessToken(cChannel, cEnv)
   IF Empty(cToken)
      Alert("DigiKey token acquisition failed")
      RETURN .F.
   ENDIF

   cFile := DigiKey_BuildOffersFile(aPriceData, cChannel)
   IF Empty(cFile)
      Alert("DigiKey offers file generation failed")
      RETURN .F.
   ENDIF

   cUrl := cBaseUrl + "/Sales/Marketplace2/Offers/v2/offers/file"
   cUrl += "?supplierId=" + cSupplierId
   cUrl += "&fileOrigin=" + cFileOrigin
   cUrl += "&uploadVersion=" + cUploadVersion
   cUrl += "&excludesDkArticleId=" + IF(lExcludeDk, "true", "false")

   cCmd := '"' + cCurl + '" -s -X POST "' + cUrl + '"'
   cCmd += ' -H "Authorization: Bearer ' + cToken + '"'
   cCmd += ' -H "X-DIGIKEY-Client-Id: ' + cClientId + '"'
   cCmd += ' -F "File=@' + cFile + '"'

   nProc := HB_OpenProcess(cCmd,,@nStdOut,,.T.)
   nSecond := Seconds()
   DO WHILE HB_ProcessValue(nProc,.F.) == -1
      cLine := Space(1000)
      nBytes := Fread(nStdOUT, @cLine, Len(cLine))
      cData += SubStr(cLine,1,nBytes)
      IF Seconds() - nSecond > GetChannelSettingWithDefault("upload_settings.digikey_api.timeout_seconds", 30)
         ? "timeout"
         EXIT
      ENDIF
   ENDDO

   BEGIN SEQUENCE
      hResponse := HB_JsonDecode(cData)
   RECOVER
      hResponse := NIL
   END SEQUENCE

   lSuccess := ValType(hResponse) == "H" .AND. HHasKey(hResponse, "id")
   IF ! lSuccess
      SendMessage("Produktmanagement | DigiKey Upload fehlgeschlagen", "Upload fehlgeschlagen: " + cChannel, "Response:<br>" + cData)
   ENDIF

RETURN lSuccess

STATIC FUNCTION DigiKey_GetAccessToken(cChannel, cEnv)
   LOCAL hToken := OauthToken_Load(DIGIKEY_PROVIDER, cChannel, cEnv)
   LOCAL tNow := hb_DateTime()
   LOCAL tExpiry
   LOCAL cAccess

   IF ValType(hToken) == "H"
      tExpiry := hb_HGetDef(hToken, "expires_at", tNow)
      cAccess := hb_HGetDef(hToken, "access_token", "")
      IF ! Empty(cAccess) .AND. tExpiry > tNow + (300 / 86400)
         RETURN cAccess
      ENDIF
      IF ! Empty(hb_HGetDef(hToken, "refresh_token", ""))         
         RETURN DigiKey_RequestToken(cChannel, cEnv, "refresh_token", hb_HGetDef(hToken, "refresh_token", ""), "")
      ENDIF
   ENDIF

RETURN DigiKey_Authorize(cChannel, cEnv)

STATIC FUNCTION DigiKey_RequestToken(cChannel, cEnv, cGrantType, cRefreshToken, cAuthCode)
   LOCAL cTokenUrl := GetChannelSettingWithDefault("upload_settings.digikey_api.token_url", "https://sandbox-api.digikey.com/v1/oauth2/token")
   LOCAL cRedirectUri := GetChannelSettingWithDefault("upload_settings.digikey_api.redirect_uri", "http://localhost:8080/callback")
   LOCAL oRest := RestAPI():New()
   LOCAL hFields := {=>}
   LOCAL aHeaders := {"Content-Type: application/x-www-form-urlencoded"}
   LOCAL cResponse
   LOCAL hResponse

   oRest:cKeyName := DIGIKEY_KEYCHAIN
   oRest:cBaseUrl := ""

   hFields["client_id"] := "$USERNAME$"
   hFields["client_secret"] := "$PASSWORD$"
   hFields["grant_type"] := cGrantType
   
   IF cGrantType == "authorization_code"
      hFields["code"] := cAuthCode
      hFields["redirect_uri"] := cRedirectUri
   ELSEIF ! Empty(cRefreshToken)
      hFields["refresh_token"] := cRefreshToken
   ENDIF

   cResponse := oRest:Execute(cTokenUrl, "POST", hFields, aHeaders, .F.)

   IF Empty(cResponse)
      Alert("Token request failed - empty response")
      RETURN ""
   ENDIF

   BEGIN SEQUENCE
      hResponse := HB_JsonDecode(cResponse)      
   RECOVER
      Alert("Token response parse error: " + cResponse)
      RETURN ""
   END SEQUENCE

   IF ValType(hResponse) != "H" .OR. ! HHasKey(hResponse, "access_token")
      Alert("Token response missing access_token: " + cResponse)
      RETURN ""
   ENDIF

   OauthToken_Save(DIGIKEY_PROVIDER, cChannel, cEnv, hResponse)

RETURN hResponse["access_token"]

STATIC FUNCTION DigiKey_BuildOffersFile(aPriceData, cChannel)
   LOCAL cFile := Path("export\product_data\" + cChannel + "_offers.csv")
   LOCAL aData := DigiKey_BuildOffersRows(aPriceData)

   IF Len(aData) <= 1
      RETURN ""
   ENDIF

   SaveAsCSV(cFile, aData, .T.)
RETURN cFile

STATIC FUNCTION DigiKey_BuildOffersRows(aPriceData)
   LOCAL aData := {}
   LOCAL aHeaders
   LOCAL nRow, nCol
   LOCAL hRow
   LOCAL cSupplierPart
   LOCAL cDkArticle
   LOCAL nQty
   LOCAL nLead
   LOCAL nBreaks := Max(1, GetChannelSettingWithDefault("upload_settings.digikey_api.price_breaks", 1))
   LOCAL cImportType := GetChannelSettingWithDefault("upload_settings.digikey_api.import_type", "REPLACE")
   LOCAL cCustomerCode := GetChannelSetting("upload_settings.digikey_api.customer_code")
   LOCAL aBreaks
   LOCAL nX

   IF ValType(aPriceData) != "A" .OR. Len(aPriceData) < 2
      RETURN {}
   ENDIF

   AAdd(aData, DigiKey_BuildHeaderRow(nBreaks))
   aHeaders := aPriceData[1]

   IF Select("aku") == 0
      NetUse("artkund", "aku")
   ENDIF
   IF Select("art") == 0
      NetUse("artikel", "art")
   ENDIF

   FOR nRow := 2 TO Len(aPriceData)
      hRow := {=>}
      FOR nCol := 1 TO Len(aHeaders)
         hRow[aHeaders[nCol]] := aPriceData[nRow, nCol]
      NEXT

      cSupplierPart := AllTrim(hb_HGetDef(hRow, "sku", ""))
      IF Empty(cSupplierPart)
         cSupplierPart := AllTrim(hb_HGetDef(hRow, "product-id", ""))
      ENDIF

      IF Empty(cSupplierPart)
         LOOP
      ENDIF

      cDkArticle := DigiKey_GetCustomerPart(hb_HGetDef(hRow, "product-id", ""), cCustomerCode)
      nQty := DigiKey_ToNumber(hb_HGetDef(hRow, "quantity", 0))
      nLead := DigiKey_ToNumber(hb_HGetDef(hRow, "leadtime-to-ship", 0))

      aBreaks := DigiKey_BuildBreaks(hRow, nBreaks)

      AAdd(aData, {;
         cSupplierPart,;
         cDkArticle,;
         nQty,;
         aBreaks[1,1],;
         aBreaks[1,2],;
         nLead,;
         cImportType;
      })

      FOR nX := 2 TO nBreaks
         AAdd(Atail(aData), aBreaks[nX,1])
         AAdd(Atail(aData), aBreaks[nX,2])
      NEXT
   NEXT

RETURN aData

STATIC FUNCTION DigiKey_BuildHeaderRow(nBreaks)
   LOCAL aHeader := {;
      "Supplier Part Number",;
      "DK Article ID",;
      "Available Stock Quantity",;
      "Break Quantity 1 (MOQ)",;
      "Break Price 1",;
      "Leadtime To Ship",;
      "Import Type";
   }
   LOCAL nX

   FOR nX := 2 TO nBreaks
      AAdd(aHeader, "Break Quantity " + LTrim(Str(nX)))
      AAdd(aHeader, "Break Price " + LTrim(Str(nX)))
   NEXT

RETURN aHeader

STATIC FUNCTION DigiKey_BuildBreaks(hRow, nBreaks)
   LOCAL aBreaks := Array(nBreaks)
   LOCAL nX
   LOCAL nMOQ := DigiKey_ToNumber(hb_HGetDef(hRow, "min-order-quantity", 1))
   LOCAL nPrice := DigiKey_ToNumber(hb_HGetDef(hRow, "price", 0))
   LOCAL cRanges := hb_HGetDef(hRow, "discount-ranges", "")
   LOCAL aRanges := DigiKey_ParseRanges(cRanges)

   aBreaks[1] := {nMOQ, nPrice}

   FOR nX := 2 TO nBreaks
      IF nX - 1 <= Len(aRanges)
         aBreaks[nX] := aRanges[nX - 1]
      ELSE
         aBreaks[nX] := {0, 0}
      ENDIF
   NEXT

RETURN aBreaks

STATIC FUNCTION DigiKey_ParseRanges(cRanges)
   LOCAL aOut := {}
   LOCAL aItems
   LOCAL nX
   LOCAL aParts
   LOCAL nQty
   LOCAL nPrice

   IF Empty(cRanges)
      RETURN {}
   ENDIF

   aItems := HB_ATokens(cRanges, ",")
   FOR nX := 1 TO Len(aItems)
      aParts := HB_ATokens(aItems[nX], "|")
      IF Len(aParts) >= 2
         nQty := DigiKey_ToNumber(aParts[1])
         nPrice := DigiKey_ToNumber(aParts[2])
         AAdd(aOut, {nQty, nPrice})
      ENDIF
   NEXT

RETURN aOut

STATIC FUNCTION DigiKey_GetCustomerPart(cMatchcode, cCustomerCode)
   LOCAL cMatch := AllTrim(cMatchcode)
   LOCAL cCust := AllTrim(cCustomerCode)
   LOCAL cPart := ""

   IF Empty(cMatch) .OR. Empty(cCust)
      RETURN ""
   ENDIF

   art->(dbSetOrder(1))
   IF art->(dbSeek(Pad(cMatch,25)))
      IF aku->(dbSeek(Pad(cCust,8) + Str(art->Artikelnr,6)))
         cPart := AllTrim(aku->Artlief)
      ENDIF
   ENDIF

RETURN cPart

STATIC FUNCTION DigiKey_ToNumber(xValue)
   LOCAL nValue
   IF ValType(xValue) == "N"
      RETURN xValue
   ENDIF
   IF ValType(xValue) == "C"
      RETURN Val(AllTrim(xValue))
   ENDIF
   //nValue := Val(AllTrim(Str(xValue)))
RETURN 0 //nValue

STATIC FUNCTION DigiKey_Authorize(cChannel, cEnv)
   LOCAL cAuthUrl := GetChannelSettingWithDefault("upload_settings.digikey_api.authorize_url", "https://sandbox-api.digikey.com/v1/oauth2/authorize")
   LOCAL cRedirectUri := GetChannelSettingWithDefault("upload_settings.digikey_api.redirect_uri", "http://localhost:8080/callback")
   LOCAL cClientId := GetChannelSetting("upload_settings.digikey_api.client_id")
   LOCAL cScope := GetChannelSettingWithDefault("upload_settings.digikey_api.scope", "")
   LOCAL cAuthCode := ""
   LOCAL cUrl := ""
   LOCAL nTimeout := 120
   LOCAL nWait := 0
   
   IF Empty(cClientId)
      Alert("DigiKey client_id is missing in channel config")
      RETURN ""
   ENDIF
   
   cUrl := cAuthUrl + "?client_id=" + DigiKey_UrlEncode(cClientId) + ;
           "&redirect_uri=" + DigiKey_UrlEncode(cRedirectUri) + ;
           "&response_type=code"
   
   IF ! Empty(cScope)
      cUrl += "&scope=" + DigiKey_UrlEncode(cScope)
   ENDIF
   
   Alert("Opening browser for DigiKey authorization...;Complete the authorization in your browser.;This window will wait for up to " + LTrim(Str(nTimeout)) + " seconds.")
   
   Wapi_ShellExecute(,'open',cUrl)
   
   * Poll database for authorization code
   nWait := 0
   DO WHILE nWait < nTimeout
      cAuthCode := DigiKey_RetrieveAuthCode()
      IF ! Empty(cAuthCode)
         EXIT
      ENDIF
      Inkey(1)  && Wait 1 second
      nWait++
   ENDDO
   
   IF Empty(cAuthCode)
      Alert("Timeout waiting for authorization callback")
      RETURN ""
   ENDIF
   
RETURN DigiKey_RequestToken(cChannel, cEnv, "authorization_code", "", cAuthCode)

STATIC FUNCTION DigiKey_RetrieveAuthCode()
   LOCAL cAuthCode := ""
   LOCAL cJson := ""
   LOCAL hData
   LOCAL tCreated
   LOCAL tNow := hb_DateTime()
   
   BEGIN SEQUENCE
      * Retrieve from LETO variable
      cJson := Leto_VarGet("OAUTH","DIGIKEY_CODE")
      
      IF Empty(cJson)
         BREAK
      ENDIF
      
      * Parse JSON
      hData := hb_JsonDecode(cJson)
      IF ValType(hData) != "H"
         BREAK
      ENDIF

      * Check if not expired (10 minutes)
      tCreated := SToT(hb_HGetDef(hData, "created", TtoS(tNow)))
      IF tCreated < tNow - (600 / 86400)
         * Expired, clear it
         Leto_VarDel("OAUTH","DIGIKEY_CODE")
         BREAK
      ENDIF
      
      * Get the code and delete variable so it can't be reused
      cAuthCode := hb_HGetDef(hData, "code", "")
      IF ! Empty(cAuthCode)
         Leto_VarDel("OAUTH","DIGIKEY_CODE")
      ENDIF
      
   RECOVER
   END SEQUENCE
   
RETURN cAuthCode

STATIC FUNCTION DigiKey_UrlEncode(cStr)
   LOCAL cOut := ""
   LOCAL nX
   LOCAL c
   
   FOR nX := 1 TO Len(cStr)
      c := SubStr(cStr, nX, 1)
      IF IsAlpha(c) .OR. IsDigit(c) .OR. c $ "-_.~"
         cOut += c
      ELSE
         cOut += "%" + HB_StrToHex(c)
      ENDIF
   NEXT
   
RETURN cOut

