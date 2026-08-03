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

STATIC s_nMcpSessionSeq  := 0     // monotonic counter for session-id uniqueness
STATIC s_lMcpHttpStop    := .F.   // set when a "shutdown" request arrives
STATIC s_lMcpHttpVerbose := .T.   // per-request console logging on/off
STATIC s_cMcpLogSink     := ""    // "QOUT" or "STDERR"; decided from the GT on first use
STATIC s_hMcpKeys        := NIL   // API-key table from mcp_keys.json (NIL = auth disabled)
STATIC s_cMcpKeysStamp   := ""    // file stamp of the loaded key table
STATIC s_lMcpAuthWarned  := .F.   // "running without authentication" warned once
STATIC s_cMcpSrcStamp    := ""    // stamp of the MCP source files for auto-reload
STATIC s_lMcpQuietReq    := .F.   // current request is routine "/" traffic in GUI mode - suppress 2xx response log
STATIC s_hMcpClients     := {=>}  // connected-client overview, keyed by session id (fallback peer#user)
STATIC s_nSlashHits      := 0     // GET / (health/stream) pings since the last stats flush
STATIC s_nSlashSince     := -1    // Seconds() baseline for the slash-rate log (-1 = unset)
STATIC s_nLastReloadCheck := -1   // Seconds() of the last source-stamp check (-1 = unset)
STATIC s_nReqUser        := 0     // current request's authenticated user (fed into client tracking)
STATIC s_cReqName        := ""    // current request's user name
STATIC s_cReqPeer        := ""    // current request's peer address

FUNCTION MCP_Http( nPort, cBindAddr, lVerbose, lAutoReload )
   LOCAL nStdErr := hb_GetStdErr()
   LOCAL hListen, hSocket
   LOCAL lRestart := .F.

   IF nPort == NIL
      nPort := McpHttpPort()
   ENDIF
   IF lVerbose == NIL
      lVerbose := .T.
   ENDIF
   IF lAutoReload == NIL
      lAutoReload := .T.
   ENDIF
   s_lMcpHttpVerbose := lVerbose
   // NOTE: cBindAddr is accepted for signature compatibility but not used - this
   // build's hb_InetServer binds all interfaces (see below).

   // Same guard as the STDIO server: never let a hook / error handler pop a
   // modal Alert/MsgBox that would block the request loop forever.
   SetConfigValue("BATCHMODE", .T.)

   hb_InetInit()

   // Use the single-argument form proven in this build (terminalserver.prg,
   // uhttpd.prg). It binds all interfaces; the 3-arg (bind-address) form does
   // NOT work here and produced a listener that accepted connections but never
   // answered (clients timed out). Restrict exposure at the firewall/proxy.
   hListen := hb_InetServer( nPort )
   IF hListen == NIL .OR. hb_InetErrorCode( hListen ) != 0
      FWrite( nStdErr, "MCP_Http: cannot listen on port " + LTrim(Str(nPort)) + Chr(10) )
      hb_InetCleanup()
      IF MCP_Http_LogSink() == "QOUT"
         Alert( "MCP_Http: cannot listen on port " + LTrim(Str(nPort)) )
      ENDIF
      RETURN NIL
   ENDIF

   // Make accept() return every second so the loop can honour the stop flag
   // and (under a GUI GT such as GTWVG) pump window messages via Inkey().
   hb_InetTimeout( hListen, 1000 )

   MCP_Http_Log( "Listening on port " + LTrim(Str(nPort)) + " (all interfaces, Streamable HTTP)" )
   IF MCP_Http_LogSink() == "QOUT"
      MCP_Http_Log( "Taste 'C' zeigt eine Uebersicht der aktuell verbundenen Clients" )
   ENDIF

   // Auto-reload: remember the source stamp; when mcp_http.prg/mcp_stdio.prg
   // change on disk the server relaunches itself with the same command line.
   IF lAutoReload
      s_cMcpSrcStamp := MCP_Http_SourceStamp()
      IF Empty( s_cMcpSrcStamp )
         MCP_Http_Log( "Auto-Reload: Quelldateien nicht gefunden - Ueberwachung inaktiv" )
      ELSE
         MCP_Http_Log( "Auto-Reload aktiv (mcp_http.prg / mcp_stdio.prg)" )
      ENDIF
   ENDIF

   s_lMcpHttpStop := .F.

   DO WHILE ! s_lMcpHttpStop
      hSocket := hb_InetAccept( hListen )
      IF hSocket == NIL
         // Accept timed out (no pending connection) - keep the UI responsive
         // and handle a 'C' keypress (connected-client overview).
         MCP_Http_PumpKeys()
         MCP_Http_MaybeReload( nPort, lAutoReload, @hListen, @lRestart )
         LOOP
      ENDIF

      // Bound how long one (possibly stalled) client can occupy the
      // single-threaded loop: each socket read/write times out after 10s.
      hb_InetTimeout( hSocket, 10000 )

      BEGIN SEQUENCE
         MCP_Http_ServeConnection( hSocket )
      RECOVER
         // A single bad connection must never take the whole server down.
         MCP_Http_Log( "  !! Fehler bei der Verarbeitung - Verbindung wird geschlossen" )
      END SEQUENCE

      hb_InetClose( hSocket )

      // Keys AND the reload check also run between requests, so that under a
      // steady request stream (when the idle branch above is never reached)
      // 'C' still responds and a source change is still picked up. Both are
      // safe here - we are between requests, never inside a tool call.
      MCP_Http_PumpKeys()
      MCP_Http_MaybeReload( nPort, lAutoReload, @hListen, @lRestart )
   ENDDO

   IF hListen != NIL
      hb_InetClose( hListen )
   ENDIF
   hb_InetCleanup()
   dbCloseAll()

   IF lRestart
      MCP_Http_Log( "Alte Instanz wird beendet." )
      QUIT
   ENDIF
   

RETURN NIL

// Combined date/time/size stamp of the MCP source files. mcp_stdio.prg is
// watched too because it is #included into the HTTP build.
STATIC FUNCTION MCP_Http_SourceStamp()
   LOCAL cStamp := "", aDir, cFile

   FOR EACH cFile IN { Path( "run\mcp_http.prg" ), Path( "run\mcp_stdio.prg" ) }
      aDir := Directory( cFile )
      IF Len( aDir ) > 0
         cStamp += DToS( aDir[1][3] ) + aDir[1][4] + LTrim( Str( aDir[1][2] ) ) + ";"
      ENDIF
   NEXT
RETURN cStamp

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

//---------------------------------------------------------------------------
// Per-user API-key authentication (Option: keys instead of OAuth).
//
// Keys live in mcp_keys.json in the DATA directory:
//    { "keys": { "<random-key>": {"user": 5, "name": "Amos"},
//                "<other-key>":  7 } }
// "user" is the Trader user (buyer) record number. While the file is missing
// or contains no keys the server runs OPEN (as before) and logs a warning, so
// rollout cannot lock anybody out. The table is cached and reloaded when the
// file changes.
//
// On each authenticated POST the Trader user context (trader.ini entry 28,
// i.e. DNUM) is switched to the key's user for the duration of the request -
// SystemUser() reloads automatically on change (model/user.prg), so the
// existing per-user permission checks apply. This is safe precisely because
// the server is single threaded: requests never overlap.
//---------------------------------------------------------------------------

// The key file lives in the config folder below the data path. Protect it
// with an ACL so only the Windows account running the server can read it.
STATIC FUNCTION MCP_Http_KeysFile()
RETURN Path("config\mcp_keys.json")

// Load/refresh the key table; cached until the file's timestamp changes.
STATIC FUNCTION MCP_Http_LoadKeys()
   LOCAL cFile := MCP_Http_KeysFile()
   LOCAL aDir, cStamp, hData

   aDir := Directory( cFile )
   IF Len( aDir ) == 0
      s_hMcpKeys := NIL          // no file - authentication disabled
      s_cMcpKeysStamp := ""
      RETURN NIL
   ENDIF
   cStamp := DToS( aDir[1][3] ) + aDir[1][4] + LTrim( Str( aDir[1][2] ) )
   IF s_hMcpKeys != NIL .AND. cStamp == s_cMcpKeysStamp
      RETURN s_hMcpKeys
   ENDIF

   hData := hb_jsonDecode( hb_MemoRead( cFile ) )
   IF HB_IsHash( hData ) .AND. HHasKey( hData, "keys" ) .AND. HB_IsHash( hData["keys"] ) .AND. Len( hData["keys"] ) > 0
      s_hMcpKeys := hData["keys"]
      MCP_Http_Log( "API-Schluessel geladen: " + LTrim( Str( Len( s_hMcpKeys ) ) ) + " Eintraege" )
   ELSE
      s_hMcpKeys := NIL
      MCP_Http_Log( "WARNUNG: " + cFile + " enthaelt keine nutzbare 'keys'-Tabelle - Authentifizierung inaktiv" )
   ENDIF
   s_cMcpKeysStamp := cStamp
RETURN s_hMcpKeys

// Check the Authorization header against the key table and resolve the
// Trader user. Returns NIL when the request may proceed (nUser/cUserName by
// reference; nUser stays 0 when authentication is disabled), otherwise the
// error text for the 401 response.
STATIC FUNCTION MCP_Http_Auth( hHeaders, cUrlKey, nUser, cUserName )
   LOCAL hKeys := MCP_Http_LoadKeys()
   LOCAL cAuth, cApiKey, xEntry

   nUser := 0
   cUserName := ""

   IF hKeys == NIL
      IF ! s_lMcpAuthWarned
         s_lMcpAuthWarned := .T.
         MCP_Http_Log( "WARNUNG: kein " + MCP_Http_KeysFile() + " - Server laeuft OHNE Authentifizierung" )
      ENDIF
      RETURN NIL              // open mode
   ENDIF

   cAuth := IIF( HHasKey( hHeaders, "AUTHORIZATION" ), AllTrim( hHeaders["AUTHORIZATION"] ), "" )
   IF Upper( Left( cAuth, 7 ) ) == "BEARER "
      cApiKey := AllTrim( SubStr( cAuth, 8 ) )
   ELSE
      cApiKey := cAuth        // accept a bare key as well
   ENDIF
   IF Empty( cApiKey ) .AND. ValType( cUrlKey ) == "C" .AND. ! Empty( cUrlKey )
      cApiKey := cUrlKey      // fallback: ?key=... in the URL (see ServeConnection)
   ENDIF
   IF Empty( cApiKey ) .OR. ! HHasKey( hKeys, cApiKey )
      RETURN "Invalid or missing API key"
   ENDIF

   xEntry := hKeys[cApiKey]
   DO CASE
   CASE HB_IsNumeric( xEntry )
      nUser := xEntry
   CASE HB_IsHash( xEntry ) .AND. HHasKey( xEntry, "user" ) .AND. HB_IsNumeric( xEntry["user"] )
      nUser := xEntry["user"]
      IF HHasKey( xEntry, "name" ) .AND. ValType( xEntry["name"] ) == "C"
         cUserName := xEntry["name"]
      ENDIF
   ENDCASE
   IF nUser <= 0
      RETURN "API key has no valid user mapping"
   ENDIF

   // The mapped user must exist and be active
   NetUse( "buyer", "buy" )
   buy->(DbGoTo( nUser ))
   IF buy->(Eof()) .OR. ! buy->Aktive
      nUser := 0
      RETURN "API key maps to an unknown or inactive user"
   ENDIF
   IF Empty( cUserName )
      cUserName := AllTrim( buy->Buyer )
   ENDIF
RETURN NIL

// Reduce wire data to printable ASCII for log output: control and high-bit
// bytes become "?", overlong input is truncated. Keeps binary garbage (port
// scanners, TLS handshakes) from corrupting the console.
STATIC FUNCTION MCP_Http_Printable( cStr )
   LOCAL cOut := "", nX, cChar
   LOCAL nMax := Min( Len( cStr ), 120 )
   FOR nX := 1 TO nMax
      cChar := SubStr( cStr, nX, 1 )
      cOut += IIF( Asc( cChar ) >= 32 .AND. Asc( cChar ) <= 126, cChar, "?" )
   NEXT
   IF Len( cStr ) > nMax
      cOut += "...(" + LTrim( Str( Len( cStr ) ) ) + " bytes)"
   ENDIF
RETURN cOut

// Read and answer exactly one HTTP request on hSocket.
STATIC FUNCTION MCP_Http_ServeConnection( hSocket )
   LOCAL nLen, cReqLine, cPath
   LOCAL aLines, aReq, nX, cLine, nColon, nQ
   LOCAL hHeaders := {=>}
   LOCAL cHttpMethod, cKey, cVal
   LOCAL nCL, cBody, cBuf, nGot
   LOCAL cOrigin, cSessionId
   LOCAL aCors
   LOCAL cAuthErr, nAuthUser := 0, cAuthName := ""
   LOCAL nOldUser, oHttpErr
   LOCAL cUrlKey := "", cQPart
   LOCAL lQuiet, cPeer

   // In GUI mode (QOUT log sink) the routine "/" traffic is not logged - it
   // would flood the visible console. Warnings, errors and requests to other
   // paths stay visible; the stderr sink keeps logging everything.
   lQuiet := ( MCP_Http_LogSink() == "QOUT" )
   cPeer := MCP_Http_Peer( hSocket )
   s_lMcpQuietReq := .F.  // set once the path is known; early sends stay logged

   // Request context for the connected-client overview (see MCP_Http_TrackClient).
   // Peer is known now; the user/name follow once authentication succeeds.
   s_cReqPeer := cPeer
   s_nReqUser := 0
   s_cReqName := ""

   IF ! lQuiet
      MCP_Http_Log( "Eingehende Verbindung von " + cPeer )
   ENDIF

   // ---- Read request line + headers, one line at a time, up to the blank
   // line. hb_InetRecvLine is the recv primitive proven to work in this build
   // (terminalserver.prg); hb_InetRecvEndBlock did not read anything here.
   aLines := {}
   DO WHILE Len( aLines ) < 200
      cLine := hb_InetRecvLine( hSocket, @nLen )
      IF ValType( cLine ) != "C" .OR. nLen < 0
         EXIT                              // error / connection closed
      ENDIF
      IF Right( cLine, 1 ) == Chr(13)      // strip a trailing CR if present
         cLine := Left( cLine, Len( cLine ) - 1 )
      ENDIF
      IF Empty( cLine )                    // blank line -> end of headers
         EXIT
      ENDIF
      AAdd( aLines, cLine )
   ENDDO

   IF Len( aLines ) < 1
      MCP_Http_Log( "  (keine Request-Daten empfangen)" )
      RETURN NIL
   ENDIF

   cReqLine := aLines[1]

   // A TLS ClientHello starts with the handshake record type 0x16: the client
   // is speaking https:// against this plain-HTTP port. Say so clearly instead
   // of spraying binary data into the log, and just close - a TLS client
   // cannot read a plaintext answer anyway.
   IF Left( cReqLine, 1 ) == Chr(22)
      MCP_Http_Log( "  TLS-Handshake auf Klartext-Port erkannt - Client verwendet https:// statt http:// " + ;
                    "(oder direkt statt ueber den Proxy). Verbindung geschlossen." + IIF( lQuiet, " [" + cPeer + "]", "" ) )
      RETURN NIL
   ENDIF

   aReq := hb_ATokens( cReqLine, " " )
   IF Len(aReq) < 2
      MCP_Http_Log( "  Keine gueltige HTTP-Request-Zeile: " + MCP_Http_Printable( cReqLine ) + IIF( lQuiet, " [" + cPeer + "]", "" ) )
      MCP_Http_Send( hSocket, 400, "text/plain", "Bad Request", {} )
      RETURN NIL
   ENDIF
   cHttpMethod := Upper( aReq[1] )
   cPath := aReq[2]
   nQ := At( "?", cPath )
   IF nQ > 0
      // Extract a ?key=... query parameter as an alternative way to pass the
      // API key: clients like mcp-remote mangle --header arguments on Windows,
      // a key in the URL avoids headers (and thus the 401/OAuth path) fully.
      FOR EACH cQPart IN hb_ATokens( SubStr( cPath, nQ + 1 ), "&" )
         IF Upper( Left( cQPart, 4 ) ) == "KEY="
            cUrlKey := AllTrim( SubStr( cQPart, 5 ) )
         ENDIF
      NEXT
      cPath := Left( cPath, nQ - 1 )
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
   aCors      := MCP_Http_CorsHeaders( cOrigin, hHeaders )

   // Routine "/" traffic in GUI mode: also mute the 2xx response log lines
   // written by MCP_Http_Send (errors are always logged there).
   s_lMcpQuietReq := lQuiet .AND. cPath == "/"

   // Log the request line (method, path, and body size for POST). All parts
   // come from the wire - print them filtered so binary/garbage input cannot
   // corrupt the console. Routine "/" calls are hidden in GUI mode.
   IF ! lQuiet .OR. ! ( cPath == "/" )
      MCP_Http_Log( "  " + MCP_Http_Printable( cHttpMethod + " " + cPath ) + ;
         IIF( HHasKey(hHeaders, "CONTENT-LENGTH"), " [" + MCP_Http_Printable(AllTrim(hHeaders["CONTENT-LENGTH"])) + " bytes]", "" ) + ;
         IIF( ! Empty(cOrigin), " origin=" + MCP_Http_Printable(cOrigin), "" ) )
   ENDIF

   // ---- Route by HTTP method -------------------------------------------

   // CORS preflight.
   IF cHttpMethod == "OPTIONS"
      MCP_Http_Send( hSocket, 204, "", "", aCors )
      RETURN NIL
   ENDIF

   // GET: health probes answer 200; a client opening the optional MCP
   // server->client SSE stream (Accept: text/event-stream) gets 405, because
   // this is single-response mode. Answering that stream GET with 200 "ok"
   // made some clients treat the stream as broken and retry in a loop - a
   // source of the "very many GET / requests" seen in the log.
   IF cHttpMethod == "GET"
      IF cPath == "/" .OR. cPath == "/health" .OR. cPath == "/healthz"
         s_nSlashHits++      // count health/stream pings for the per-minute stats
      ENDIF
      IF cPath == "/healthz" .OR. cPath == "/health"
         MCP_Http_Send( hSocket, 200, "text/plain", "ok", aCors )
      ELSEIF cPath == "/"
         IF "text/event-stream" $ Lower( IIF( HHasKey(hHeaders, "ACCEPT"), hHeaders["ACCEPT"], "" ) )
            AAdd( aCors, "Allow: POST, OPTIONS" )
            MCP_Http_Send( hSocket, 405, "text/plain", "Method Not Allowed (no SSE stream)", aCors )
         ELSE
            MCP_Http_Send( hSocket, 200, "text/plain", "ok", aCors )
         ENDIF
      ELSE
         // Single response mode does not offer a server -> client SSE stream.
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

   // ---- POST: this is a JSON-RPC message -------------------------------

   // Origin check (defence in depth against DNS-rebinding for browser clients).
   IF ! MCP_Http_OriginAllowed( cOrigin )
      MCP_Http_Send( hSocket, 403, "text/plain", "Forbidden origin", aCors )
      RETURN NIL
   ENDIF

   // Only "/" is the MCP endpoint. Anything else (e.g. the OAuth endpoints
   // /register etc. that mcp-remote probes after a 401) gets an explicit 404
   // so OAuth-capable clients conclude "not supported" instead of looping
   // through our auth with unparseable results.
   IF ! ( cPath == "/" )
      MCP_Http_Send( hSocket, 404, "application/json", ;
         hb_jsonEncode( {"error"=>"not_found", "error_description"=>"Unknown endpoint - the MCP endpoint is /"} ), aCors )
      RETURN NIL
   ENDIF

   // Read the body according to Content-Length.
   nCL := 0
   IF HHasKey( hHeaders, "CONTENT-LENGTH" )
      nCL := Val( hHeaders["CONTENT-LENGTH"] )
   ENDIF
   cBody := ""
   IF nCL > 0
      DO WHILE Len( cBody ) < nCL
         cBuf := Space( nCL - Len( cBody ) )
         nGot := hb_InetRecv( hSocket, @cBuf, nCL - Len( cBody ) )
         IF nGot <= 0
            EXIT                           // closed / timeout / error
         ENDIF
         cBody += Left( cBuf, nGot )
      ENDDO
   ENDIF

   // Per-user API-key authentication (mcp_keys.json); see above. The 401 body
   // uses the OAuth Bearer error format of RFC 6750 ({"error": "<string>",
   // "error_description": ...}) - that is what MCP clients like mcp-remote
   // parse on a 401; a JSON-RPC error object here makes them fail ("expected
   // string, received object"). The right client setup is a static header
   // (e.g. mcp-remote --header "Authorization: Bearer <key>").
   cAuthErr := MCP_Http_Auth( hHeaders, cUrlKey, @nAuthUser, @cAuthName )
   IF cAuthErr != NIL
      MCP_Http_Log( "  401: " + cAuthErr + IIF( lQuiet, " [" + cPeer + "]", "" ) )
      AAdd( aCors, 'WWW-Authenticate: Bearer realm="Trader MCP", error="invalid_token", error_description="' + cAuthErr + '"' )
      MCP_Http_Send( hSocket, 401, "application/json", ;
         hb_jsonEncode( {"error"=>"invalid_token", "error_description"=>cAuthErr} ), aCors )
      RETURN NIL
   ENDIF

   // Switch the Trader user context to the authenticated user for this one
   // request; guaranteed to be restored even when the dispatch errors out.
   nOldUser := Tr_GetIni( 28 )
   s_nReqUser := nAuthUser
   s_cReqName := cAuthName
   IF nAuthUser > 0
      Tr_GetIni( 28, nAuthUser )
      IF ! lQuiet
         MCP_Http_Log( "  Benutzer: " + cAuthName + " (" + LTrim( Str( nAuthUser ) ) + ")" )
      ENDIF
   ENDIF
   BEGIN SEQUENCE
      MCP_Http_HandleMessage( hSocket, cBody, cSessionId, aCors )
   RECOVER USING oHttpErr
      Tr_GetIni( 28, nOldUser )
      Break( oHttpErr )
   END SEQUENCE
   Tr_GetIni( 28, nOldUser )

RETURN NIL

// Decode the JSON-RPC body, dispatch it and write the HTTP response.
STATIC FUNCTION MCP_Http_HandleMessage( hSocket, cBody, cSessionId, aCors )
   LOCAL xMsg, hReq, cMethod, cResponse
   LOCAL lIsInitialize, cNewSession
   LOCAL aOut, cItem
   LOCAL aHeaders := {}
   LOCAL nX
   LOCAL nT0, nMs

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
      MCP_Http_Log( "  JSON-RPC Batch mit " + LTrim(Str(Len(xMsg))) + " Nachricht(en)" )
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
         cResponse := "[" + MCP_Http_Join( aOut, "," ) + "]"
         IF Len( cResponse ) > 1000000
            MCP_Http_Log( "  Batch-Antwort zu gross (" + LTrim( Str( Len( cResponse ) ) ) + " bytes) - durch Fehler ersetzt" )
            cResponse := CreateErrorResponse( "Batch response too large for the MCP client buffer", "" )
         ENDIF
         MCP_Http_Send( hSocket, 200, "application/json; charset=utf-8", cResponse, aHeaders )
      ENDIF
      RETURN NIL
   ENDIF

   IF ValType( xMsg ) != "H"
      MCP_Http_Send( hSocket, 400, "application/json", ;
         CreateErrorResponse( "Invalid JSON-RPC message", "" ), aHeaders )
      RETURN NIL
   ENDIF

   hReq := xMsg

   cMethod := IIF( HHasKey(hReq, "method"), hReq["method"], "" )
   MCP_Http_Log( "  JSON-RPC: " + cMethod + MCP_Http_ToolLabel( hReq ) )

   // NOTE: session validation is intentionally NOT enforced. Per the MCP spec
   // it is optional, and this single, stateless server keeps no per-session
   // data. We still ISSUE an Mcp-Session-Id on initialize (some clients want
   // it) but we accept any/none afterwards - rejecting an unrecognised id with
   // 404 only broke clients (e.g. the MCP Inspector's notifications/initialized).

   nT0 := Seconds()
   cResponse := MCP_Http_DispatchOne( hReq, cSessionId, @lIsInitialize, @cNewSession )
   nMs := Int( ( Seconds() - nT0 ) * 1000 )
   IF nMs < 0                       // clock passed midnight during the request
      nMs += 86400000
   ENDIF
   // Surface slow requests - they are what makes a second, queued request time
   // out on this single-threaded server. Only >=1s is logged, to avoid noise.
   IF nMs >= 1000
      MCP_Http_Log( "  langsam: " + cMethod + MCP_Http_ToolLabel( hReq ) + " " + LTrim( Str( nMs ) ) + "ms" )
   ENDIF

   // Record the client for the GUI overview (uses the request context set in
   // ServeConnection). Only real JSON-RPC POSTs reach here - health GETs do not.
   MCP_Http_TrackClient( cSessionId, cNewSession, cMethod )

   // Safety net: a response larger than the MCP client's message buffer
   // (~1 MB) makes the client fail to decode and drop the connection - the
   // whole server then looks "unreachable". Replace an oversized result with a
   // JSON-RPC error so one big tool result can never take the transport down.
   IF ! Empty( cResponse ) .AND. Len( cResponse ) > 1000000
      MCP_Http_Log( "  Antwort zu gross (" + LTrim( Str( Len( cResponse ) ) ) + " bytes) fuer " + ;
         cMethod + MCP_Http_ToolLabel( hReq ) + " - durch Fehler ersetzt" )
      cResponse := CreateErrorResponse( "Response too large (" + LTrim( Str( Len( cResponse ) ) ) + ;
         " bytes) for the MCP client buffer - narrow the query (limit/filters) or fetch large files via their path", ;
         IIF( HHasKey( hReq, "id" ), hReq["id"], "" ) )
   ENDIF

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
   s_nMcpSessionSeq++
RETURN "s" + LTrim( Str( Int( Seconds() * 1000 ) ) ) + "-" + LTrim( Str( s_nMcpSessionSeq ) )

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

// Build the CORS response headers for a request. On a preflight the browser
// lists the headers it intends to send in Access-Control-Request-Headers; we
// echo them back verbatim so ANY header is allowed (e.g. MCP-Protocol-Version,
// Mcp-Session-Id, which recent MCP clients like the Inspector send after
// initialize). Without this the browser blocks the follow-up request and the
// connection "fails" right after the preflight.
STATIC FUNCTION MCP_Http_CorsHeaders( cOrigin, hHeaders )
   LOCAL aHeaders := {}
   LOCAL cReqHeaders := ""

   IF ValType( hHeaders ) == "H" .AND. HHasKey( hHeaders, "ACCESS-CONTROL-REQUEST-HEADERS" )
      cReqHeaders := AllTrim( hHeaders["ACCESS-CONTROL-REQUEST-HEADERS"] )
   ENDIF

   IF Empty( cOrigin )
      AAdd( aHeaders, "Access-Control-Allow-Origin: *" )
   ELSE
      AAdd( aHeaders, "Access-Control-Allow-Origin: " + cOrigin )
   ENDIF
   AAdd( aHeaders, "Access-Control-Allow-Methods: POST, GET, OPTIONS" )
   IF ! Empty( cReqHeaders )
      AAdd( aHeaders, "Access-Control-Allow-Headers: " + cReqHeaders )
   ELSE
      AAdd( aHeaders, "Access-Control-Allow-Headers: Content-Type, Accept, Authorization, Mcp-Session-Id, MCP-Protocol-Version, Last-Event-ID" )
   ENDIF
   AAdd( aHeaders, "Access-Control-Expose-Headers: Mcp-Session-Id, MCP-Protocol-Version" )
   AAdd( aHeaders, "Access-Control-Max-Age: 86400" )

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

   // Success responses of routine "/" requests are muted in GUI mode
   // (s_lMcpQuietReq, see ServeConnection); errors are always logged.
   IF ! s_lMcpQuietReq .OR. nStatus >= 400
      MCP_Http_Log( "  <= " + LTrim(Str(nStatus)) + " " + MCP_Http_StatusText(nStatus) + ;
         " (" + LTrim(Str(Len(cBody))) + " bytes)" )
   ENDIF

   MCP_Http_SendAll( hSocket, cOut )

RETURN NIL

STATIC FUNCTION MCP_Http_SendAll( hSocket, cSend )
   LOCAL nLen

   // Pass the length explicitly, like terminalserver.prg (proven in this build).
   DO WHILE Len( cSend ) > 0
      nLen := hb_InetSendAll( hSocket, cSend, Len( cSend ) )
      IF nLen <= 0
         EXIT                              // error / connection gone
      ENDIF
      cSend := SubStr( cSend, nLen + 1 )
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
   CASE nStatus == 500 ; cText := "Internal Server Error"
   OTHERWISE           ; cText := "OK"
   ENDCASE

RETURN cText

//---------------------------------------------------------------------------
// Console logging helpers
//---------------------------------------------------------------------------

// Write a timestamped diagnostics line. The sink is chosen from the active GT
// (once, cached):
//   - GUI GTs (WVG/WVT/WIN/GUI): QOut, so it shows in the app's window.
//   - everything else (CGI/STD/NUL/...): stderr, because under those GTs QOut
//     goes to stdout, which can block on an unread pipe (or be discarded).
STATIC FUNCTION MCP_Http_Log( cMsg )
   LOCAL cLine

   IF ! s_lMcpHttpVerbose
      RETURN NIL
   ENDIF

   IF Empty( s_cMcpLogSink )
      s_cMcpLogSink := MCP_Http_LogSink()
   ENDIF

   cLine := "[MCP-HTTP " + Time() + "] " + cMsg
   IF s_cMcpLogSink == "QOUT"
      QOut( cLine )
   ELSE
      FWrite( hb_GetStdErr(), cLine + Chr(10) )
   ENDIF

RETURN NIL

// Pick the log sink from the active GT (see MCP_Http_Log).
STATIC FUNCTION MCP_Http_LogSink()
   LOCAL cGt := Upper( AllTrim( hb_gtVersion() ) )

   IF cGt == "WVG" .OR. cGt == "WVT" .OR. cGt == "WIN" .OR. cGt == "GUI"
      RETURN "QOUT"
   ENDIF

RETURN "STDERR"

// Remote peer address of an accepted socket (best effort; never fatal).
STATIC FUNCTION MCP_Http_Peer( hSocket )
   LOCAL cAddr := ""
   BEGIN SEQUENCE
      cAddr := hb_InetAddress( hSocket )
   RECOVER
      cAddr := ""
   END SEQUENCE
   IF ValType( cAddr ) != "C" .OR. Empty( cAddr )
      cAddr := "?"
   ENDIF
RETURN cAddr

// For a tools/call request, return " (tool: <name>)" for the log, else "".
STATIC FUNCTION MCP_Http_ToolLabel( hReq )
   LOCAL hParams

   IF ValType( hReq ) == "H" .AND. HHasKey( hReq, "method" ) .AND. hReq["method"] == "tools/call" ;
      .AND. HHasKey( hReq, "params" )
      hParams := hReq["params"]
      IF ValType( hParams ) == "H" .AND. HHasKey( hParams, "name" ) .AND. ValType( hParams["name"] ) == "C"
         RETURN " (tool: " + hParams["name"] + ")"
      ENDIF
   ENDIF

RETURN ""

//---------------------------------------------------------------------------
// Connected-client overview (GUI): the 'C' key prints the clients seen most
// recently. The server is single-threaded (accept -> serve -> close), so a
// "client" is tracked by its MCP session id across requests; clients that send
// no session id are collapsed onto one peer+user entry.
//---------------------------------------------------------------------------

STATIC FUNCTION MCP_Http_TrackClient( cSessionId, cNewSession, cMethod )
   LOCAL cKey, hRec, lNew := .F.
   LOCAL nNow := Seconds()

   cKey := IIF( ! Empty( cSessionId ), cSessionId, ;
           IIF( ! Empty( cNewSession ), cNewSession, ;
                s_cReqPeer + "#" + LTrim( Str( s_nReqUser ) ) ) )

   IF ! HHasKey( s_hMcpClients, cKey )
      s_hMcpClients[ cKey ] := { "user"=>s_nReqUser, "name"=>s_cReqName, "peer"=>s_cReqPeer, ;
         "first"=>nNow, "count"=>0, "last"=>nNow, "lasttime"=>Time(), "method"=>"" }
      lNew := .T.
   ENDIF
   hRec := s_hMcpClients[ cKey ]
   hRec[ "count" ]++
   hRec[ "last" ]     := nNow
   hRec[ "lasttime" ] := Time()
   hRec[ "method" ]   := cMethod
   IF s_nReqUser > 0        // identity may have been unknown on the very first hit
      hRec[ "user" ] := s_nReqUser
      hRec[ "name" ] := s_cReqName
   ENDIF
   IF ! Empty( s_cReqPeer )
      hRec[ "peer" ] := s_cReqPeer
   ENDIF

   IF lNew
      MCP_Http_Log( "Neuer Client verbunden: " + MCP_Http_ClientLabel( hRec ) + "  [Sitzung " + Left( cKey, 32 ) + "]" )
   ENDIF
RETURN NIL

STATIC FUNCTION MCP_Http_ClientLabel( hRec )
RETURN IIF( hRec[ "user" ] > 0, ;
           AllTrim( hRec[ "name" ] ) + " (" + LTrim( Str( hRec[ "user" ] ) ) + ")", ;
           "ohne Key" ) + " @ " + hRec[ "peer" ]

// Print the overview to the GUI log. "aktiv" = a request within the last 120s;
// entries idle for more than an hour are pruned so the table stays bounded.
STATIC FUNCTION MCP_Http_ShowClients()
   LOCAL cKey, hRec, nNow := Seconds(), nAge
   LOCAL aActive := {}, nTotal, nX

   FOR EACH cKey IN HGetKeys( s_hMcpClients )   // a snapshot array - safe to HDel below
      nAge := nNow - s_hMcpClients[ cKey ][ "last" ]
      IF nAge < 0
         nAge += 86400          // clock passed midnight since the last request
      ENDIF
      IF nAge > 3600
         HDel( s_hMcpClients, cKey )
      ELSEIF nAge <= 120
         AAdd( aActive, { nAge, cKey, s_hMcpClients[ cKey ] } )
      ENDIF
   NEXT

   nTotal := Len( s_hMcpClients )
   ASort( aActive,,, {| a, b | a[ 1 ] < b[ 1 ] } )   // most recent activity first

   MCP_Http_Log( "==== Verbundene Clients: " + LTrim( Str( Len( aActive ) ) ) + ;
      " aktiv (<=120s), " + LTrim( Str( nTotal ) ) + " bekannt ====" )
   IF Len( aActive ) == 0
      MCP_Http_Log( "  (keine aktiven Clients)" )
   ENDIF
   FOR nX := 1 TO Len( aActive )
      nAge := aActive[ nX ][ 1 ]
      cKey := aActive[ nX ][ 2 ]
      hRec := aActive[ nX ][ 3 ]
      MCP_Http_Log( "  " + MCP_Http_ClientLabel( hRec ) + ;
         "  Anfragen " + LTrim( Str( hRec[ "count" ] ) ) + ;
         "  zuletzt " + hRec[ "lasttime" ] + " (vor " + LTrim( Str( Int( nAge ) ) ) + "s, " + AllTrim( hRec[ "method" ] ) + ")" + ;
         "  Sitzung " + Left( cKey, 24 ) )
   NEXT
RETURN NIL

// Poll the keyboard once (non-blocking) and act on hotkeys. Called both while
// idle and between requests so the 'C' overview still works under load. It does
// NOT help while a single request is stuck - a dangling request is itself the
// diagnosis (see the request timing in MCP_Http_HandleMessage).
STATIC FUNCTION MCP_Http_PumpKeys()
   LOCAL nKey := Inkey()
   DO CASE
   CASE nKey == Asc( "c" ) .OR. nKey == Asc( "C" )
      MCP_Http_ShowClients()
   ENDCASE
   MCP_Http_FlushSlashStats()   // piggyback the periodic housekeeping
RETURN NIL

// Once a minute log a heartbeat: active clients and the number of GET / (health
// /stream) pings in the interval. Runs from the loop's housekeeping (idle and
// between requests), so it also proves the loop is alive: if the heartbeat
// STOPS while the server is up, the loop is stuck inside a single request (a
// hanging tool/hook) - that is the definitive hang indicator, and 'C' being
// dead at the same time is the same cause.
STATIC FUNCTION MCP_Http_FlushSlashStats()
   LOCAL nNow := Seconds(), nElapsed, nActive := 0, cKey, nAge
   IF s_nSlashSince < 0
      s_nSlashSince := nNow
      RETURN NIL
   ENDIF
   nElapsed := nNow - s_nSlashSince
   IF nElapsed < 0
      nElapsed += 86400
   ENDIF
   IF nElapsed < 60
      RETURN NIL
   ENDIF
   FOR EACH cKey IN HGetKeys( s_hMcpClients )
      nAge := nNow - s_hMcpClients[ cKey ][ "last" ]
      IF nAge < 0
         nAge += 86400
      ENDIF
      IF nAge <= 120
         nActive++
      ENDIF
   NEXT
   MCP_Http_Log( "Heartbeat: " + LTrim( Str( nActive ) ) + " Client(s) aktiv, " + ;
      LTrim( Str( s_nSlashHits ) ) + " GET-/ Pings in " + LTrim( Str( Int( nElapsed ) ) ) + "s" )
   s_nSlashHits := 0
   s_nSlashSince := nNow
RETURN NIL

// Time-based auto-reload, callable both while idle and between requests so a
// source change is picked up even under constant load (when the idle branch is
// never reached). Never runs mid-request, so a restart cannot interrupt a tool
// call. hListen and lRestart are updated by reference.
STATIC FUNCTION MCP_Http_MaybeReload( nPort, lAutoReload, phListen, plRestart )
   LOCAL nNow := Seconds(), nElapsed, nSpawn
   IF ! lAutoReload .OR. Empty( s_cMcpSrcStamp )
      RETURN NIL
   ENDIF
   IF s_nLastReloadCheck < 0
      s_nLastReloadCheck := nNow
      RETURN NIL
   ENDIF
   nElapsed := nNow - s_nLastReloadCheck
   IF nElapsed < 0
      nElapsed += 86400
   ENDIF
   IF nElapsed < 10          // at most one source check every ~10 wall-clock s
      RETURN NIL
   ENDIF
   s_nLastReloadCheck := nNow
   IF MCP_Http_SourceStamp() == s_cMcpSrcStamp
      RETURN NIL
   ENDIF
   MCP_Http_Log( "Quelldatei geaendert - starte neue Instanz mit gleicher Kommandozeile..." )
   hb_InetClose( phListen )   // free the port FIRST so the new instance can bind
   phListen := NIL
   nSpawn := WAPI_ShellExecute( NIL, "open", Exename(), DosParam() )
   IF HB_IsNumeric( nSpawn ) .AND. nSpawn <= 32   // ShellExecute error code
      MCP_Http_Log( "  Neustart fehlgeschlagen (Code " + LTrim( Str( nSpawn ) ) + ") - Server laeuft mit altem Stand weiter" )
      s_cMcpSrcStamp := MCP_Http_SourceStamp()    // do not retry every check
      phListen := hb_InetServer( nPort )
      hb_InetTimeout( phListen, 1000 )
   ELSE
      plRestart := .T.
      s_lMcpHttpStop := .T.
   ENDIF
RETURN NIL

#include 'mcp_stdio.prg'
