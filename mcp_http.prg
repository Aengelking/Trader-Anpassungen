/*
 * MCP (Model Context Protocol) Server for Trader - Streamable HTTP transport
 *
 * A thin HTTP wrapper around the very same ProcessMCPRequest() dispatch used
 * by the STDIO transport in mcp_stdio.prg. It implements the MCP "Streamable
 * HTTP" transport in its single JSON response mode: the client POSTs one
 * JSON-RPC message to a single endpoint and receives one JSON-RPC response
 * with Content-Type: application/json. No SSE stream is opened (that can be
 * added later without touching any tool code).
 *
 * TLS is intentionally NOT handled here. Run this listener bound to localhost
 * and terminate HTTPS at a reverse proxy (Caddy / nginx / IIS / stunnel) that
 * forwards to it. See MCP_HTTP_README.md for ready-to-use configurations.
 *
 * The server is single threaded and serves one request at a time, exactly
 * like the STDIO loop, so the global work areas / LetoDBF state used by the
 * MCP_Tool_* functions are accessed serially and need no extra locking.
 *
 * BUILD NOTE: this file is not self-contained. It must be compiled/linked
 * together with mcp_stdio.prg, whose public functions it reuses:
 *     ProcessMCPRequest()   - the shared JSON-RPC dispatch
 *     CreateErrorResponse() - the shared JSON-RPC error encoder
 * and, through ProcessMCPRequest(), every MCP_Tool_* implementation.
 *
 * Copyright 2025 Trader Development Team
 *
 */

// PKCE S256 needs plain SHA-256; force it into the link (the crypto lib that
// already provides hb_HMAC_SHA256 / hb_SHA1 exposes it). If the linker still
// complains, add HB_SHA256 to the EXTERNAL list in tr_001.prg.
REQUEST HB_SHA256

// Keychain entry that holds the HMAC secret used to sign the OAuth JWTs
// (access / refresh tokens, authorization codes, client_ids). Create it once,
// e.g. via the keychain admin, with any long random value. NOTE: keychain
// entry NAMES are limited to 10 characters, hence the short "MCPOAUTH".
#define MCP_OAUTH_KEY  "MCPOAUTH"

STATIC s_hMcpSessions    := NIL   // hash: session-id -> .T. (issued at initialize)
STATIC s_nMcpSessionSeq  := 0     // monotonic counter for session-id uniqueness
STATIC s_lMcpHttpStop    := .F.   // set when a "shutdown" request arrives
STATIC s_lMcpOAuth       := .T.   // whether the OAuth 2.1 layer is enforced
STATIC s_cMcpPublicUrl   := ""    // configured public base URL for OAuth metadata

FUNCTION MCP_Http( nPort, cBindAddr, lOAuth )
   LOCAL nStdErr := hb_GetStdErr()
   LOCAL hListen, hSocket

   IF nPort == NIL
      nPort := McpHttpPort()
   ENDIF
   IF Empty(cBindAddr)
      cBindAddr := "127.0.0.1"
   ENDIF
   IF lOAuth == NIL
      lOAuth := MCP_Http_OAuthDefault()   // value MCP_HTTP_OAUTH, default ON
   ENDIF
   s_lMcpOAuth := lOAuth

   // Public base URL for the OAuth discovery metadata, read ONCE here so that
   // per-request handling never touches the DB / current work area. Empty ->
   // derive it from the proxy's forwarded / Host headers.
   s_cMcpPublicUrl := ""
   IF s_lMcpOAuth
      s_cMcpPublicUrl := GetValue( "MCP_HTTP_PUBLIC_URL", "", ;
         "MCP HTTP server: public base URL for OAuth metadata (e.g. https://mcp.example.com)" )
      IF ValType( s_cMcpPublicUrl ) != "C"
         s_cMcpPublicUrl := ""
      ENDIF
      s_cMcpPublicUrl := AllTrim( s_cMcpPublicUrl )
   ENDIF

   // Same guard as the STDIO server: never let a hook / error handler pop a
   // modal Alert/MsgBox that would block the request loop forever.
   SetConfigValue("BATCHMODE", .T.)

   // With OAuth on, the JWT signing secret must be present up front - otherwise
   // every token/registration would fail. Fail fast with a clear message.
   IF s_lMcpOAuth .AND. ! MCP_OAuth_SecretReady()
      FWrite( nStdErr, "MCP_Http: OAuth is enabled but the keychain secret '" + MCP_OAUTH_KEY + ;
         "' is missing. Create it, or start with OAuth disabled (pass .F. / set MCP_HTTP_OAUTH=0)." + Chr(10) )
      RETURN NIL
   ENDIF

   hb_InetInit()

   // Bind to the given interface only (localhost by default) - the reverse
   // proxy is expected to run on the same host and terminate TLS.
   hListen := hb_InetServer( nPort, NIL, cBindAddr )
   IF hListen == NIL .OR. hb_InetErrorCode( hListen ) != 0
      FWrite( nStdErr, "MCP_Http: cannot bind " + cBindAddr + ":" + LTrim(Str(nPort)) + Chr(10) )
      hb_InetCleanup()
      RETURN NIL
   ENDIF

   FWrite( nStdErr, "MCP_Http: listening on " + cBindAddr + ":" + LTrim(Str(nPort)) + ;
      " (Streamable HTTP, single response, OAuth " + IIF(s_lMcpOAuth, "on", "off") + ")" + Chr(10) )
   ? "MCP HTTP: Started on " + cBindAddr + ":" + LTrim(Str(nPort))

   s_lMcpHttpStop := .F.

   DO WHILE ! s_lMcpHttpStop
      hSocket := hb_InetAccept( hListen )
      IF hSocket == NIL
         // Accept failed (interrupted / transient) - keep serving.
         LOOP
      ENDIF

      BEGIN SEQUENCE
         MCP_Http_ServeConnection( hSocket )
      RECOVER
         // A single bad connection must never take the whole server down.
      END SEQUENCE

      hb_InetClose( hSocket )
   ENDDO

   hb_InetClose( hListen )
   hb_InetCleanup()
   dbCloseAll()

RETURN NIL

// Determine the listen port: -port / --port on the command line, else 8765.
STATIC FUNCTION McpHttpPort()
   LOCAL nX, cArg, nPort := 8765

   FOR nX := 1 TO HB_ArgC()
      cArg := Lower( HB_ArgV(nX) )
      IF ( cArg == "-port" .OR. cArg == "--port" ) .AND. nX < HB_ArgC()
         nPort := Val( HB_ArgV(nX + 1) )
      ENDIF
   NEXT

   IF nPort <= 0
      nPort := 8765
   ENDIF

RETURN nPort

// Read and answer exactly one HTTP request on hSocket.
STATIC FUNCTION MCP_Http_ServeConnection( hSocket )
   LOCAL cCRLF := Chr(13) + Chr(10)
   LOCAL cHead, nLen, cReqLine, cPath, cQuery
   LOCAL aLines, aReq, nX, cLine, nColon, nQ
   LOCAL hHeaders := {=>}
   LOCAL cHttpMethod, cKey, cVal
   LOCAL nCL, cBody, cBuf, nGot
   LOCAL cOrigin, cSessionId, cBase, cAuth
   LOCAL aCors

   // ---- Read request headers (up to the blank line) --------------------
   cHead := hb_InetRecvEndBlock( hSocket, cCRLF + cCRLF, @nLen )
   IF nLen <= 0 .OR. Empty(cHead)
      RETURN NIL
   ENDIF

   aLines := hb_ATokens( cHead, cCRLF )
   IF Len(aLines) < 1
      MCP_Http_Send( hSocket, 400, "text/plain", "Bad Request", {} )
      RETURN NIL
   ENDIF

   cReqLine := aLines[1]
   aReq := hb_ATokens( cReqLine, " " )
   IF Len(aReq) < 2
      MCP_Http_Send( hSocket, 400, "text/plain", "Bad Request", {} )
      RETURN NIL
   ENDIF
   cHttpMethod := Upper( aReq[1] )
   cPath  := aReq[2]
   cQuery := ""
   nQ := At( "?", cPath )
   IF nQ > 0
      cQuery := SubStr( cPath, nQ + 1 )
      cPath  := Left( cPath, nQ - 1 )
   ENDIF

   // Parse headers into an upper-cased hash.
   FOR nX := 2 TO Len(aLines)
      cLine := aLines[nX]
      nColon := At( ":", cLine )
      IF nColon > 0
         cKey := Upper( AllTrim( Left( cLine, nColon - 1 ) ) )
         cVal := AllTrim( SubStr( cLine, nColon + 1 ) )
         hHeaders[cKey] := cVal
      ENDIF
   NEXT

   cOrigin    := IIF( HHasKey(hHeaders, "ORIGIN"), hHeaders["ORIGIN"], "" )
   cSessionId := IIF( HHasKey(hHeaders, "MCP-SESSION-ID"), hHeaders["MCP-SESSION-ID"], "" )
   cAuth      := IIF( HHasKey(hHeaders, "AUTHORIZATION"), hHeaders["AUTHORIZATION"], "" )
   aCors      := MCP_Http_CorsHeaders( cOrigin )
   cBase      := MCP_Http_BaseUrl( hHeaders )

   // Read the request body (POST) up front so every route can use it.
   cBody := ""
   IF cHttpMethod == "POST"
      nCL := 0
      IF HHasKey( hHeaders, "CONTENT-LENGTH" )
         nCL := Val( hHeaders["CONTENT-LENGTH"] )
      ENDIF
      IF nCL > 0
         cBuf := Space( nCL )
         nGot := hb_InetRecvAll( hSocket, @cBuf, nCL )
         IF nGot > 0
            cBody := Left( cBuf, nGot )
         ENDIF
      ENDIF
   ENDIF

   // ---- CORS preflight -------------------------------------------------
   IF cHttpMethod == "OPTIONS"
      MCP_Http_Send( hSocket, 204, "", "", aCors )
      RETURN NIL
   ENDIF

   // ---- Health probe (always open, used by proxy health checks) --------
   IF cHttpMethod == "GET" .AND. ( cPath == "/healthz" .OR. cPath == "/health" )
      MCP_Http_Send( hSocket, 200, "text/plain", "ok", aCors )
      RETURN NIL
   ENDIF

   // ---- OAuth 2.1 endpoints (only when OAuth is enforced) --------------
   IF s_lMcpOAuth
      // Discovery metadata (RFC 9728 / RFC 8414).
      IF cHttpMethod == "GET" .AND. MCP_Http_StartsWith( cPath, "/.well-known/oauth-protected-resource" )
         MCP_Http_Send( hSocket, 200, "application/json", MCP_OAuth_ProtectedResourceMeta( cBase ), aCors )
         RETURN NIL
      ENDIF
      IF cHttpMethod == "GET" .AND. ( MCP_Http_StartsWith( cPath, "/.well-known/oauth-authorization-server" ) ;
                                 .OR. MCP_Http_StartsWith( cPath, "/.well-known/openid-configuration" ) )
         MCP_Http_Send( hSocket, 200, "application/json", MCP_OAuth_AuthServerMeta( cBase ), aCors )
         RETURN NIL
      ENDIF
      // Dynamic client registration (RFC 7591).
      IF cHttpMethod == "POST" .AND. cPath == "/register"
         MCP_OAuth_Register( hSocket, cBody, aCors )
         RETURN NIL
      ENDIF
      // Authorization endpoint - auto-approves and redirects back with a code.
      IF cHttpMethod == "GET" .AND. cPath == "/authorize"
         MCP_OAuth_Authorize( hSocket, cQuery, aCors )
         RETURN NIL
      ENDIF
      // Token endpoint (authorization_code / refresh_token, PKCE S256).
      IF cHttpMethod == "POST" .AND. cPath == "/token"
         MCP_OAuth_Token( hSocket, cBody, aCors )
         RETURN NIL
      ENDIF
   ENDIF

   // ---- No SSE stream on GET (and health at "/" when OAuth is off) -----
   IF cHttpMethod == "GET"
      IF ! s_lMcpOAuth .AND. cPath == "/"
         MCP_Http_Send( hSocket, 200, "text/plain", "ok", aCors )
      ELSE
         AAdd( aCors, "Allow: POST, OPTIONS" )
         MCP_Http_Send( hSocket, 405, "text/plain", "Method Not Allowed", aCors )
      ENDIF
      RETURN NIL
   ENDIF

   IF cHttpMethod != "POST"
      AAdd( aCors, "Allow: POST, OPTIONS" )
      MCP_Http_Send( hSocket, 405, "text/plain", "Method Not Allowed", aCors )
      RETURN NIL
   ENDIF

   // ---- POST to the MCP endpoint: a JSON-RPC message -------------------

   // Origin check (defence in depth against DNS-rebinding for browser clients).
   IF ! MCP_Http_OriginAllowed( cOrigin )
      MCP_Http_Send( hSocket, 403, "text/plain", "Forbidden origin", aCors )
      RETURN NIL
   ENDIF

   // Bearer token check. An unauthenticated request gets a 401 that points the
   // client at the protected-resource metadata, which kicks off the OAuth flow.
   IF s_lMcpOAuth .AND. ! MCP_OAuth_Authorized( cAuth )
      AAdd( aCors, 'WWW-Authenticate: Bearer resource_metadata="' + cBase + '/.well-known/oauth-protected-resource"' )
      MCP_Http_Send( hSocket, 401, "application/json", ;
         CreateErrorResponse( "Authorization required", "" ), aCors )
      RETURN NIL
   ENDIF

   MCP_Http_HandleMessage( hSocket, cBody, cSessionId, aCors )

RETURN NIL

// Decode the JSON-RPC body, dispatch it and write the HTTP response.
STATIC FUNCTION MCP_Http_HandleMessage( hSocket, cBody, cSessionId, aCors )
   LOCAL xMsg, hReq, cMethod, cResponse
   LOCAL lIsInitialize, cNewSession
   LOCAL aOut, cItem
   LOCAL aHeaders := {}
   LOCAL nX

   FOR nX := 1 TO Len(aCors)
      AAdd( aHeaders, aCors[nX] )
   NEXT

   IF Empty(cBody)
      MCP_Http_Send( hSocket, 400, "application/json", ;
         CreateErrorResponse( "Empty request body", "" ), aHeaders )
      RETURN NIL
   ENDIF

   xMsg := HB_JsonDecode( cBody )
   IF xMsg == NIL
      MCP_Http_Send( hSocket, 400, "application/json", ;
         CreateErrorResponse( "Invalid JSON in request", "" ), aHeaders )
      RETURN NIL
   ENDIF

   // A JSON-RPC batch arrives as an array. Process each element and return an
   // array of the responses that actually carry an id (notifications yield
   // no response). If nothing needs a response, answer 202 Accepted.
   IF ValType( xMsg ) == "A"
      aOut := {}
      FOR nX := 1 TO Len( xMsg )
         IF ValType( xMsg[nX] ) == "H"
            cItem := MCP_Http_DispatchOne( xMsg[nX], cSessionId, @lIsInitialize, @cNewSession )
            IF ! Empty(cItem)
               AAdd( aOut, cItem )
            ENDIF
            IF lIsInitialize .AND. ! Empty(cNewSession)
               AAdd( aHeaders, "Mcp-Session-Id: " + cNewSession )
            ENDIF
         ENDIF
      NEXT
      IF Len( aOut ) == 0
         MCP_Http_Send( hSocket, 202, "", "", aHeaders )
      ELSE
         MCP_Http_Send( hSocket, 200, "application/json; charset=utf-8", ;
            "[" + MCP_Http_Join( aOut, "," ) + "]", aHeaders )
      ENDIF
      RETURN NIL
   ENDIF

   IF ValType( xMsg ) != "H"
      MCP_Http_Send( hSocket, 400, "application/json", ;
         CreateErrorResponse( "Invalid JSON-RPC message", "" ), aHeaders )
      RETURN NIL
   ENDIF

   hReq := xMsg

   // Reject an unknown (expired) session id, prompting the client to re-init.
   cMethod := IIF( HHasKey(hReq, "method"), hReq["method"], "" )
   IF cMethod != "initialize" .AND. ! Empty(cSessionId)
      IF s_hMcpSessions == NIL .OR. ! HHasKey( s_hMcpSessions, cSessionId )
         MCP_Http_Send( hSocket, 404, "application/json", ;
            CreateErrorResponse( "Unknown or expired session", "" ), aHeaders )
         RETURN NIL
      ENDIF
   ENDIF

   cResponse := MCP_Http_DispatchOne( hReq, cSessionId, @lIsInitialize, @cNewSession )

   // A notification (no id) produced no response -> acknowledge with 202.
   IF Empty( cResponse )
      MCP_Http_Send( hSocket, 202, "", "", aHeaders )
      RETURN NIL
   ENDIF

   IF lIsInitialize .AND. ! Empty( cNewSession )
      AAdd( aHeaders, "Mcp-Session-Id: " + cNewSession )
   ENDIF

   MCP_Http_Send( hSocket, 200, "application/json; charset=utf-8", cResponse, aHeaders )

   // Honour a graceful shutdown request after the reply has been sent.
   IF cMethod == "shutdown"
      s_lMcpHttpStop := .T.
   ENDIF

RETURN NIL

// Dispatch one JSON-RPC object. Returns the response string, or "" for a
// notification (a request without an "id" member, which gets no response).
STATIC FUNCTION MCP_Http_DispatchOne( hReq, cSessionId, lIsInitialize, cNewSession )
   LOCAL cMethod

   // cSessionId is accepted for symmetry / future per-session state; the
   // single-server model keeps no per-session data yet.

   lIsInitialize := .F.
   cNewSession   := ""

   IF ValType( hReq ) != "H"
      RETURN CreateErrorResponse( "Invalid JSON-RPC message", "" )
   ENDIF

   // Basic JSON-RPC structural validation (mirrors the STDIO loop).
   IF ! HHasKey( hReq, "jsonrpc" ) .OR. ! HHasKey( hReq, "method" )
      RETURN CreateErrorResponse( "Invalid JSON-RPC request: missing required fields", ;
         IIF( HHasKey(hReq, "id"), hReq["id"], "" ) )
   ENDIF

   // Notifications carry no id and expect no response.
   IF ! HHasKey( hReq, "id" )
      RETURN ""
   ENDIF

   cMethod := hReq["method"]

   // Issue a session id on initialize so stateful clients can correlate calls.
   IF cMethod == "initialize"
      lIsInitialize := .T.
      cNewSession := MCP_Http_NewSession()
   ENDIF

RETURN ProcessMCPRequest( hReq )

// Create, remember and return a new session id.
STATIC FUNCTION MCP_Http_NewSession()
   LOCAL cId

   IF s_hMcpSessions == NIL
      s_hMcpSessions := {=>}
   ENDIF

   s_nMcpSessionSeq++
   cId := "s" + LTrim( Str( Int( Seconds() * 1000 ) ) ) + "-" + LTrim( Str( s_nMcpSessionSeq ) )
   s_hMcpSessions[ cId ] := .T.

RETURN cId

// Origin allow-list. Empty list (the default) accepts any origin, which is
// safe while the listener is bound to localhost behind a trusted proxy. When
// the endpoint is reachable by browsers, populate MCP_Http_AllowedOrigins().
STATIC FUNCTION MCP_Http_OriginAllowed( cOrigin )
   LOCAL aAllowed, nX

   IF Empty( cOrigin )
      RETURN .T.   // non-browser MCP clients send no Origin header.
   ENDIF

   aAllowed := MCP_Http_AllowedOrigins()
   IF Len( aAllowed ) == 0
      RETURN .T.
   ENDIF

   FOR nX := 1 TO Len( aAllowed )
      IF Lower( AllTrim( aAllowed[nX] ) ) == Lower( AllTrim( cOrigin ) )
         RETURN .T.
      ENDIF
   NEXT

RETURN .F.

// Configured list of allowed browser origins. Extend this to lock the
// endpoint down to specific web front-ends (e.g. { "https://app.example.com" }).
STATIC FUNCTION MCP_Http_AllowedOrigins()
RETURN {}

// Build the CORS response headers for a given request Origin.
STATIC FUNCTION MCP_Http_CorsHeaders( cOrigin )
   LOCAL aHeaders := {}

   IF Empty( cOrigin )
      AAdd( aHeaders, "Access-Control-Allow-Origin: *" )
   ELSE
      AAdd( aHeaders, "Access-Control-Allow-Origin: " + cOrigin )
   ENDIF
   AAdd( aHeaders, "Access-Control-Allow-Methods: POST, GET, OPTIONS" )
   AAdd( aHeaders, "Access-Control-Allow-Headers: Content-Type, Accept, Mcp-Session-Id, Authorization" )
   AAdd( aHeaders, "Access-Control-Expose-Headers: Mcp-Session-Id" )

RETURN aHeaders

// Write a full HTTP/1.1 response and close the (single request) connection.
STATIC FUNCTION MCP_Http_Send( hSocket, nStatus, cContentType, cBody, aHeaders )
   LOCAL cCRLF := Chr(13) + Chr(10)
   LOCAL cOut, nX

   IF cBody == NIL
      cBody := ""
   ENDIF
   IF aHeaders == NIL
      aHeaders := {}
   ENDIF

   cOut := "HTTP/1.1 " + LTrim(Str(nStatus)) + " " + MCP_Http_StatusText(nStatus) + cCRLF
   IF ! Empty( cContentType )
      cOut += "Content-Type: " + cContentType + cCRLF
   ENDIF
   cOut += "Content-Length: " + LTrim(Str(Len(cBody))) + cCRLF
   cOut += "Connection: close" + cCRLF
   FOR nX := 1 TO Len( aHeaders )
      cOut += aHeaders[nX] + cCRLF
   NEXT
   cOut += cCRLF + cBody

   MCP_Http_SendAll( hSocket, cOut )

RETURN NIL

STATIC FUNCTION MCP_Http_SendAll( hSocket, cSend )
   LOCAL nLen

   DO WHILE Len( cSend ) > 0
      nLen := hb_InetSendAll( hSocket, cSend )
      IF nLen == -1
         EXIT
      ELSEIF nLen > 0
         cSend := SubStr( cSend, nLen + 1 )
      ENDIF
   ENDDO

RETURN NIL

STATIC FUNCTION MCP_Http_Join( aItems, cSep )
   LOCAL cOut := "", nX

   FOR nX := 1 TO Len( aItems )
      IF nX > 1
         cOut += cSep
      ENDIF
      cOut += aItems[nX]
   NEXT

RETURN cOut

STATIC FUNCTION MCP_Http_StatusText( nStatus )
   LOCAL cText

   DO CASE
   CASE nStatus == 200 ; cText := "OK"
   CASE nStatus == 202 ; cText := "Accepted"
   CASE nStatus == 204 ; cText := "No Content"
   CASE nStatus == 400 ; cText := "Bad Request"
   CASE nStatus == 403 ; cText := "Forbidden"
   CASE nStatus == 404 ; cText := "Not Found"
   CASE nStatus == 405 ; cText := "Method Not Allowed"
   CASE nStatus == 201 ; cText := "Created"
   CASE nStatus == 302 ; cText := "Found"
   CASE nStatus == 401 ; cText := "Unauthorized"
   CASE nStatus == 500 ; cText := "Internal Server Error"
   OTHERWISE           ; cText := "OK"
   ENDCASE

RETURN cText

//===========================================================================
// OAuth 2.1 layer (auto-approve shim)
//
// Claude's remote-connector flow requires OAuth with Dynamic Client
// Registration. This server has no real user login, so it implements the
// standard endpoints as an *auto-approve* shim: it advertises the discovery
// metadata (RFC 9728 + RFC 8414), accepts any client at /register (RFC 7591),
// auto-approves /authorize with PKCE (S256), and issues signed JWT access /
// refresh tokens at /token. Every artefact (client_id, authorization code,
// tokens) is a self-contained JWT signed with the keychain secret
// MCP_OAUTH_KEY, so the server keeps NO in-memory OAuth state and survives a
// restart (clients only re-run the silent OAuth dance).
//
// SECURITY: this grants a token to anyone who can reach the endpoint. The
// real access boundary is the network / reverse proxy in front of it - keep
// the listener bound to localhost and the public port protected. To turn the
// layer off entirely (pure authless server) start with MCP_Http(,,.F.) or set
// the config key MCP_HTTP_OAUTH=0.
//===========================================================================

// Default OAuth on unless the persisted value MCP_HTTP_OAUTH is set to .F.
// GetValue() reads the "values" table, never throws on a missing key, and
// creates the key with the given default the first time it is read.
STATIC FUNCTION MCP_Http_OAuthDefault()
   LOCAL xVal := GetValue( "MCP_HTTP_OAUTH", .T., "MCP HTTP server: enable OAuth 2.1 layer (.T./.F.)" )

   IF ValType( xVal ) == "L"
      RETURN xVal
   ELSEIF ValType( xVal ) == "N"
      RETURN xVal != 0
   ENDIF

RETURN .T.

// True if the JWT signing secret is available (keychain entry present).
STATIC FUNCTION MCP_OAuth_SecretReady()
   LOCAL cTok := ""

   BEGIN SEQUENCE
      cTok := JWT_Encode( { "typ" => "probe", "exp" => JWT_CurrentTimestamp() + 60 }, MCP_OAUTH_KEY )
   RECOVER
      cTok := ""
   END SEQUENCE

RETURN ! Empty( cTok )

// Validate a Bearer access token on the MCP endpoint.
STATIC FUNCTION MCP_OAuth_Authorized( cAuth )
   LOCAL cToken := MCP_OAuth_BearerToken( cAuth )
   LOCAL hClaims

   IF Empty( cToken )
      RETURN .F.
   ENDIF

   hClaims := JWT_Decode( cToken, MCP_OAUTH_KEY )   // verifies signature + exp
   IF ValType( hClaims ) != "H"
      RETURN .F.
   ENDIF

RETURN MCP_Http_HashStr( hClaims, "typ" ) == "access"

STATIC FUNCTION MCP_OAuth_BearerToken( cAuth )
   cAuth := AllTrim( cAuth )
   IF Empty( cAuth )
      RETURN ""
   ENDIF
   IF Upper( Left( cAuth, 7 ) ) == "BEARER "
      RETURN AllTrim( SubStr( cAuth, 8 ) )
   ENDIF
RETURN ""

// Protected Resource Metadata (RFC 9728).
STATIC FUNCTION MCP_OAuth_ProtectedResourceMeta( cBase )
   LOCAL h := {=>}

   h["resource"] := cBase + "/"
   h["authorization_servers"] := { cBase }
   h["scopes_supported"] := { "mcp" }
   h["bearer_methods_supported"] := { "header" }

RETURN HB_JsonEncode( h )

// Authorization Server Metadata (RFC 8414).
STATIC FUNCTION MCP_OAuth_AuthServerMeta( cBase )
   LOCAL h := {=>}

   h["issuer"] := cBase
   h["authorization_endpoint"] := cBase + "/authorize"
   h["token_endpoint"] := cBase + "/token"
   h["registration_endpoint"] := cBase + "/register"
   h["response_types_supported"] := { "code" }
   h["grant_types_supported"] := { "authorization_code", "refresh_token" }
   h["code_challenge_methods_supported"] := { "S256" }
   h["token_endpoint_auth_methods_supported"] := { "none" }
   h["scopes_supported"] := { "mcp" }

RETURN HB_JsonEncode( h )

// Encode the registered redirect_uris into the client_id itself (a JWT), so
// /authorize can validate redirect_uri statelessly.
STATIC FUNCTION MCP_OAuth_MakeClientId( aRedirectUris )
   LOCAL h := {=>}

   IF ValType( aRedirectUris ) != "A"
      aRedirectUris := {}
   ENDIF

   h["typ"] := "client"
   h["ruris"] := aRedirectUris
   h["iat"] := JWT_CurrentTimestamp()
   // No exp -> the client_id does not expire.

RETURN JWT_Encode( h, MCP_OAUTH_KEY )

// Dynamic Client Registration (RFC 7591): accept and echo, auto-approve.
STATIC FUNCTION MCP_OAuth_Register( hSocket, cBody, aCors )
   LOCAL hReq, aRuris := {}, cClientId, hResp := {=>}

   hReq := HB_JsonDecode( cBody )
   IF ValType( hReq ) == "H" .AND. HHasKey( hReq, "redirect_uris" ) .AND. ValType( hReq["redirect_uris"] ) == "A"
      aRuris := hReq["redirect_uris"]
   ENDIF

   cClientId := MCP_OAuth_MakeClientId( aRuris )
   IF Empty( cClientId )
      MCP_OAuth_ErrJson( hSocket, 500, "server_error", "OAuth secret not configured", aCors )
      RETURN NIL
   ENDIF

   hResp["client_id"] := cClientId
   hResp["token_endpoint_auth_method"] := "none"
   hResp["grant_types"] := { "authorization_code", "refresh_token" }
   hResp["response_types"] := { "code" }
   hResp["redirect_uris"] := aRuris

   MCP_Http_Send( hSocket, 201, "application/json", HB_JsonEncode( hResp ), aCors )

RETURN NIL

// Authorization endpoint: auto-approve and redirect back with an auth code.
STATIC FUNCTION MCP_OAuth_Authorize( hSocket, cQuery, aCors )
   LOCAL h := MCP_OAuth_ParseForm( cQuery )
   LOCAL cClientId, cRedirect, cState, cChallenge, cMethod, cCode
   LOCAL hClient, aRuris, cLoc, hCode, nX, lOk

   cClientId  := MCP_Http_HashStr( h, "client_id" )
   cRedirect  := MCP_Http_HashStr( h, "redirect_uri" )
   cState     := MCP_Http_HashStr( h, "state" )
   cChallenge := MCP_Http_HashStr( h, "code_challenge" )
   cMethod    := MCP_Http_HashStr( h, "code_challenge_method" )

   hClient := JWT_Decode( cClientId, MCP_OAUTH_KEY )
   IF ValType( hClient ) != "H" .OR. MCP_Http_HashStr( hClient, "typ" ) != "client"
      MCP_Http_Send( hSocket, 400, "text/plain", "invalid_client", aCors )
      RETURN NIL
   ENDIF

   IF Empty( cRedirect )
      MCP_Http_Send( hSocket, 400, "text/plain", "invalid_request: redirect_uri required", aCors )
      RETURN NIL
   ENDIF

   // redirect_uri must be one the client registered (open-redirect guard).
   aRuris := IIF( HHasKey( hClient, "ruris" ) .AND. ValType( hClient["ruris"] ) == "A", hClient["ruris"], {} )
   IF Len( aRuris ) > 0
      lOk := .F.
      FOR nX := 1 TO Len( aRuris )
         IF ValType( aRuris[nX] ) == "C" .AND. aRuris[nX] == cRedirect
            lOk := .T.
            EXIT
         ENDIF
      NEXT
      IF ! lOk
         MCP_Http_Send( hSocket, 400, "text/plain", "invalid_request: redirect_uri not registered", aCors )
         RETURN NIL
      ENDIF
   ENDIF

   // PKCE is mandatory; only S256 is supported.
   IF Empty( cChallenge ) .OR. cMethod != "S256"
      MCP_Http_SendRedirect( hSocket, MCP_OAuth_RedirectError( cRedirect, "invalid_request", cState ), aCors )
      RETURN NIL
   ENDIF

   // Auto-approve: issue a short-lived authorization code (JWT).
   hCode := {=>}
   hCode["typ"] := "code"
   hCode["ruri"] := cRedirect
   hCode["cc"] := cChallenge
   hCode["exp"] := JWT_CurrentTimestamp() + 300
   cCode := JWT_Encode( hCode, MCP_OAUTH_KEY )

   cLoc := cRedirect + IIF( At( "?", cRedirect ) > 0, "&", "?" ) + "code=" + MCP_Http_UrlEncode( cCode )
   IF ! Empty( cState )
      cLoc += "&state=" + MCP_Http_UrlEncode( cState )
   ENDIF

   MCP_Http_SendRedirect( hSocket, cLoc, aCors )

RETURN NIL

// Token endpoint: authorization_code (with PKCE) and refresh_token grants.
STATIC FUNCTION MCP_OAuth_Token( hSocket, cBody, aCors )
   LOCAL h, cGrant
   LOCAL cCode, cVerifier, cRedirect, cRefresh
   LOCAL hCode, hRt, hResp

   h := MCP_OAuth_ParseForm( cBody )
   // Some clients send a JSON body instead of form-encoded.
   IF Empty( MCP_Http_HashStr( h, "grant_type" ) ) .AND. Left( AllTrim( cBody ), 1 ) == "{"
      hResp := HB_JsonDecode( cBody )
      IF ValType( hResp ) == "H"
         h := hResp
      ENDIF
   ENDIF
   cGrant := MCP_Http_HashStr( h, "grant_type" )

   DO CASE
   CASE cGrant == "authorization_code"
      cCode     := MCP_Http_HashStr( h, "code" )
      cVerifier := MCP_Http_HashStr( h, "code_verifier" )
      cRedirect := MCP_Http_HashStr( h, "redirect_uri" )

      hCode := JWT_Decode( cCode, MCP_OAUTH_KEY )       // verifies signature + exp
      IF ValType( hCode ) != "H" .OR. MCP_Http_HashStr( hCode, "typ" ) != "code"
         MCP_OAuth_ErrJson( hSocket, 400, "invalid_grant", "invalid or expired code", aCors )
         RETURN NIL
      ENDIF
      IF ! Empty( MCP_Http_HashStr( hCode, "ruri" ) ) .AND. cRedirect != MCP_Http_HashStr( hCode, "ruri" )
         MCP_OAuth_ErrJson( hSocket, 400, "invalid_grant", "redirect_uri mismatch", aCors )
         RETURN NIL
      ENDIF
      IF Empty( cVerifier ) .OR. MCP_Http_HashStr( hCode, "cc" ) != MCP_OAuth_PkceS256( cVerifier )
         MCP_OAuth_ErrJson( hSocket, 400, "invalid_grant", "PKCE verification failed", aCors )
         RETURN NIL
      ENDIF

      MCP_Http_Send( hSocket, 200, "application/json", HB_JsonEncode( MCP_OAuth_IssueTokens( .T. ) ), aCors )

   CASE cGrant == "refresh_token"
      cRefresh := MCP_Http_HashStr( h, "refresh_token" )
      hRt := JWT_Decode( cRefresh, MCP_OAUTH_KEY )
      IF ValType( hRt ) != "H" .OR. MCP_Http_HashStr( hRt, "typ" ) != "refresh"
         MCP_OAuth_ErrJson( hSocket, 400, "invalid_grant", "invalid refresh token", aCors )
         RETURN NIL
      ENDIF

      MCP_Http_Send( hSocket, 200, "application/json", HB_JsonEncode( MCP_OAuth_IssueTokens( .T. ) ), aCors )

   OTHERWISE
      MCP_OAuth_ErrJson( hSocket, 400, "unsupported_grant_type", cGrant, aCors )
   ENDCASE

RETURN NIL

// Build the token response (signed JWT access token, optional refresh token).
STATIC FUNCTION MCP_OAuth_IssueTokens( lWithRefresh )
   LOCAL nNow := JWT_CurrentTimestamp()
   LOCAL hResp := {=>}
   LOCAL hAccess := {=>}, hRefresh := {=>}

   hAccess["typ"] := "access"
   hAccess["iat"] := nNow
   hAccess["exp"] := nNow + 3600           // 1 hour
   hAccess["scope"] := "mcp"

   hResp["access_token"] := JWT_Encode( hAccess, MCP_OAUTH_KEY )
   hResp["token_type"] := "Bearer"
   hResp["expires_in"] := 3600
   hResp["scope"] := "mcp"

   IF lWithRefresh
      hRefresh["typ"] := "refresh"
      hRefresh["iat"] := nNow
      hRefresh["exp"] := nNow + 2592000    // 30 days
      hResp["refresh_token"] := JWT_Encode( hRefresh, MCP_OAUTH_KEY )
   ENDIF

RETURN hResp

// PKCE S256 transform: BASE64URL( SHA256( verifier ) ).
STATIC FUNCTION MCP_OAuth_PkceS256( cVerifier )
RETURN Base64UrlEncode( hb_SHA256( cVerifier, .T. ) )

STATIC FUNCTION MCP_OAuth_RedirectError( cRedirect, cErr, cState )
   LOCAL cLoc := cRedirect + IIF( At( "?", cRedirect ) > 0, "&", "?" ) + "error=" + MCP_Http_UrlEncode( cErr )
   IF ! Empty( cState )
      cLoc += "&state=" + MCP_Http_UrlEncode( cState )
   ENDIF
RETURN cLoc

STATIC FUNCTION MCP_OAuth_ErrJson( hSocket, nStatus, cErr, cDesc, aCors )
   LOCAL h := {=>}
   h["error"] := cErr
   IF ! Empty( cDesc )
      h["error_description"] := cDesc
   ENDIF
   MCP_Http_Send( hSocket, nStatus, "application/json", HB_JsonEncode( h ), aCors )
RETURN NIL

STATIC FUNCTION MCP_Http_SendRedirect( hSocket, cLocation, aHeaders )
   LOCAL a := {}, nX
   FOR nX := 1 TO Len( aHeaders )
      AAdd( a, aHeaders[nX] )
   NEXT
   AAdd( a, "Location: " + cLocation )
   MCP_Http_Send( hSocket, 302, "", "", a )
RETURN NIL

//---------------------------------------------------------------------------
// Small HTTP / string helpers
//---------------------------------------------------------------------------

// Public base URL for the metadata documents. Prefers the configured override,
// then the proxy's forwarded headers, then the Host header.
STATIC FUNCTION MCP_Http_BaseUrl( hHeaders )
   LOCAL cProto, cHost

   IF ! Empty( s_cMcpPublicUrl )
      RETURN MCP_Http_TrimSlash( s_cMcpPublicUrl )
   ENDIF

   cProto := MCP_Http_HashStr( hHeaders, "X-FORWARDED-PROTO" )
   IF Empty( cProto )
      cProto := "https"
   ENDIF
   IF At( ",", cProto ) > 0
      cProto := AllTrim( Left( cProto, At( ",", cProto ) - 1 ) )
   ENDIF

   cHost := MCP_Http_HashStr( hHeaders, "X-FORWARDED-HOST" )
   IF Empty( cHost )
      cHost := MCP_Http_HashStr( hHeaders, "HOST" )
   ENDIF
   IF Empty( cHost )
      cHost := "localhost"
   ENDIF

RETURN cProto + "://" + cHost

STATIC FUNCTION MCP_Http_TrimSlash( c )
   DO WHILE Len( c ) > 0 .AND. Right( c, 1 ) == "/"
      c := Left( c, Len( c ) - 1 )
   ENDDO
RETURN c

STATIC FUNCTION MCP_Http_StartsWith( cStr, cPrefix )
RETURN Left( cStr, Len( cPrefix ) ) == cPrefix

// Safe hash -> string accessor.
STATIC FUNCTION MCP_Http_HashStr( h, cKey )
   IF ValType( h ) == "H" .AND. HHasKey( h, cKey ) .AND. ValType( h[cKey] ) == "C"
      RETURN h[cKey]
   ENDIF
RETURN ""

// Parse an application/x-www-form-urlencoded string (also used for query
// strings) into a hash of decoded key/value pairs.
STATIC FUNCTION MCP_OAuth_ParseForm( cData )
   LOCAL h := {=>}, aPairs, nX, nEq, cPair

   IF Empty( cData )
      RETURN h
   ENDIF

   aPairs := hb_ATokens( cData, "&" )
   FOR nX := 1 TO Len( aPairs )
      cPair := aPairs[nX]
      IF Empty( cPair )
         LOOP
      ENDIF
      nEq := At( "=", cPair )
      IF nEq > 0
         h[ MCP_Http_UrlDecode( Left( cPair, nEq - 1 ) ) ] := MCP_Http_UrlDecode( SubStr( cPair, nEq + 1 ) )
      ELSE
         h[ MCP_Http_UrlDecode( cPair ) ] := ""
      ENDIF
   NEXT

RETURN h

STATIC FUNCTION MCP_Http_UrlDecode( cStr )
   LOCAL cOut := "", nX := 1, nLen := Len( cStr ), c

   DO WHILE nX <= nLen
      c := SubStr( cStr, nX, 1 )
      DO CASE
      CASE c == "+"
         cOut += " "
      CASE c == "%" .AND. nX + 2 <= nLen
         cOut += Chr( MCP_Http_Hex2( SubStr( cStr, nX + 1, 2 ) ) )
         nX += 2
      OTHERWISE
         cOut += c
      ENDCASE
      nX++
   ENDDO

RETURN cOut

STATIC FUNCTION MCP_Http_UrlEncode( cStr )
   LOCAL cOut := "", nX, c

   FOR nX := 1 TO Len( cStr )
      c := SubStr( cStr, nX, 1 )
      IF ( c >= "A" .AND. c <= "Z" ) .OR. ( c >= "a" .AND. c <= "z" ) .OR. ( c >= "0" .AND. c <= "9" ) ;
         .OR. c == "-" .OR. c == "_" .OR. c == "." .OR. c == "~"
         cOut += c
      ELSE
         cOut += "%" + MCP_Http_Num2Hex( Asc( c ) )
      ENDIF
   NEXT

RETURN cOut

STATIC FUNCTION MCP_Http_Hex2( cHex )
   LOCAL nVal := 0, nX, nD

   FOR nX := 1 TO Len( cHex )
      nD := At( Upper( SubStr( cHex, nX, 1 ) ), "0123456789ABCDEF" ) - 1
      IF nD < 0
         nD := 0
      ENDIF
      nVal := nVal * 16 + nD
   NEXT

RETURN nVal

STATIC FUNCTION MCP_Http_Num2Hex( n )
   LOCAL cHex := "0123456789ABCDEF"
RETURN SubStr( cHex, Int( n / 16 ) + 1, 1 ) + SubStr( cHex, ( n % 16 ) + 1, 1 )

// Pull in the shared dispatch (ProcessMCPRequest / CreateErrorResponse and all
// MCP_Tool_* implementations) so this file compiles as a standalone unit.
#include 'mcp_stdio.prg'
