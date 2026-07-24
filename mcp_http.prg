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

FUNCTION MCP_Http( nPort, cBindAddr, lVerbose )
   LOCAL nStdErr := hb_GetStdErr()
   LOCAL hListen, hSocket

   IF nPort == NIL
      nPort := McpHttpPort()
   ENDIF
   IF lVerbose == NIL
      lVerbose := .T.
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
      RETURN NIL
   ENDIF

   // Make accept() return every second so the loop can honour the stop flag
   // and (under a GUI GT such as GTWVG) pump window messages via Inkey().
   hb_InetTimeout( hListen, 1000 )

   MCP_Http_Log( "Listening on port " + LTrim(Str(nPort)) + " (all interfaces, Streamable HTTP)" )

   s_lMcpHttpStop := .F.

   DO WHILE ! s_lMcpHttpStop
      hSocket := hb_InetAccept( hListen )
      IF hSocket == NIL
         // Accept timed out (no pending connection) - keep the UI responsive.
         Inkey( 0 )
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
   LOCAL nLen, cReqLine, cPath
   LOCAL aLines, aReq, nX, cLine, nColon, nQ
   LOCAL hHeaders := {=>}
   LOCAL cHttpMethod, cKey, cVal
   LOCAL nCL, cBody, cBuf, nGot
   LOCAL cOrigin, cSessionId
   LOCAL aCors

   MCP_Http_Log( "Eingehende Verbindung von " + MCP_Http_Peer( hSocket ) )

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
   aReq := hb_ATokens( cReqLine, " " )
   IF Len(aReq) < 2
      MCP_Http_Send( hSocket, 400, "text/plain", "Bad Request", {} )
      RETURN NIL
   ENDIF
   cHttpMethod := Upper( aReq[1] )
   cPath := aReq[2]
   nQ := At( "?", cPath )
   IF nQ > 0
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

   // Log the request line (method, path, and body size for POST).
   MCP_Http_Log( "  " + cHttpMethod + " " + cPath + ;
      IIF( HHasKey(hHeaders, "CONTENT-LENGTH"), " [" + AllTrim(hHeaders["CONTENT-LENGTH"]) + " bytes]", "" ) + ;
      IIF( ! Empty(cOrigin), " origin=" + cOrigin, "" ) )

   // ---- Route by HTTP method -------------------------------------------

   // CORS preflight.
   IF cHttpMethod == "OPTIONS"
      MCP_Http_Send( hSocket, 204, "", "", aCors )
      RETURN NIL
   ENDIF

   // Health probe / no SSE stream on GET.
   IF cHttpMethod == "GET"
      IF cPath == "/healthz" .OR. cPath == "/health" .OR. cPath == "/"
         MCP_Http_Send( hSocket, 200, "text/plain", "ok", aCors )
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

   cMethod := IIF( HHasKey(hReq, "method"), hReq["method"], "" )
   MCP_Http_Log( "  JSON-RPC: " + cMethod + MCP_Http_ToolLabel( hReq ) )

   // NOTE: session validation is intentionally NOT enforced. Per the MCP spec
   // it is optional, and this single, stateless server keeps no per-session
   // data. We still ISSUE an Mcp-Session-Id on initialize (some clients want
   // it) but we accept any/none afterwards - rejecting an unrecognised id with
   // 404 only broke clients (e.g. the MCP Inspector's notifications/initialized).

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

   MCP_Http_Log( "  <= " + LTrim(Str(nStatus)) + " " + MCP_Http_StatusText(nStatus) + ;
      " (" + LTrim(Str(Len(cBody))) + " bytes)" )

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

#include 'mcp_stdio.prg'
