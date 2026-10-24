
PROCEDURE RUN_Browser(cUrl,cTitle)
   cUrl := "https://engelking.frepple.com/quote/"
   cTitle := "Lieferzeit fÅr Angebote berechnen"
   /*Default(@cSecret, GetConfigValue("JWT_SECRET"))
   IF Empty(cSecret)
      cSecret := "frepple-default-secret-key-change-in-production"
   ENDIF
   
   // Create payload with user information
   hPayload := CreateJWTPayload(cUserId, cEmail, 24) // 24 hours expiration
   
   // Generate JWT token
   cToken := GenerateJWT(hPayload, cSecret, "HS256")*/

hb_threadStart({|cUrl,cTitle|        
         
   LOCAL nW
   HB_gtSelect(HB_GTCREATE("gtcgi"))  //this avoids any problems with things being displayed on the screen
   nW := hb_webview_create(.T.)

   IF LETO_Connect(getConfigValue("leto_server"),HB_UserName()) < 0 
      hb_webview_eval(nW, 'window.alert("Could not connect to Leto server")')   
      hb_webview_run(nW)    
      hb_webview_destroy(nW)     
      RETURN .T.
   ENDIF
   
   hb_webview_set_title(nW,cTitle)   
   //hb_webview_bind2(nW,"aawEditorLoad",HB_CALL_FUNC_DIRECT)
   //hb_webview_bind2(nW,"aawEditorSave",HB_CALL_FUNC_DIRECT)
   hb_webview_navigate(nW,cUrl)
   hb_webview_run(nW)
   

   hb_webview_destroy(nW)
   RETURN .T.
},cUrl,cTitle)



// JWT Token Generation Functions
FUNCTION GenerateJWT(hPayload, cSecret, cAlgorithm)
   LOCAL cToken
   LOCAL hHeader := {=>}
   LOCAL cEncodedHeader, cEncodedPayload, cToSign, cSignature
   
   Default(@cAlgorithm, "HS256")
   Default(@cSecret, "your-secret-key")
   
   // Create JWT header
   hHeader["typ"] := "JWT"
   hHeader["alg"] := cAlgorithm
   
   // Encode header and payload to Base64URL
   cEncodedHeader := Base64UrlEncode(HB_JsonEncode(hHeader))
   cEncodedPayload := Base64UrlEncode(HB_JsonEncode(hPayload))
   
   // Create signature
   cToSign := cEncodedHeader + "." + cEncodedPayload
   cSignature := GenerateJWTSignature(cToSign, cSecret, cAlgorithm)
   
   // Combine all parts
   cToken := cEncodedHeader + "." + cEncodedPayload + "." + cSignature
   
RETURN cToken

FUNCTION GenerateJWTSignature(cData, cSecret, cAlgorithm)
   LOCAL cSignature
   
   DO CASE
   CASE cAlgorithm == "HS256"
      cSignature := Base64UrlEncode(hb_hmac_sha256(cData, cSecret, .T.))
   CASE cAlgorithm == "HS384"
      // Note: hb_hmac_sha384 might not be available in all Harbour versions
      // You may need to implement or use alternative crypto library
      cSignature := Base64UrlEncode(hb_hmac_sha256(cData, cSecret, .T.)) // Fallback to SHA256
   CASE cAlgorithm == "HS512"
      // Note: hb_hmac_sha512 might not be available in all Harbour versions
      // You may need to implement or use alternative crypto library  
      cSignature := Base64UrlEncode(hb_hmac_sha256(cData, cSecret, .T.)) // Fallback to SHA256
   OTHERWISE
      // Default to HMAC-SHA256
      cSignature := Base64UrlEncode(hb_hmac_sha256(cData, cSecret, .T.))
   ENDCASE
   
RETURN cSignature

FUNCTION Base64UrlEncode(cData)
   LOCAL cEncoded
   LOCAL oBase64 := TIPEncoderBase64():New()
   
   cEncoded := oBase64:Encode(cData)
   
   // Remove padding and make URL safe
   cEncoded := StrTran(cEncoded, Chr(13), "")  // Remove CR
   cEncoded := StrTran(cEncoded, Chr(10), "")  // Remove LF
   cEncoded := StrTran(cEncoded, "+", "-")     // Replace + with -
   cEncoded := StrTran(cEncoded, "/", "_")     // Replace / with _
   
   // Remove padding characters manually
   DO WHILE Right(cEncoded, 1) == "="
      cEncoded := Left(cEncoded, Len(cEncoded) - 1)
   ENDDO
   
RETURN cEncoded

FUNCTION CreateJWTPayload(cUserId, cEmail, nExpirationHours)
   LOCAL hPayload := {=>}
   LOCAL nNow := DateTime()
   
   Default(@nExpirationHours, 24)
   
   // Standard JWT claims
   hPayload["iss"] := "frepple-interface"        // Issuer
   hPayload["sub"] := cUserId                    // Subject (user ID)
   hPayload["aud"] := "frepple-api"              // Audience
   hPayload["exp"] := Int((nNow + nExpirationHours/24) * 86400)  // Expiration time (Unix timestamp)
   hPayload["nbf"] := Int(nNow * 86400)          // Not before (Unix timestamp)
   hPayload["iat"] := Int(nNow * 86400)          // Issued at (Unix timestamp)
   hPayload["jti"] := win_UuidCreateString()     // JWT ID (unique identifier)
   
   // Custom claims
   hPayload["email"] := cEmail
   hPayload["type"] := "access_token"
   
RETURN hPayload

// Example usage function
FUNCTION CreateFreppleJWT(cUserId, cEmail, cSecret)
   LOCAL hPayload, cToken
   
   Default(@cSecret, GetConfigValue("JWT_SECRET"))
   IF Empty(cSecret)
      cSecret := "frepple-default-secret-key-change-in-production"
   ENDIF
   
   // Create payload with user information
   hPayload := CreateJWTPayload(cUserId, cEmail, 24) // 24 hours expiration
   
   // Generate JWT token
   cToken := GenerateJWT(hPayload, cSecret, "HS256")
   
RETURN cToken

// Test function to demonstrate JWT generation
PROCEDURE TestJWTGeneration()
   LOCAL cToken, hPayload
   LOCAL cUserId := "user123"
   LOCAL cEmail := "user@example.com"
   LOCAL cSecret := "my-super-secret-key"
   
   // Test 1: Generate a basic JWT token
   Alert("Generating JWT token for user: " + cUserId)
   cToken := CreateFreppleJWT(cUserId, cEmail, cSecret)
   Alert("Generated JWT Token: " + cToken)
   
   // Test 2: Generate with custom payload
   hPayload := {=>}
   hPayload["user_id"] := cUserId
   hPayload["email"] := cEmail
   hPayload["role"] := "admin"
   hPayload["permissions"] := {"read", "write", "delete"}
   hPayload["exp"] := Int((DateTime() + 1) * 86400) // 1 day from now
   
   cToken := GenerateJWT(hPayload, cSecret, "HS256")
   Alert("Custom JWT Token: " + cToken)
   
   // Test 3: Different algorithm (fallback to HS256 in our implementation)
   cToken := GenerateJWT(hPayload, cSecret, "HS512")
   Alert("HS512 JWT Token (fallback): " + cToken)
   
RETURN

// Validate JWT token (basic structure validation)
FUNCTION ValidateJWTStructure(cToken)
   LOCAL aParts
   
   IF Empty(cToken)
      RETURN .F.
   ENDIF
   
   aParts := HB_ATokens(cToken, ".")
   
   // JWT should have exactly 3 parts: header.payload.signature
   IF Len(aParts) != 3
      RETURN .F.
   ENDIF
   
   // Basic check that each part is not empty
   IF Empty(aParts[1]) .OR. Empty(aParts[2]) .OR. Empty(aParts[3])
      RETURN .F.
   ENDIF
   
RETURN .T.


