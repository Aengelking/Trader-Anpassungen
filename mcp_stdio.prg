/*
 * MCP (Model Context Protocol) Server for Trader - STDIO Integrated Version
 *
 * This module implements an MCP server that communicates via stdin/stdout
 * with full database integration for Claude Desktop.
 *
 * Copyright 2025 Trader Development Team
 * 
 */

// David InfoCenter archive constants (from david.ch). Defined locally so this
// module compiles independently of the David include path.
#ifndef DvArchiveCommon
   #define DvArchiveCommon      2
#endif
#ifndef DvArchivePersonalIn
   #define DvArchivePersonalIn  101
#endif


FUNCTION MCP_StdIO()
   LOCAL cInput, hRequest, cResponse
   LOCAL nStdIn, nStdOut,cChar,nStdErr
   LOCAL cLine := ""
   LOCAL cBuffer := ""
   LOCAL nChar, nPos
   LOCAL bOldError


   // Get stdin and stdout handles
   nStdIn := hb_GetStdIn()
   nStdOut := hb_GetStdOut()
   nStdErr := hb_GetStdErr()

   // No keyboard and no visible window in an MCP process: make sure nothing
   // (MailConnect, error handler, hooks) ever pops a modal Alert/MsgBox that
   // would block the request loop forever.
   SetConfigValue("BATCHMODE", .T.)

   FWrite(nStdErr,"MCP_StdIO: Starting MCP server via STDIO..."+Chr(10))

   ? "MCP STDIO: Started"
   
   // Set up error handler, changed the main error handler to ouput to stdErr
   /*bOldError := ErrorBlock({|oError| 
      LOCAL cMessage := ErrorMessage(oError)
      LOCAL nX := 1
      DO WHILE ! Empty(ProcName(nX))            
         cMessage += " (" + ProcName(nX) + " "+LTrim(Str(ProcLine(nX))) + ")"
         nX++
      ENDDO
      Break(cMessage)
      RETURN NIL 
   })*/
   

   // Main loop - read JSON-RPC requests from stdin
   DO WHILE .T.
      cLine := ""

      // Read a complete line (terminated by newline) from stdin. Data is read
      // in chunks into cBuffer, which carries any bytes past the newline over
      // to the next request. Reading byte-by-byte with a 0.1s Inkey() delay
      // per byte (the previous version) limited throughput to ~10 bytes/sec,
      // so any larger request (e.g. send_email with a long body) hit the MCP
      // client timeout before the tool was even called.
      DO WHILE .T.
         nPos := At(Chr(10), cBuffer)
         IF nPos > 0
            cLine := Left(cBuffer, nPos - 1)
            cBuffer := SubStr(cBuffer, nPos + 1)
            // Remove carriage return if present
            IF Right(cLine, 1) == Chr(13)
               cLine := Left(cLine, Len(cLine) - 1)
            ENDIF
            EXIT
         ENDIF

         cChar := Space(4096)
         nChar := FRead(nStdIn, @cChar, Len(cChar))
         IF nChar > 0
            cBuffer += Left(cChar, nChar)
         ELSE
            // Nothing read (pipe empty or closed) - wait briefly so we do
            // not busy-spin. FRead on a pipe normally blocks, so this only
            // triggers on EOF or a non-blocking stdin.
            Inkey(0.1)
         ENDIF
      ENDDO
      
      
      IF !Empty(cLine)
         ? "Processing request: " + cLine
         // Parse JSON request
         hRequest := HB_JsonDecode(cLine)
         IF hRequest != NIL .AND. ValType(hRequest) == "H"
            // Validate basic JSON-RPC structure
            IF !HHasKey(hRequest, "jsonrpc") .OR. !HHasKey(hRequest, "method")
               cResponse := CreateErrorResponse("Invalid JSON-RPC request: missing required fields", ;
                  IIF(HHasKey(hRequest, "id"), hRequest["id"], ""))
            ELSE
               // Process MCP request
               cResponse := ProcessMCPRequest(hRequest)
               
               // Check for shutdown
               IF HHasKey(hRequest, "method") .AND. hRequest["method"] == "shutdown"
                  FWrite(nStdOut, cResponse + Chr(10))
                  EXIT
               ENDIF
            ENDIF
         ELSE
            cResponse := CreateErrorResponse("Invalid JSON in request", "")
         ENDIF
         
         // Write response to stdout with newline
         FWrite(nStdOut, cResponse + Chr(10))
      ENDIF
   ENDDO
   
   // Cleanup
   dbCloseAll()

RETURN NIL

//===========================================================================
// MCP Streamable HTTP transport
//
// A thin HTTP wrapper around the very same ProcessMCPRequest() dispatch used
// by the STDIO transport above. It implements the MCP "Streamable HTTP"
// transport in its single JSON response mode: the client POSTs one JSON-RPC
// message to a single endpoint and receives one JSON-RPC response with
// Content-Type: application/json. No SSE stream is opened (that can be added
// later without touching any tool code).
//
// TLS is intentionally NOT handled here. Run this listener bound to localhost
// and terminate HTTPS at a reverse proxy (Caddy / nginx / stunnel) that
// forwards to it. See MCP_HTTP_README.md for a ready-to-use Caddyfile.
//
// The server is single threaded and serves one request at a time, exactly
// like the STDIO loop, so the global work areas / LetoDBF state used by the
// MCP_Tool_* functions are accessed serially and need no extra locking.
//===========================================================================

STATIC s_hMcpSessions    := NIL   // hash: session-id -> .T. (issued at initialize)
STATIC s_nMcpSessionSeq  := 0     // monotonic counter for session-id uniqueness
STATIC s_lMcpHttpStop    := .F.   // set when a "shutdown" request arrives

FUNCTION MCP_Http( nPort, cBindAddr )
   LOCAL nStdErr := hb_GetStdErr()
   LOCAL hListen, hSocket

   IF nPort == NIL
      nPort := McpHttpPort()
   ENDIF
   IF Empty(cBindAddr)
      cBindAddr := "127.0.0.1"
   ENDIF

   // Same guard as the STDIO server: never let a hook / error handler pop a
   // modal Alert/MsgBox that would block the request loop forever.
   SetConfigValue("BATCHMODE", .T.)

   hb_InetInit()

   // Bind to the given interface only (localhost by default) - the reverse
   // proxy is expected to run on the same host and terminate TLS.
   hListen := hb_InetServer( nPort, NIL, cBindAddr )
   IF hListen == NIL .OR. hb_InetErrorCode( hListen ) != 0
      FWrite( nStdErr, "MCP_Http: cannot bind " + cBindAddr + ":" + LTrim(Str(nPort)) + Chr(10) )
      hb_InetCleanup()
      RETURN NIL
   ENDIF

   FWrite( nStdErr, "MCP_Http: listening on " + cBindAddr + ":" + LTrim(Str(nPort)) + " (Streamable HTTP, single response)" + Chr(10) )
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
   LOCAL cHead, nLen, cReqLine, cPath
   LOCAL aLines, aReq, nX, cLine, nColon, nQ
   LOCAL hHeaders := {=>}
   LOCAL cHttpMethod, cKey, cVal
   LOCAL nCL, cBody, cBuf, nGot
   LOCAL cOrigin, cSessionId
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
   aCors      := MCP_Http_CorsHeaders( cOrigin )

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
      cBuf := Space( nCL )
      nGot := hb_InetRecvAll( hSocket, @cBuf, nCL )
      IF nGot > 0
         cBody := Left( cBuf, nGot )
      ENDIF
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
   CASE nStatus == 500 ; cText := "Internal Server Error"
   OTHERWISE           ; cText := "OK"
   ENDCASE

RETURN cText

FUNCTION ProcessMCPRequest(hRequest)
   LOCAL cMethod, cResponse, cFunctionName
   LOCAL cJsonrpc := hRequest["jsonrpc"]
   LOCAL xId := IIF(HHasKey(hRequest, "id"), hRequest["id"], "")
   LOCAL cMessage
   
   IF cJsonrpc != "2.0"
      RETURN CreateErrorResponse("Invalid JSON-RPC version", xId)
   ENDIF
   
   cMethod := IIF(HHasKey(hRequest, "method"), hRequest["method"], "")
   
   IF Empty(cMethod)
      RETURN CreateErrorResponse("Missing method field", xId)
   ENDIF
   
   // Convert method name to function name: tools/list -> MCP_Tools_List
   cFunctionName := "MCP_" + StrTran(cMethod, "/", "_")
   
   // Check if function exists and call it dynamically
   IF Type(cFunctionName + "()") != "U"
      BEGIN SEQUENCE
         cResponse := HB_ExecFromArray(cFunctionName, {hRequest, xId})
      RECOVER
         cResponse := CreateErrorResponse("Error executing method: " + cFunctionName,xID)
      END SEQUENCE
   ELSE
      cResponse := CreateErrorResponse("Unknown method: " + cMethod + " (function: " + cFunctionName + ")", xId)
   ENDIF
   
RETURN cResponse

FUNCTION MCP_Initialize(hRequest, xId)
   LOCAL hResult := {=>}
   LOCAL hCapabilities := {=>}
   
   hCapabilities["tools"] := {=>}
   hCapabilities["resources"] := {=>}
   
   hResult["protocolVersion"] := "2024-11-05"
   hResult["capabilities"] := hCapabilities
   hResult["serverInfo"] := {;
      "name"=>"Trader MCP Server (STDIO Integrated)",;
      "version"=>"1.0.0"}
   
RETURN CreateSuccessResponse(hResult, xId)

FUNCTION MCP_Shutdown(hRequest, xId)
   LOCAL hResult := {=>}
   
RETURN CreateSuccessResponse(hResult, xId)

FUNCTION MCP_Tools_List(hRequest, xId)
   LOCAL aTools := {}
   LOCAL aFuncNames, cFuncName, cToolName, hTool, hToolInfo
   
   // Dynamically discover all MCP_Tool_* functions
   aFuncNames := GetFunctionsWithPrefix("MCP_TOOL_")
   
   FOR EACH cFuncName IN aFuncNames
      // Convert MCP_TOOL_GET_CUSTOMER to get_customer
      cToolName := Lower(SubStr(cFuncName, 10))  // Remove "MCP_TOOL_"
      
      // Get schema and description from the tool function itself
      hToolInfo := HB_ExecFromArray(cFuncName, {})
      
      hTool := {=>}
      hTool["name"] := cToolName
      hTool["description"] := hToolInfo["description"]
      hTool["inputSchema"] := hToolInfo["schema"]
      
      AAdd(aTools, hTool)
   NEXT
   
RETURN CreateSuccessResponse({"tools"=>aTools}, xId)

FUNCTION GetFunctionsWithPrefix(cPrefix)
   LOCAL aFunctions := {}
   LOCAL nCount := __dynsCount()
   LOCAL i, cFuncName
   
   cPrefix := Upper(cPrefix)
   
   FOR i := 1 TO nCount
      cFuncName := __dynsGetName(i)
      IF Left(Upper(cFuncName), Len(cPrefix)) == cPrefix
         AAdd(aFunctions, cFuncName)
      ENDIF
   NEXT
   
RETURN aFunctions


FUNCTION MCP_Tools_Call(hRequest, xId)
   LOCAL hParams := hRequest["params"]
   LOCAL cToolName := hParams["name"]
   LOCAL hArguments := IF(HHasKey(hParams,"arguments"),hParams["arguments"],{=>})
   LOCAL cFunctionName, hResult, hToolData, cFormattedText
   LOCAL hToolInfo, aRequired, cRequiredParam
   LOCAL aAnyOfGroups
   LOCAL aGroup, lGroupSatisfied, cParam
   LOCAL cGroupParams,oError
   LOCAL nProvidedCount := 0
   LOCAL cProvidedParams := ""

   
   // Convert tool name to function name: get_customer -> MCP_Tool_Get_Customer
   cFunctionName := "MCP_Tool_" + cToolName
   
   // Check if function exists
   IF Type(cFunctionName + "()") != "U"
      // Get tool schema for parameter validation
      
      hToolInfo := HB_ExecFromArray(cFunctionName, {})
      
      // Validate required parameters
      IF HHasKey(hToolInfo["schema"], "required") .AND. HB_IsArray(hToolInfo["schema"]["required"])
         aRequired := hToolInfo["schema"]["required"]
         FOR EACH cRequiredParam IN aRequired
            IF !HHasKey(hArguments, cRequiredParam) .OR. Empty(hArguments[cRequiredParam])
               RETURN CreateErrorResponse("Missing required parameter: " + cRequiredParam, xId)
            ENDIF
         NEXT
      ENDIF
      
      // Validate anyOf requirements (exactly one parameter from the group must be provided)
      IF HHasKey(hToolInfo["schema"], "anyOf") .AND. HB_IsArray(hToolInfo["schema"]["anyOf"])
         aAnyOfGroups := hToolInfo["schema"]["anyOf"]
         FOR EACH aGroup IN aAnyOfGroups
            nProvidedCount := 0
            cProvidedParams := ""
            
            FOR EACH cParam IN aGroup
               IF HHasKey(hArguments, cParam) .AND. !Empty(hArguments[cParam])
                  nProvidedCount++
                  IF Len(cProvidedParams) > 0
                     cProvidedParams += ", "
                  ENDIF
                  cProvidedParams += cParam
               ENDIF
            NEXT
            
            IF nProvidedCount == 0
               cGroupParams := ""
               FOR EACH cParam IN aGroup
                  IF Len(cGroupParams) > 0
                     cGroupParams += " OR "
                  ENDIF
                  cGroupParams += cParam
               NEXT
               RETURN CreateErrorResponse("Exactly one of these parameters is required: " + cGroupParams, xId)
            ELSEIF nProvidedCount > 1
               cGroupParams := ""
               FOR EACH cParam IN aGroup
                  IF Len(cGroupParams) > 0
                     cGroupParams += " OR "
                  ENDIF
                  cGroupParams += cParam
               NEXT
               RETURN CreateErrorResponse("Only one of these parameters is allowed: " + cGroupParams + ". You provided: " + cProvidedParams, xId)
            ENDIF
         NEXT
      ENDIF

      //make sure the tool is not called with no arguments, this would otherwise return the schmema
      IF hArguments == NIL .OR. ValType(hArguments) != "H" .OR. Len(hArguments) == 0
         hArguments := {"DUMMY"=>.T.}
      ENDIF      
      
      hToolData := HB_ExecFromArray(cFunctionName, {hArguments})
      
      IF ValType(hToolData) == "C" //string returned this is an error message
         RETURN CreateErrorResponse(hToolData, xId)
      ELSE   
         // Convert structured data to readable text for MCP content
         //cFormattedText := FormatToolResult(hToolData)
         cFormattedText := HB_JsonEncode(hToolData)  // Use JSON encoding for structured data
      
         hResult := {=>}
         hResult["type"] := "text"
         hResult["text"] := cFormattedText
      ENDIF       
   ELSE   
      RETURN CreateErrorResponse("Unknown tool: " + cToolName + " (function: " + cFunctionName + ")", xId)
   ENDIF
   
RETURN CreateSuccessResponse({"content"=>{hResult}}, xId)

FUNCTION MCP_Tool_Get_Customer(hArgs)
   LOCAL nCustomerNumber, cSearchTerm
   LOCAL hResult := {=>}
   LOCAL lFound := .F.
   LOCAL oKunde
   
   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{;
            "customer"=>{"type"=>"string","description"=>"Customer matchcode"},;
            "customer_number"=>{"type"=>"number","description"=>"Customer number"};
         },;
         "anyOf"=>{{"customer", "customer_number"}};
      }
      hResult["description"] := "Retrieve customer information by customer matchcode or number"
      RETURN hResult
   ENDIF

   IF HHasKey(hArgs, "customer_number") 
      nCustomerNumber := hArgs["customer_number"]
   ENDIF
   IF HHasKey(hArgs, "customer") 
      cSearchTerm := hArgs["customer"]
   ENDIF

   oKunde:= Adresse():New()
   IF nCustomerNumber != NIL .AND. nCustomerNumber > 0
      // Load customer by number
      ku->(DbSetOrder(8))  // Assume order 1 is by customer number
      lFound := oKunde:Load(nCustomerNumber)
   ELSEIF !Empty(cSearchTerm)
      // Search by matchcode
      lFound := oKunde:LoadMatchcode(Pad(Upper(cSearchTerm),8),"K")
   ENDIF
   
   IF lFound
      hResult["number"] := oKunde:nummer
      hResult["name"] := AllTrim(oKunde:cName)
      hResult["street"] := AllTrim(oKunde:street)
      hResult["city"] := AllTrim(oKunde:town)
      hResult["country"] := AllTrim(oKunde:cLand)
      hResult["status"] := "found"
   ELSE
      hResult["status"] := "not_found"
      hResult["message"] := "Customer not found"
   ENDIF
   
RETURN _HashToUtf8(hResult)

FUNCTION MCP_Tool_Search_Customers(hArgs)
   LOCAL hResult := {=>}
   LOCAL aCustomers := {}
   LOCAL hCustomer
   LOCAL cFilter, cNeedle
   LOCAL nMaxResults, nCount := 0
   LOCAL nOldSelect := Select()

   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{;
            "name"=>{"type"=>"string","description"=>"Case-insensitive text filter applied to customer Name"},;
            "town"=>{"type"=>"string","description"=>"Case-insensitive text filter applied to customer Town"},;
            "max_results"=>{"type"=>"number","description"=>"Maximum number of matching customers to return (default 50, max 200)"};
         },;
         "anyOf"=>{{"name", "town"}};
      }
      hResult["description"] := "Search customers by text in Name or Town"
      RETURN hResult
   ENDIF

   nMaxResults := IIF(HHasKey(hArgs, "max_results") .AND. HB_IsNumeric(hArgs["max_results"]), hArgs["max_results"], 50)
   nMaxResults := Max(1, Min(nMaxResults, 200))

   IF ! HHasKey(hArgs, "name") .AND. !HHasKey(hArgs, "town")
      RETURN "Invalid arguments for Search Customer: filter is required"
   ENDIF

   cFilter := ""
   IF HHasKey(hArgs, "name") .AND. !Empty(hArgs["name"])
      cFilter := '"'+Upper(AllTrim(hArgs["name"]))+'" $ Upper(Trim(name1)+name2)'
   ENDIF
   IF HHasKey(hArgs, "town") .AND. !Empty(hArgs["town"])
      IF !Empty(cFilter)
         cFilter += " .OR. "
      ENDIF
      cFilter += '"'+Upper(AllTrim(hArgs["town"]))+'" $ Upper(Trim(town))'
   ENDIF

   NetUse("engkund","ku")
   ku->(dbSetFilter({|| ku->(&(cFilter))},cFilter))
   ku->(DbSetOrder(2))
   ku->(DbSeek("K"))

   DO WHILE !ku->(Eof()) .AND. ku->Group == "K" .AND. nCount < nMaxResults

      hCustomer := {=>}
      hCustomer["number"] := ku->Nummer
      hCustomer["kunde"] := AllTrim(ku->Kunde)
      hCustomer["name"] := Trim(Trim(ku->Name1)+" "+ku->Name2)      
      hCustomer["town"] := AllTrim(ku->Town)
      hCustomer["street"] := AllTrim(ku->Street)
      hCustomer["countryiso"] := AllTrim(ku->CountryIso)
      AAdd(aCustomers, _HashToUtf8(hCustomer))
      nCount++

         ku->(DbSkip())
   ENDDO

   DbSelectArea(nOldSelect)
   ku->(dbClearFilter())

   hResult["status"] := IIF(Len(aCustomers) > 0, "found", "not_found")
   hResult["count"] := Len(aCustomers)
   hResult["max_results"] := nMaxResults
   //hResult["filter"] := cFilter
   hResult["customers"] := aCustomers

   IF Len(aCustomers) == 0
      hResult["message"] := "No customers found"
   ELSEIF Len(aCustomers) == nMaxResults
      hResult["message"] := "Result limited to " + AllTrim(Str(nMaxResults)) + " customers"
   ENDIF

RETURN _HashToUtf8(hResult)

FUNCTION MCP_Tool_Get_Article(hArgs)
   LOCAL hResult := {=>}
   LOCAL lFound := .F.
   LOCAL hShopwareData, hShopwareOptions

   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{;
            "matchcode"=>{"type"=>"string","description"=>"Artikel Matchcode"},;
            "partno"=>{"type"=>"string","description"=>"Artikelnummer"};
         },;
         "anyOf"=>{{"matchcode", "partno"}};
      }
      hResult["description"] := "Retrieve detailed information for a single article/product by matchcode or part number. " + ;
                                "Returns comprehensive data including stock, prices, description" + ;
                                "Use this when you need detailed information"
      RETURN hResult
   ENDIF

   IF ValType(hArgs) != "H" .OR. !HHasKey(hArgs, "matchcode") .AND. !HHasKey(hArgs, "partno")
      RETURN "Invalid arguments for Get Article: "+ValType(hArgs) + " " + ;
             IF(ValType(hArgs)=="H" .AND. !HHasKey(hArgs, "matchcode") .AND. !HHasKey(hArgs, "partno"), ;
             "No matchcode or part number provided", "Wrong type of arguments")
   ENDIF

   NetUse("artikel","art")  // Ensure article database is available

   IF HHasKey(hArgs,"matchcode") .AND. !Empty(hArgs["matchcode"])
      // Load by matchcode
      art->(DbSetOrder(1))  // Assume order 1 is by matchcode
      lFound := art->(DbSeek(Upper(hArgs["matchcode"])))
   ELSEIF HHasKey(hArgs,"partno") .AND. !Empty(hArgs["partno"])
      // Search by part number
      art->(DbSetOrder(2))  
      lFound := art->(DbSeek(Str(Val(hArgs["partno"]),6)))
   ENDIF

   IF lFound
      hResult["matchcode"] := AllTrim(art->matchcode)
      hResult["description"] := AllTrim(art->artikel)
      hResult["unit"] := AllTrim(art->Me)
      hResult["group"] := AllTrim(art->gruppe)
      //hResult["sell_price"] := art->vkpr
      hResult["stock"] := art->bestand
      
      hResult["status"] := "found"
   ELSE
      hResult["status"] := "not_found"
      hResult["message"] := "Article not found"
   ENDIF
   
RETURN hResult

FUNCTION MCP_Tool_Get_Order_Details(hArgs)
   LOCAL oAuftrag
   LOCAL hResult := {=>}
   LOCAL lFound := .F.
   
   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{;
            "order_number"=>{"type"=>"number","description"=>"Order number"};
         },;
         "required"=>{"order_number"};
      }
      hResult["description"] := "Retrieve detailed order information by order number, including all line items and their status"
      RETURN hResult
   ENDIF
   
   oAuftrag := Auftrag():New()
   IF  oAuftrag:Load(hArgs["order_number"])
      lFound := .T.         
      hResult["order_number"] := oAuftrag:abnr
      hResult["customer"] := oAuftrag:Kundma
      hResult["date"] := oAuftrag:Besda
      hResult["completed"] := oAuftrag:Erledigt //auf->Status == 3 .OR. auf->Status == 7
      hResult["total"] := oAuftrag:total
      hResult["lines"] := {}
      oAuftrag:Positions:Each({|oPos| 
         LOCAL hPosition := {=>}
         hPosition["article"] := AllTrim(oPos:Matchcode)
         //hPosition["description"] := AllTrim(oPos:Artikel:Artikel)
         hPosition["blanket_order"] := oPos:IsRahmen
         IF oPos:IsRahmen
            hPosition["quantity"] := oPos:ContrQty            
         ELSE
            hPosition["quantity"] := oPos:VkQty
         ENDIF
         hPosition["open_quantity"] := IF(oPos:lErledigt, 0, oPos:VkQty - oPos:GelQty)
         hPosition["delivered_quantity"] := oPos:GelQty
         hPosition["price"] := oPos:VkPr/oPos:Pe
         hPosition["status"] := IF(oPos:lErledigt, "completed", "open")
         hPosition["total"] := oPos:GetLineTotal()
         
         // Add position to order result
         AAdd(hResult["lines"], hPosition)
         RETURN .T.
      })
      hResult["status"] := "found"
   ENDIF
   
   IF !lFound
      hResult["status"] := "not_found"
      hResult["message"] := "Order not found: " + LTrim(Str(hArgs["order_number"]))
   ENDIF
   
RETURN hResult

FUNCTION MCP_Tool_Check_Stock(hArgs)
   LOCAL cMatchcode
   LOCAL hResult := {=>}

   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{;
            "matchcode"=>{"type"=>"string","description"=>"Article matchcode"};
         },;
         "required"=>{"matchcode"};
      }
      hResult["description"] := "Check current stock levels for an article"
      RETURN hResult
   ENDIF

   cMatchcode := hArgs["matchcode"]
   
   NetUse("artikel","art")  // Ensure article database is available
   NetUse("shopware","shop")  // For Shopware URLs
   
   IF !Empty(cMatchcode)
      art->(DbSetOrder(1))  // Assume order 1 is by matchcode
      IF art->(DbSeek(cMatchcode))
         hResult["matchcode"] := AllTrim(cMatchcode)
         hResult["description"] := AllTrim(art->artikel)
         hResult["current_stock"] := art->bestand
         //hResult["reserved"] := art->reserviert
         hResult["available"] := LagGetStock(art->Artikelnr,2) //art->bestand - art->reserviert
         
         // Check if article has Shopware entry
         IF shop->(dbSeek(Str(art->Artikelnr,6)))
            hResult["shopware_url"] := "https://engelking.de/detail/" + AllTrim(shop->UUID)
         ENDIF
         
         hResult["status"] := "found"
      ELSE
         hResult["status"] := "not_found"
         hResult["message"] := "Article not found: " + cMatchcode
      ENDIF
   ELSE
      hResult["status"] := "error"
      hResult["message"] := "No matchcode provided"
   ENDIF
   
RETURN hResult

FUNCTION MCP_Tool_Search_Articles(hArgs)
   LOCAL hResult := {=>}
   LOCAL aArticles := {}
   LOCAL nCount := 0
   LOCAL hArticle
   LOCAL cMatchcodePrefix, cDescriptionContains, nMaxResults, cGroup
   LOCAL cStockFilter, nMinStock, nMaxStock
   LOCAL lMatches
   LOCAL cEnhancedDescription, cMacroFilter
   LOCAL bMatchAndAdd,cFilter,bFilter
   
   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{;
            "matchcode_prefix"=>{"type"=>"string","description"=>"Search for articles where matchcode starts with this value"},;
            "description_contains"=>{"type"=>"string","description"=>"Search for articles where description contains text. Supports AND/OR operators and parentheses for grouping (e.g., 'resistor AND 1k', 'capacitor OR inductor', '(resistor OR capacitor) AND (1k OR 2k)')"},;
            "group"=>{"type"=>"string","description"=>"Filter by article group"},;
            "stock_filter"=>{"type"=>"string","description"=>"Filter by stock status: 'in_stock' (>0), 'out_of_stock' (=0), 'low_stock' (<10)"},;
            "min_stock"=>{"type"=>"number","description"=>"Minimum stock quantity"},;
            "max_stock"=>{"type"=>"number","description"=>"Maximum stock quantity"},;
            "max_results"=>{"type"=>"number","description"=>"Maximum number of results to return (default: 30)"};
         };
      }
      hResult["description"] := "Search the INTERNAL article database (not online shop). For online shop product searches, use get_catalogue instead. This tool searches local inventory records."
      RETURN hResult
   ENDIF
   
   // Get filter parameters
   cMatchcodePrefix := IIF(HHasKey(hArgs, "matchcode_prefix"), Upper(AllTrim(hArgs["matchcode_prefix"])), "")
   cDescriptionContains := IIF(HHasKey(hArgs, "description_contains"), Upper(AllTrim(hArgs["description_contains"])), "")
   cGroup := IIF(HHasKey(hArgs, "group"), AllTrim(hArgs["group"]), "")
   cStockFilter := IIF(HHasKey(hArgs, "stock_filter"), Lower(AllTrim(hArgs["stock_filter"])), "")
   nMaxResults := IIF(HHasKey(hArgs, "max_results"), hArgs["max_results"], 50)
   
   NetUse("artikel","art")  // Ensure article database is available
   NetUse("shopware","shop")  // For Shopware URLs

   cMacroFilter := BuildDescriptionFilter(cDescriptionContains)
   bFilter := &("{|cValue| art->(" + cMacroFilter + ")}")

   //Code block to match and add articles
   bMatchAndAdd := {||
      // Description filter (only if needed)
      IF  !Empty(cDescriptionContains)
         // Try basic article description first (fast)
         IF !Upper(cDescriptionContains) $ Upper(art->artikel)
            // Only get enhanced description if basic check fails
            
            IF !Empty(cMacroFilter) 
               // If we have a macro filter, we need to get the enhanced description
               cEnhancedDescription := GetEnhancedDescription(art->artikelnr)
               // Now check enhanced description
               IF ! Eval(bFilter, Upper(cEnhancedDescription) )
                  RETURN .F.
               ENDIF               
            ENDIF
         ENDIF
      ENDIF
      
      hArticle := {=>}
      hArticle["matchcode"] := AllTrim(art->matchcode)
      hArticle["description"] := GetEnhancedDescription(art->artikelnr)
      hArticle["unit"] := AllTrim(art->Me)
      hArticle["group"] := AllTrim(art->gruppe)
      hArticle["group_name"] := GetArtGroupName(AllTrim(art->gruppe))
      hArticle["stock"] := art->bestand
      
      // Check if article has Shopware entry
      IF shop->(dbSeek(Str(art->Artikelnr,6)))
         hArticle["shopware_url"] := "https://engelking.de/detail/" + AllTrim(shop->UUID)
      ENDIF
      
      AAdd(aArticles, hArticle)
      nCount++
      
      RETURN .T.
   }

   cFilter := "! obsolete"
   IF !Empty(cStockFilter)
      IF ! Empty(cFilter)
         cFilter += " .AND. "
      ENDIF

      DO CASE
         CASE cStockFilter == "in_stock"
            cFilter += "bestand > 0"
         CASE cStockFilter == "out_of_stock"
            cFilter += "bestand == 0"
         CASE cStockFilter == "low_stock"
            cFilter += "bestand < 10"
      ENDCASE
   ENDIF
   IF Empty(cStockFilter) .OR. cStockFilter == "in_stock"
      IF HHasKey(hArgs, "min_stock")
         IF ! Empty(cFilter)
            cFilter += " .AND. "
         ENDIF
         cFilter += "bestand > "+LTrim(Str( hArgs["min_stock"] ))
      ENDIF
      IF HHasKey(hArgs, "max_stock")
         IF ! Empty(cFilter)
            cFilter += " .AND. "
         ENDIF
         cFilter += "bestand <= "+LTrim(Str( hArgs["max_stock"] ))
      ENDIF
   ENDIF

   IF !Empty(cGroup)
      IF ! Empty(cFilter)
         cFilter += " .AND. "
      ENDIF
      cFilter += 'AllTrim(gruppe) != "'+cGroup+'"'
   ENDIF
   
   IF ! Empty(cFilter)
      // Apply stock filter to the article database
      art->(DbSetFilter({|| art->(&(cFilter))},cFilter))
   ENDIF
   
   hResult["filter"] := art->(dbFilter() )

   // Search using matchcode prefix if provided
   IF !Empty(cMatchcodePrefix)
      art->(DbSetOrder(1))  // Matchcode index
      hResult["filter_after_order"] := art->(dbFilter() )
      art->(DbSeek(cMatchcodePrefix))
         hResult["filter_after_seek"] := art->(dbFilter() )   
      WHILE !art->(Eof()) .AND. Left(Upper(art->matchcode), Len(cMatchcodePrefix)) == cMatchcodePrefix .AND. nCount < nMaxResults         
         Eval(bMatchAndAdd)
         //AAdd(aArticles, {"bestand"=>art->Bestand,"filter"=>art->(dbFilter())})
         art->(DbSkip())
      ENDDO
   ELSE
      // If no matchcode prefix, scan all articles with filters
      art->(DbGoTop())
      
      WHILE !art->(Eof()) .AND. nCount < nMaxResults
         
         Eval(bMatchAndAdd)
         
         art->(DbSkip())
      ENDDO
   ENDIF

   art->(dbClearFilter())  // Clear any filters applied
   
   hResult["articles"] := aArticles
   hResult["count"] := Len(aArticles)
   hResult["status"] := "found "+cFilter
   
   IF Len(aArticles) == 0
      hResult["message"] := "No articles found matching the criteria "+cMacroFilter
   ELSEIF Len(aArticles) == nMaxResults
      hResult["message"] := "Result limited to " + AllTrim(Str(nMaxResults)) + " articles"
   ENDIF
   
RETURN hResult

FUNCTION GetArtGroupName(cGruppe)
   LOCAL cGroupName := "", nOldSelect := Select()
   
   IF Empty(cGruppe)
      RETURN ""
   ENDIF
   
   NetUse("group","grup",.F.,0)
   IF grup->(DbSeek(cGruppe))
      cGroupName := AllTrim(grup->Name)
   ENDIF
   grup->(DbCloseArea())
   DbSelectArea(nOldSelect)
   
RETURN cGroupName

FUNCTION GetEnhancedDescription(nArtikelnr)
   LOCAL cDescription := "", cExtendedText := "", cVariantOptions := ""
   LOCAL nOldSelect := Select()
   LOCAL oBase, nLen, cBase
   LOCAL aEnv 
   
   // Get basic description
   cDescription := AllTrim(HB_StrToUTF8(art->artikel))
   
   // Get extended text description if available
   IF art->textnr > 0
      NetUse("engtext2","tx",.F.,0)
      cExtendedText := tx->(ReadText(art->textnr))
      IF !Empty(cExtendedText)
         cExtendedText := AllTrim(HB_StrToUTF8(cExtendedText))
         // Limit extended text to reasonable length for API response
         IF Len(cExtendedText) > 200
            cExtendedText := Left(cExtendedText, 197) + "..."
         ENDIF
      ENDIF
      tx->(DbCloseArea())
   ENDIF
   
   // Get variant options if this is a variant article
   IF art->Variant == "V" .AND. art->length > 0
      cBase := SubStr(art->Matchcode, 1, art->length)
      NetUse("optbas","opb",.F.,0)
      NetUse("option","op",.F.,0)
      
      IF opb->(DbSeek(cBase))
         aEnv := SaveEnv()
         oBase := OptionBase():New()
         oBase:Load(cBase)
         nLen := art->Length + 1
         
         oBase:oTables:Each({|oTable|
            LOCAL oKey, cOptionText
            
            oKey := oTable:oKeys:GetRecord(SubStr(art->Matchcode, nLen, oTable:Length))
            IF oKey != NIL .AND. !Empty(oKey:Descript)
               nLen += oTable:Length
               cOptionText := AllTrim(oTable:funktion("DE")) + ": " + AllTrim(oKey:descript("DE"))
               IF !Empty(cVariantOptions)
                  cVariantOptions += " | "
               ENDIF
               cVariantOptions += cOptionText
            ENDIF
            RETURN NIL
         })
         RestEnv(aEnv)
      ENDIF
      
      opb->(DbCloseArea())
      op->(DbCloseArea())
   ENDIF
   
   // Combine all description parts
   IF !Empty(cExtendedText)
      cDescription += " - " + cExtendedText
   ENDIF
   
   IF !Empty(cVariantOptions)
      cDescription += " (" + cVariantOptions + ")"
   ENDIF
   
   DbSelectArea(nOldSelect)
   
RETURN cDescription

/*FUNCTION GetShopwareProductData(cUUID, hOptions)
   LOCAL oSW, hResult := {=>}, hResponse, hData
   LOCAL lIncludePrices, lIncludeMedia, lIncludeCategories
   LOCAL cMessage, hPrice
   LOCAL cParentId, hParentData, hParentResponse, bGetValue
   LOCAL nWeight, nWidth, nHeight, nLength
   LOCAL cMetaTitle, cMetaDescription, cKeywords
   LOCAL hFeatureSet, aProperties, aOptions
   LOCAL aPropertyIds, aParentPropertyIds, cId, lIsVariant
   LOCAL aRelProperties, aFormattedProps, hProp, hPropItem
   LOCAL aRelOptions, aFormattedOptions, hOption, hOptionItem, aOptionIds
   LOCAL hSendData, hProductData, hParentSendData, hParentProductData
   LOCAL aProductProps
   LOCAL aParentProps := {}

   
   // Parse options
   lIncludePrices := IIF(HHasKey(hOptions, "prices"), hOptions["prices"], .F.)
   lIncludeMedia := IIF(HHasKey(hOptions, "media"), hOptions["media"], .F.)
   lIncludeCategories := IIF(HHasKey(hOptions, "categories"), hOptions["categories"], .F.)
   
   // Initialize API
   oSW := ShopwareApi():New(.T.)
   IF !oSW:Auth()
      hResult["error"] := "Shopware authentication failed"
      hResult["status"] := "error"
      RETURN hResult
   ENDIF
   
   // Build search request to include associations
   hSendData := {;
      "filter"=>{;
         {;
            "type"=>"equals",;
            "field"=>"id",;
            "value"=>cUUID;
         };
      },;
      "associations"=>{;             
         "properties"=>{"associations"=>{"group"=>{}}},;         
         "manufacturer"=>{},;
         "unit"=>{},;
         "tax"=>{};
      },;
      "limit"=>1;
   }

         // Add price associations if requested
   IF lIncludePrices
      hSendData["associations"]["prices"] := {}
   ENDIF
   
   // Add media associations if requested  
   IF lIncludeMedia
      hSendData["associations"]["media"] := {}
   ENDIF
   
   // Execute API call with error handling
   BEGIN SEQUENCE
      hResponse := oSW:Execute("search/product", "POST", hSendData)
      
      // Temporary debug: Check if we got a response
      IF !HB_IsHash(hResponse)
         hResult["error"] := "No response from API"
         hResult["status"] := "error"
         //RETURN hResult
      ENDIF
      
      IF HB_IsHash(hResponse) .AND. HHasKey(hResponse, "data") .AND. HB_IsArray(hResponse["data"]) .AND. Len(hResponse["data"]) > 0
         // Search endpoint returns array of results, get first one
         hProductData := hResponse["data"][1]
         
         // Handle different possible response structures
         IF HHasKey(hProductData, "attributes")
            hData := hProductData["attributes"]
         ELSE
            hData := hProductData
         ENDIF
         
         // Check if this is a variant and get parent data if needed
         cParentId := IIF(HHasKey(hData, "parentId") .AND. hData["parentId"] != NIL, hData["parentId"], "")
         hParentData := NIL
         
         IF !Empty(cParentId)
            // Make a separate search call for parent product
            hParentSendData := {;
               "filter"=>{;
                  {;
                     "type"=>"equals",;
                     "field"=>"id",;
                     "value"=>cParentId;
                  };
               },;
               "associations"=>{;                  
                  "properties"=>{"associations"=>{"group"=>{}}};
               },;
               "limit"=>1;
            }
            
            hParentResponse := oSW:Execute("search/product", "POST", hParentSendData)
            
            IF HB_IsHash(hParentResponse) .AND. HHasKey(hParentResponse, "data") .AND. ;
               HB_IsArray(hParentResponse["data"]) .AND. Len(hParentResponse["data"]) > 0
               
               hParentProductData := hParentResponse["data"][1]
               IF HHasKey(hParentProductData, "attributes")
                  hParentData := hParentProductData["attributes"]
               ELSE
                  hParentData := hParentProductData
               ENDIF
            ENDIF
         ENDIF
         
         // Helper function to get value with inheritance
         bGetValue := {|cField, xDefault| 
            LOCAL xValue := IIF(HHasKey(hData, cField), hData[cField], NIL)
            IF xValue == NIL .AND. hParentData != NIL .AND. HHasKey(hParentData, cField)
               xValue := hParentData[cField]
            ENDIF
            RETURN IIF(xValue != NIL, xValue, xDefault)
         }
         
         // Basic product information  
         lIsVariant := !Empty(cParentId)
         hResult["uuid"] := IIF(HHasKey(hProductData, "id"), hProductData["id"], cUUID)
         hResult["parent_id"] := cParentId
         hResult["is_variant"] := lIsVariant
         
         // Get values with inheritance support
         hResult["product_number"] := AllTrim(Eval(bGetValue, "productNumber", ""))
         hResult["name"] := AllTrim(Eval(bGetValue, "name", ""))
         hResult["description"] := AllTrim(Eval(bGetValue, "description", ""))
         hResult["active"] := Eval(bGetValue, "active", .F.)
         hResult["available"] := Eval(bGetValue, "available", .F.)
         hResult["online_stock"] := IIF(HHasKey(hData, "stock") .AND. hData["stock"] != NIL, hData["stock"], 0)  // Stock is usually not inherited
         hResult["ean"] := AllTrim(Eval(bGetValue, "ean", ""))
         hResult["manufacturer_number"] := AllTrim(Eval(bGetValue, "manufacturerNumber", ""))
         hResult["updated_at"] := AllTrim(Eval(bGetValue, "updatedAt", ""))
         //hResult["response"] := hResponse  // Commented out debug info
         //hResult["parentResponse"] := hParentResponse  // Commented out debug info
         
         // Physical attributes with inheritance
         nWeight := Eval(bGetValue, "weight", NIL)
         nWidth := Eval(bGetValue, "width", NIL)
         nHeight := Eval(bGetValue, "height", NIL)
         nLength := Eval(bGetValue, "length", NIL)
         
         IF nWeight != NIL .OR. nWidth != NIL .OR. nHeight != NIL .OR. nLength != NIL
            hResult["physical"] := {;
               "weight" => nWeight,;
               "width" => nWidth,;
               "height" => nHeight,;
               "length" => nLength;
            }
         ENDIF
         
         // Custom fields
         IF HHasKey(hData, "customFields") .AND. hData["customFields"] != NIL
            hResult["custom_fields"] := hData["customFields"]
         ENDIF        
        
         // Product properties collated with parent properties by group name
         aProductProps := GetPropertiesFromIncluded(hResponse)         
         
         // Get parent properties if this is a variant
         IF lIsVariant .AND. !Empty(cParentId) .AND. hParentResponse != NIL
            aParentProps := GetPropertiesFromIncluded(hParentResponse)
         ENDIF
         
         // Collate properties by group name
         hResult["properties"] := CollatePropertiesByGroup(aProductProps, aParentProps)
         
         // Price information
         IF lIncludePrices .AND. HHasKey(hData, "price") .AND. HB_IsArray(hData["price"]) .AND. Len(hData["price"]) > 0
            hResult["prices"] := {}
            FOR EACH hPrice IN hData["price"]
               AAdd(hResult["prices"], {;
                  "net" => IIF(HHasKey(hPrice, "net"), hPrice["net"], 0),;
                  "gross" => IIF(HHasKey(hPrice, "gross"), hPrice["gross"], 0),;
                  "currency" => "EUR",;
                  "linked" => IIF(HHasKey(hPrice, "linked"), hPrice["linked"], .F.);
               })
            NEXT
         ENDIF
         
         // SEO data with inheritance
         cMetaTitle := AllTrim(Eval(bGetValue, "metaTitle", ""))
         cMetaDescription := AllTrim(Eval(bGetValue, "metaDescription", ""))
         cKeywords := AllTrim(Eval(bGetValue, "keywords", ""))
         
         IF !Empty(cMetaTitle) .OR. !Empty(cMetaDescription) .OR. !Empty(cKeywords)
            hResult["seo"] := {;
               "meta_title" => cMetaTitle,;
               "meta_description" => cMetaDescription,;
               "keywords" => cKeywords;
            }
         ENDIF
         
         hResult["status"] := "success"
      ELSE
         // More detailed error information
         IF HB_IsHash(hResponse)
            IF HHasKey(hResponse, "errors") .AND. HB_IsArray(hResponse["errors"]) .AND. Len(hResponse["errors"]) > 0
               hResult["error"] := "API Error: " + IIF(HHasKey(hResponse["errors"][1], "detail"), hResponse["errors"][1]["detail"], "Unknown error")
            ELSEIF HHasKey(hResponse, "data") .AND. HB_IsArray(hResponse["data"]) .AND. Len(hResponse["data"]) == 0
               hResult["error"] := "Product not found with ID: " + cUUID
               hResult["search_filter"] := hSendData["filter"]  // Show what filter was used
            ELSE
               hResult["error"] := "Unexpected response structure"
               hResult["debug_response_keys"] := IIF(HB_IsHash(hResponse), HB_HKeys(hResponse), {})
            ENDIF
         ELSE
            hResult["error"] := "Invalid response from Shopware API"
         ENDIF
         hResult["status"] := "error"
      ENDIF
      
   RECOVER USING cMessage
      hResult["error"] := "API Error: " + cMessage
      hResult["status"] := "error"
   END SEQUENCE
   
RETURN hResult

FUNCTION GetPropertiesFromIncluded(hResponse)
   LOCAL aProperties := {}, aIncluded, hItem, hPropData, hPropItem
   LOCAL hGroups := {=>}, hGroupItem, cGroupId
   
   IF !HB_IsHash(hResponse) .OR. !HHasKey(hResponse, "included") .OR. !HB_IsArray(hResponse["included"])
      RETURN aProperties
   ENDIF
   
   aIncluded := hResponse["included"]
   
   // First pass: collect all property groups
   FOR EACH hItem IN aIncluded
      IF HB_IsHash(hItem) .AND. HHasKey(hItem, "type") .AND. hItem["type"] == "property_group"
         IF HHasKey(hItem, "attributes") .AND. HB_IsHash(hItem["attributes"])
            hGroupItem := hItem["attributes"]
            cGroupId := IIF(HHasKey(hItem, "id"), hItem["id"], "")
            IF !Empty(cGroupId)
               hGroups[cGroupId] := IIF(HHasKey(hGroupItem, "name"), hGroupItem["name"], "")
            ENDIF
         ENDIF
      ENDIF
   NEXT
   
   // Second pass: collect property options and match with groups
   FOR EACH hItem IN aIncluded
      IF HB_IsHash(hItem) .AND. HHasKey(hItem, "type") .AND. hItem["type"] == "property_group_option"
         IF HHasKey(hItem, "attributes") .AND. HB_IsHash(hItem["attributes"])
            hPropData := hItem["attributes"]
         ELSE
            LOOP  // Skip invalid property
         ENDIF
         
         hPropItem := {=>}
         hPropItem["id"] := IIF(HHasKey(hItem, "id"), hItem["id"], "")
         hPropItem["name"] := IIF(HHasKey(hPropData, "name"), hPropData["name"], "")
         hPropItem["group_id"] := IIF(HHasKey(hPropData, "groupId"), hPropData["groupId"], "")
         hPropItem["position"] := IIF(HHasKey(hPropData, "position"), hPropData["position"], 0)
         
         // Add color if available
         IF HHasKey(hPropData, "colorHexCode") .AND. hPropData["colorHexCode"] != NIL
            hPropItem["color"] := hPropData["colorHexCode"]
         ENDIF
         
         // Add group name from our collected groups
         IF !Empty(hPropItem["group_id"]) .AND. HHasKey(hGroups, hPropItem["group_id"])
            hPropItem["group_name"] := hGroups[hPropItem["group_id"]]
         ENDIF
         
         AAdd(aProperties, hPropItem)
      ENDIF
   NEXT
   
RETURN aProperties

FUNCTION GetCombinedPropertiesFromIncluded(hResponse, aPropertyIds)
   LOCAL hCollated := {=>}, aIncluded, hItem, hPropData, hPropItem
   LOCAL hGroups := {=>}, hGroupItem, cGroupId, cGroupName
   LOCAL cItemId, cPropName
   
   IF !HB_IsHash(hResponse) .OR. !HHasKey(hResponse, "included") .OR. !HB_IsArray(hResponse["included"]) .OR. !HB_IsArray(aPropertyIds)
      RETURN hCollated
   ENDIF
   
   aIncluded := hResponse["included"]
   
   // First pass: collect all property groups
   FOR EACH hItem IN aIncluded
      IF HB_IsHash(hItem) .AND. HHasKey(hItem, "type") .AND. hItem["type"] == "property_group"
         IF HHasKey(hItem, "attributes") .AND. HB_IsHash(hItem["attributes"])
            hGroupItem := hItem["attributes"]
            cGroupId := IIF(HHasKey(hItem, "id"), hItem["id"], "")
            IF !Empty(cGroupId)
               hGroups[cGroupId] := IIF(HHasKey(hGroupItem, "name"), hGroupItem["name"], "")
            ENDIF
         ENDIF
      ENDIF
   NEXT
   
   // Second pass: collect and group properties by group name
   FOR EACH hItem IN aIncluded
      IF HB_IsHash(hItem) .AND. HHasKey(hItem, "type") .AND. hItem["type"] == "property_group_option"
         cItemId := IIF(HHasKey(hItem, "id"), hItem["id"], "")
         
         // Only include this property if it's in the product's combined propertyIds
         IF !Empty(cItemId) .AND. AScan(aPropertyIds, cItemId) > 0
            IF HHasKey(hItem, "attributes") .AND. HB_IsHash(hItem["attributes"])
               hPropData := hItem["attributes"]
               
               cGroupId := IIF(HHasKey(hPropData, "groupId"), hPropData["groupId"], "")
               IF !Empty(cGroupId) .AND. HHasKey(hGroups, cGroupId)
                  cGroupName := hb_strToUtf8(hGroups[cGroupId])
                  
                  // Initialize group if not exists
                  IF !HHasKey(hCollated, cGroupName)
                     hCollated[cGroupName] := {}
                  ENDIF
                  
                  // Add property name to group (avoid duplicates)
                  cPropName := hb_strToUtf8(IIF(HHasKey(hPropData, "name"), hPropData["name"], ""))
                  IF AScan(hCollated[cGroupName], cPropName) == 0
                     AAdd(hCollated[cGroupName], cPropName)
                  ENDIF
               ENDIF
            ENDIF
         ENDIF
      ENDIF
   NEXT
   
RETURN hCollated

FUNCTION CollatePropertiesByGroup(aProductProps, aParentProps)
   LOCAL hCollated := {=>}, hProp, cGroupName, cGroupKey
   LOCAL aAllProps := {}, nX
   LOCAL lExists

   
   // Combine all properties (product + parent)
   FOR EACH hProp IN aProductProps
      AAdd(aAllProps, hProp)
   NEXT
   
   FOR EACH hProp IN aParentProps
      AAdd(aAllProps, hProp)
   NEXT
   
   // Group properties by group name
   FOR EACH hProp IN aAllProps
      IF HB_IsHash(hProp) .AND. HHasKey(hProp, "group_name") .AND. !Empty(hProp["group_name"])
         cGroupName := hb_strToUtf8(hProp["group_name"])
         
         // Initialize group if not exists
         IF !HHasKey(hCollated, cGroupName)
            hCollated[cGroupName] := {}
         ENDIF
         
         // Add property to group (avoid duplicates by checking if property with same name already exists)
         lExists := .F.         
         FOR nX := 1 TO Len(hCollated[cGroupName])
            IF hCollated[cGroupName][nX] == hProp["name"]
               lExists := .T.
               EXIT
            ENDIF
         NEXT
         
         IF !lExists
            AAdd(hCollated[cGroupName], hb_strToUtf8(hProp["name"]))
         ENDIF
      ENDIF
   NEXT
   
RETURN hCollated*/

FUNCTION BuildDescriptionFilter(cSearchExpression)
   LOCAL cResult
   
   IF Empty(cSearchExpression)
      RETURN ""
   ENDIF
   
   // Convert to uppercase for case-insensitive search
   cResult := ParseExpression(Upper(AllTrim(cSearchExpression)))
   
RETURN cResult

STATIC FUNCTION ParseExpression(cExpr)
   LOCAL cResult := ""
   LOCAL nPos := 1
   LOCAL nLen := Len(cExpr)
   LOCAL cChar, nParenCount := 0
   LOCAL nStart, cSubExpr
   
   // Handle parentheses by finding matching pairs and recursively parsing
   DO WHILE nPos <= nLen
      cChar := SubStr(cExpr, nPos, 1)
      
      IF cChar == "("
         // Find matching closing parenthesis
         nStart := nPos + 1
         nParenCount := 1
         nPos++
         
         DO WHILE nPos <= nLen .AND. nParenCount > 0
            cChar := SubStr(cExpr, nPos, 1)
            IF cChar == "("
               nParenCount++
            ELSEIF cChar == ")"
               nParenCount--
            ENDIF
            nPos++
         ENDDO
         
         IF nParenCount == 0
            // Extract content inside parentheses and parse recursively
            cSubExpr := SubStr(cExpr, nStart, nPos - nStart - 1)
            cResult += "(" + ParseExpression(cSubExpr) + ")"
         ELSE
            // Unmatched parenthesis - treat as literal
            cResult += "("
            nPos := nStart
         ENDIF
      ELSE
         // Process non-parenthetical content
         nStart := nPos
         DO WHILE nPos <= nLen .AND. SubStr(cExpr, nPos, 1) != "("
            nPos++
         ENDDO
         
         cSubExpr := SubStr(cExpr, nStart, nPos - nStart)
         IF !Empty(AllTrim(cSubExpr))
            cResult += ParseSimpleExpression(cSubExpr)
         ENDIF
      ENDIF
   ENDDO
   
RETURN cResult

STATIC FUNCTION ParseSimpleExpression(cExpr)
   LOCAL cResult := ""
   LOCAL nStart := 1
   LOCAL nAnd, nOr, nNext
   LOCAL cTerm, cOperator
   LOCAL lFirstTerm := .T.
   
   // If no operators, do simple search
   IF !(" AND " $ cExpr) .AND. !(" OR " $ cExpr)
      cTerm := AllTrim(cExpr)
      IF !Empty(cTerm)
         // Escape quotes in the search term
         cTerm := StrTran(cTerm, '"', "'")
         RETURN '"' + cTerm + '" $ cValue'
      ENDIF
      RETURN ""
   ENDIF
   
   // Parse terms with AND/OR operators
   DO WHILE nStart <= Len(cExpr)
      // Find next operator
      nAnd := HB_At(" AND ", cExpr, nStart)
      nOr := HB_At(" OR ", cExpr, nStart)
      
      // Determine which operator comes first
      IF nAnd > 0 .AND. (nOr == 0 .OR. nAnd < nOr)
         nNext := nAnd
         cOperator := "AND"
      ELSEIF nOr > 0
         nNext := nOr
         cOperator := "OR"
      ELSE
         nNext := 0
      ENDIF
      
      // Extract the term
      IF nNext > 0
         cTerm := AllTrim(SubStr(cExpr, nStart, nNext - nStart))
         nStart := nNext + IIF(cOperator == "AND", 5, 4)  // Skip " AND " or " OR "
      ELSE
         cTerm := AllTrim(SubStr(cExpr, nStart))
         nStart := Len(cExpr) + 1
      ENDIF
      
      // Build the filter expression
      IF !Empty(cTerm)
         IF !lFirstTerm
            cResult += IIF(cOperator == "AND", " .AND. ", " .OR. ")
         ENDIF
         
         // Remove quotes in the search term
         cTerm := StrTran(cTerm, '"', "")         
         cResult += '"' + cTerm + '" $ cValue'
         lFirstTerm := .F.
      ENDIF
   ENDDO
   
RETURN cResult

FUNCTION MCP_Tool_Get_Customer_Orders(hArgs)
   LOCAL hResult := {=>}
   LOCAL aOrders := {}
   LOCAL hOrder
   LOCAL cCustomer
   LOCAL oAuftrag,oKunde
   LOCAL cStatus := "all"
  
   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{;
            "customer_number"=>{"type"=>"number","description"=>"Customer number"},;
            "status_filter"=>{"type"=>"string","description"=>"Filter by status (open, completed, all)"};
         },;
         "required"=>{"customer_number"};
      }
      hResult["description"] := "Get all orders for a specific customer"
      RETURN hResult
   ENDIF

   IF HHasKey(hArgs,"status_filter") .AND. hArgs["status_filter"] $ {"open","completed"}
      cStatus := hArgs["status_filter"]
   ENDIF
   NetUse("auftrag","ab")  // Ensure order database is available
   oKunde := Adresse():New()
   IF HHasKey(hArgs,"customer_number") .AND. ! Empty(hArgs["customer_number"]) .AND. oKunde:Load(hArgs["customer_number"])
      hResult["customer"] := oKunde:Kunde
      
      ab->(DbSetOrder(2))  // Assume order 2 is by customer number
      IF ab->(DbSeek(oKunde:Kunde))
         WHILE ab->kundma == oKunde:Kunde .AND. !ab->(Eof())
            oAuftrag := Auftrag():New(.F.)
            IF cStatus == "all" .OR. (cStatus == "open" .AND. !oAuftrag:Erledigt) .OR. (cStatus == "completed" .AND. oAuftrag:Erledigt)
               hOrder := {=>}
               hOrder["order_number"] := oAuftrag:Abnr
               hOrder["date"] := oAuftrag:Besda
               hOrder["completed"] := oAuftrag:Erledigt
               hOrder["total"] := oAuftrag:total
            
               AAdd(aOrders, hOrder)
            ENDIF
            ab->(DbSkip())
         ENDDO
      ENDIF
      
      hResult["orders"] := aOrders
      hResult["count"] := Len(aOrders)
      hResult["status"] := "found"
   ELSE
      hResult["status"] := "error"
      hResult["message"] := "Invalid customer number"
   ENDIF
   
RETURN hResult

/*FUNCTION MCP_Tool_Get_Property_Groups(hArgs)
   LOCAL hResult := {=>}
   LOCAL oSW, hResponse, hSendData
   LOCAL aIncluded, hItem, hGroupData, hOptionData
   LOCAL hGroups := {=>}, cGroupId, cGroupName
   LOCAL hOptions := {=>}, hOptionItem
   
   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{=>},;
         "required"=>{};
      }
      hResult["description"] := "Get all available product properties and their options for filtering products. " + ;
                                "Use this BEFORE searching products to discover filterable properties like: " + ;
                                "- Colors (red, blue, green...); " + ;
                                "- Materials (steel, aluminum, plastic...); " + ;
                                "- Sizes (S, M, L, XL...); " + ;
                                "- Technical specifications. " + ;
                                "Example workflow: " + ;
                                "1. Call get_property_groups to see available properties; " + ;
                                "2. Note the property IDs you need; " + ;
                                "3. Use those IDs in get_catalogue with property_ids parameter to filter products. " + ;
                                "Returns a hash where keys are property group names and values are arrays of available options."
      RETURN hResult
   ENDIF
   
   // Initialize API
   oSW := ShopwareApi():New(.T.)
   IF !oSW:Auth()
      hResult["error"] := "Shopware authentication failed"
      hResult["status"] := "error"
      RETURN hResult
   ENDIF
   
   // Build search request for property groups with options
   hSendData := {;
      "associations"=>{;
         "options"=>{};  // Include all options for each group
      },;
      "limit"=>500;  // Get all groups
   }
   
   // Execute API call
   BEGIN SEQUENCE
      hResponse := oSW:Execute("search/property-group", "POST", hSendData)
      
      IF HB_IsHash(hResponse) .AND. HHasKey(hResponse, "data") .AND. HB_IsArray(hResponse["data"])
         // First collect all groups from data
         FOR EACH hItem IN hResponse["data"]
            IF HB_IsHash(hItem) .AND. HHasKey(hItem, "attributes") .AND. HB_IsHash(hItem["attributes"])
               hGroupData := hItem["attributes"]
               cGroupId := IIF(HHasKey(hItem, "id"), hItem["id"], "")
               cGroupName := IIF(HHasKey(hGroupData, "name"), hb_strToUtf8(hGroupData["name"]), "")

               IF !Empty(cGroupId) .AND. !Empty(cGroupName)
                  hGroups[cGroupId] := cGroupName
                  hOptions[cGroupName] := {}
               ENDIF
            ENDIF
         NEXT
         
         // Then collect options from included section
         IF HHasKey(hResponse, "included") .AND. HB_IsArray(hResponse["included"])
            aIncluded := hResponse["included"]
            
            FOR EACH hItem IN aIncluded
               IF HB_IsHash(hItem) .AND. HHasKey(hItem, "type") .AND. hItem["type"] == "property_group_option"
                  IF HHasKey(hItem, "attributes") .AND. HB_IsHash(hItem["attributes"])
                     hOptionData := hItem["attributes"]
                     
                     hOptionItem := {=>}
                     hOptionItem["id"] := IIF(HHasKey(hItem, "id"), hItem["id"], "")
                     hOptionItem["name"] := IIF(HHasKey(hOptionData, "name"), hb_strToUTf8(hOptionData["name"]), "")
                     hOptionItem["position"] := IIF(HHasKey(hOptionData, "position"), hOptionData["position"], 0)
                     
                     // Add color if available
                     IF HHasKey(hOptionData, "colorHexCode") .AND. hOptionData["colorHexCode"] != NIL
                        hOptionItem["color"] := hOptionData["colorHexCode"]
                     ENDIF
                     
                     // Add media ID if available
                     IF HHasKey(hOptionData, "mediaId") .AND. hOptionData["mediaId"] != NIL
                        hOptionItem["media_id"] := hOptionData["mediaId"]
                     ENDIF
                     
                     // Find which group this option belongs to
                     cGroupId := IIF(HHasKey(hOptionData, "groupId"), hOptionData["groupId"], "")
                     IF !Empty(cGroupId) .AND. HHasKey(hGroups, cGroupId)
                        cGroupName := hGroups[cGroupId]
                        IF HHasKey(hOptions, cGroupName)
                           AAdd(hOptions[cGroupName], hOptionItem)
                        ENDIF
                     ENDIF
                  ENDIF
               ENDIF
            NEXT
         ENDIF
         
         // Sort options within each group by position
         FOR EACH cGroupName IN HB_HKeys(hOptions)
            ASort(hOptions[cGroupName],,, {|a,b| a["position"] < b["position"]})
         NEXT
         
         hResult := hOptions
         hResult["status"] := "success"
      ELSE
         hResult["error"] := "Failed to retrieve property groups"
         hResult["status"] := "error"
      ENDIF
      
   RECOVER USING cMessage
      hResult["error"] := "API Error: " + cMessage
      hResult["status"] := "error"
   END SEQUENCE
   
RETURN hResult*/

/*FUNCTION MCP_Tool_Get_Catalogue(hArgs)
   LOCAL hResult := {=>}
   LOCAL oSW, hResponse, hSendData
   LOCAL aFilters := {}, hFilter
   LOCAL nLimit, nPage
   LOCAL aProducts := {}, hProduct, hProductData
   LOCAL cSearchTerm, aPropertyIds, cPropId
   LOCAL hProd := {=>}
   LOCAL cMessage  // For error handling
   LOCAL aCleanPropertyIds
   LOCAL aAllProducts := {}, aParentIds := {}, hParentData := {=>}
   LOCAL aProductProps, aParentProps, aCombinedProps, lHasAllProps
   LOCAL hParentSendData, hParentResponse
   LOCAL aProductProperties, aParentProperties
   LOCAL aCombinedIds, cId
   
   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{;
            "search"=>{"type"=>"string","description"=>"Search term for product name or number"},;
            "active"=>{"type"=>"boolean","description"=>"Filter by active status"},;
            "available"=>{"type"=>"boolean","description"=>"Filter by availability"},;
            "manufacturer_id"=>{"type"=>"string","description"=>"Filter by manufacturer ID"},;
            "property_ids"=>{"type"=>"array","items"=>{"type"=>"string"},"description"=>"Filter by property option IDs"},;
            "min_price"=>{"type"=>"number","description"=>"Minimum price filter"},;
            "max_price"=>{"type"=>"number","description"=>"Maximum price filter"},;
            "min_stock"=>{"type"=>"integer","description"=>"Minimum stock level filter"},;
            "max_stock"=>{"type"=>"integer","description"=>"Maximum stock level filter"},;
            "in_stock"=>{"type"=>"boolean","description"=>"Filter products that are in stock (stock > 0)"},;
            "limit"=>{"type"=>"integer","description"=>"Number of results to return (default: 50, max: 500)"},;
            "page"=>{"type"=>"integer","description"=>"Page number for pagination (default: 1)"};
         },;
         "required"=>{};
      }
      hResult["description"] := "Search and filter products from our online shop. This is the PRIMARY TOOL for product searches. " + ;
                                "Supports filtering by: " + ;
                                "- Product properties (color, size, material, etc.) - use get_property_groups first to see available options; " + ;
                                "- Search terms (product name/number); " + ;
                                "- Stock levels and availability; " + ;
                                "- Price ranges; " + ;
                                "- Manufacturer. " + ;
                                "Examples: " + ;
                                '- Find products with specific properties: {"property_ids": ["prop-id-1", "prop-id-2"]} (ALL properties must match); ' + ;
                                '- Find products in stock under 50 EUR: {"in_stock": true, "max_price": 50}; ' + ;
                                '- Search by name: {"search": "cable"}; ' + ;
                                '- Combine filters: {"search": "resistor", "property_ids": ["color-red-id"], "in_stock": true}. ' + ;
                                "Always prefer this tool over search_articles for online shop products."
      RETURN hResult
   ENDIF
   
   // Parse parameters
   nLimit := IIF(HHasKey(hArgs, "limit") .AND. HB_IsNumeric(hArgs["limit"]), Min(hArgs["limit"], 500), 50)
   nPage := IIF(HHasKey(hArgs, "page") .AND. HB_IsNumeric(hArgs["page"]), Max(hArgs["page"], 1), 1)
   
   // Initialize API
   oSW := ShopwareApi():New(.T.)
   IF !oSW:Auth()
      hResult["error"] := "Shopware authentication failed"
      hResult["status"] := "error"
      RETURN hResult
   ENDIF
   
   // Build filters
   // Search term filter
   IF HHasKey(hArgs, "search") .AND. !Empty(hArgs["search"])
      cSearchTerm := AllTrim(hArgs["search"])
      AAdd(aFilters, {;
         "type"=>"multi",;
         "operator"=>"or",;
         "queries"=>{;
            {"type"=>"contains", "field"=>"name", "value"=>cSearchTerm},;
            {"type"=>"contains", "field"=>"productNumber", "value"=>cSearchTerm};
         };
      })
   ENDIF
   
   // Active filter
   IF HHasKey(hArgs, "active") .AND. HB_IsLogical(hArgs["active"])
      AAdd(aFilters, {"type"=>"equals", "field"=>"active", "value"=>hArgs["active"]})
   ENDIF
   
   // Available filter
   IF HHasKey(hArgs, "available") .AND. HB_IsLogical(hArgs["available"])
      AAdd(aFilters, {"type"=>"equals", "field"=>"available", "value"=>hArgs["available"]})
   ENDIF
   
   // Manufacturer filter
   IF HHasKey(hArgs, "manufacturer_id") .AND. !Empty(hArgs["manufacturer_id"])
      AAdd(aFilters, {"type"=>"equals", "field"=>"manufacturerId", "value"=>hArgs["manufacturer_id"]})
   ENDIF
   
   // Property filter - combine propertyIds (inherited) and optionIds (product-specific)
   // Store clean property IDs for later use
   aCleanPropertyIds := {}
   IF HHasKey(hArgs, "property_ids") .AND. HB_IsArray(hArgs["property_ids"]) .AND. Len(hArgs["property_ids"]) > 0
      FOR EACH cPropId IN hArgs["property_ids"]
         IF !Empty(cPropId)
            AAdd(aCleanPropertyIds, cPropId)
         ENDIF
      NEXT
   ENDIF
   
   // Price range filter
   IF HHasKey(hArgs, "min_price") .AND. HB_IsNumeric(hArgs["min_price"])
      AAdd(aFilters, {"type"=>"range", "field"=>"price.gross", "parameters"=>{"gte"=>hArgs["min_price"]}})
   ENDIF
   
   IF HHasKey(hArgs, "max_price") .AND. HB_IsNumeric(hArgs["max_price"])
      AAdd(aFilters, {"type"=>"range", "field"=>"price.gross", "parameters"=>{"lte"=>hArgs["max_price"]}})
   ENDIF
   
   // Stock level filters
   IF HHasKey(hArgs, "min_stock") .AND. HB_IsNumeric(hArgs["min_stock"])
      AAdd(aFilters, {"type"=>"range", "field"=>"stock", "parameters"=>{"gte"=>hArgs["min_stock"]}})
   ENDIF
   
   IF HHasKey(hArgs, "max_stock") .AND. HB_IsNumeric(hArgs["max_stock"])
      AAdd(aFilters, {"type"=>"range", "field"=>"stock", "parameters"=>{"lte"=>hArgs["max_stock"]}})
   ENDIF
   
   // In stock filter (stock > 0)
   IF HHasKey(hArgs, "in_stock") .AND. HB_IsLogical(hArgs["in_stock"]) .AND. hArgs["in_stock"]
      AAdd(aFilters, {"type"=>"range", "field"=>"stock", "parameters"=>{"gt"=>0}})
   ENDIF
   
   // Build search request
   hSendData := {;
      "limit"=>nLimit,;
      "page"=>nPage,;
      "associations"=>{;
         "manufacturer"=>{},;
         "properties"=>{"associations"=>{"group"=>{}}},;
         "options"=>{"associations"=>{"group"=>{}}};
      },;
      "includes"=>{;
         "product"=>{;
            "id", "productNumber", "name", "description", "active", "available",;
            "stock", "price", "ean", "manufacturerNumber", "weight", "width", "height", "length",;
            "propertyIds", "optionIds", "parentId";
         };
      };
   }
   
   // Execute search
   BEGIN SEQUENCE
      // Special handling for property filters - need to check ALL properties match
      IF Len(aCleanPropertyIds) > 0
         // Create AND filter for ALL properties - each property must be present
         FOR EACH cPropId IN aCleanPropertyIds
            // Create OR filter to check property in both propertyIds and optionIds
            AAdd(aFilters, {;
               "type"=>"multi",;
               "operator"=>"or",;
               "queries"=>{;
                  {"type"=>"contains", "field"=>"propertyIds", "value"=>cPropId},;
                  {"type"=>"contains", "field"=>"optionIds", "value"=>cPropId};
               };
            })
         NEXT
      ENDIF
      
      // Update filter in send data
      IF Len(aFilters) > 0
         IF Len(aFilters) == 1
            hSendData["filter"] := aFilters
         ELSE
            hSendData["filter"] := {{;
               "type"=>"multi",;
               "operator"=>"and",;
               "queries"=>aFilters;
            }}
         ENDIF
      ENDIF
      
      hResponse := oSW:Execute("search/product", "POST", hSendData)
      
      IF HB_IsHash(hResponse) .AND. HHasKey(hResponse, "data") .AND. HB_IsArray(hResponse["data"])
         
         // Process all products (already filtered by API)
         FOR EACH hProduct IN hResponse["data"]
            IF HB_IsHash(hProduct) .AND. HHasKey(hProduct, "attributes")
               hProductData := hProduct["attributes"]
               
               // Build product result    
               hProd := {=>}           
               hProd["id"] := IIF(HHasKey(hProduct, "id"), hProduct["id"], "")
               hProd["product_number"] := IIF(HHasKey(hProductData, "productNumber"), hProductData["productNumber"], "")
               hProd["name"] := IIF(HHasKey(hProductData, "name"), hb_strtoutf8(hProductData["name"]), "")
               hProd["description"] := IIF(HHasKey(hProductData, "description"), hb_strtoutf8(hProductData["description"]), "")
               hProd["active"] := IIF(HHasKey(hProductData, "active"), hProductData["active"], .F.)
               hProd["available"] := IIF(HHasKey(hProductData, "available"), hProductData["available"], .F.)
               hProd["stock"] := IIF(HHasKey(hProductData, "stock"), hProductData["stock"], 0)
               hProd["ean"] := IIF(HHasKey(hProductData, "ean"), hProductData["ean"], "")
               hProd["parent_id"] := IIF(HHasKey(hProductData, "parentId"), hProductData["parentId"], "")
               hProd["property_ids"] := IIF(HHasKey(hProductData, "propertyIds"), hProductData["propertyIds"], {})
               hProd["option_ids"] := IIF(HHasKey(hProductData, "optionIds").AND.hProductData["optionIds"]!=NIL, hProductData["optionIds"], {})
               
               // Combine propertyIds (inherited) and optionIds (product-specific) for complete property list
               aCombinedIds := AClone(hProd["property_ids"])
               FOR EACH cId IN hProd["option_ids"]
                  IF AScan(aCombinedIds, cId) == 0
                     AAdd(aCombinedIds, cId)
                  ENDIF
               NEXT
               hProd["all_property_ids"] := aCombinedIds
               
               // Price information
               IF HHasKey(hProductData, "price") .AND. HB_IsArray(hProductData["price"]) .AND. Len(hProductData["price"]) > 0
                  hProd["price"] := {;
                     "net" => IIF(HHasKey(hProductData["price"][1], "net"), hProductData["price"][1]["net"], 0),;
                     "gross" => IIF(HHasKey(hProductData["price"][1], "gross"), hProductData["price"][1]["gross"], 0);
                  }
               ENDIF
               
               // Add properties from included section using combined property IDs
               hProd["properties"] := GetCombinedPropertiesFromIncluded(hResponse, hProd["all_property_ids"])
               
               AAdd(aProducts, hProd)
            ENDIF
         NEXT
         
         hResult["products"] := aProducts
         //debugging information
         hResult["respone"] := hResponse  // Include full response for debugging
         IF HHasKey(hSendData, "filter")
            hResult["search_filter"] := hSendData["filter"]  // Show what filter was used
         ENDIF         
         hResult["args"] := hArgs  // Include original arguments for debugging
         //end debugging information
         hResult["total"] := IIF(HHasKey(hResponse, "total"), hResponse["total"], Len(aProducts))
         hResult["page"] := nPage
         hResult["limit"] := nLimit
         hResult["status"] := "success"
      ELSE
         // More detailed error information
         IF HB_IsHash(hResponse)
            IF HHasKey(hResponse, "errors") .AND. HB_IsArray(hResponse["errors"]) .AND. Len(hResponse["errors"]) > 0
               hResult["error"] := "API Error: " + IIF(HHasKey(hResponse["errors"][1], "detail"), hResponse["errors"][1]["detail"], "Unknown error")
               hResult["api_errors"] := hResponse["errors"]
            ELSEIF HHasKey(hResponse, "data") .AND. HB_IsArray(hResponse["data"]) .AND. Len(hResponse["data"]) == 0
               hResult["error"] := "No products found matching the search criteria"
               hResult["search_filter"] := hSendData["filter"]  // Show what filter was used
            ELSE
               hResult["error"] := "Unexpected response structure from API"
               hResult["debug_response_keys"] := IIF(HB_IsHash(hResponse), HB_HKeys(hResponse), {})
            ENDIF
         ELSE
            hResult["error"] := "Invalid response from Shopware API (not a hash)"
            hResult["response_type"] := ValType(hResponse)
         ENDIF
         hResult["status"] := "error"
         hResult["request_data"] := hSendData  // Include the request that was sent
      ENDIF
      
   RECOVER      
      hResult["status"] := "error"
      hResult["request_data"] := hSendData  // Include the request that was sent
   END SEQUENCE
   
RETURN hResult*/

FUNCTION MCP_Resources_List(hRequest, xId)
   LOCAL aResources := {}
   LOCAL aFuncNames, cFuncName, cResourceName, hResource
   
   // Dynamically discover all MCP_Resource_* functions
   aFuncNames := GetFunctionsWithPrefix("MCP_RESOURCE_")
   
   FOR EACH cFuncName IN aFuncNames
      // Convert MCP_RESOURCE_CUSTOMERS to customers
      cResourceName := Lower(SubStr(cFuncName, 14))  // Remove "MCP_RESOURCE_"
      
      hResource := {=>}
      hResource["uri"] := TraderUrl("trader://" + cResourceName)
      hResource["name"] := GetResourceName(cResourceName)
      hResource["description"] := GetResourceDescription(cResourceName)
      hResource["mimeType"] := "application/json"
      
      AAdd(aResources, hResource)
   NEXT
   
RETURN CreateSuccessResponse({"resources"=>aResources}, xId)

FUNCTION GetResourceName(cResourceName)
   LOCAL hNames := {;
      "customers" => "Customer Database",;
      "orders" => "Sales Orders";
   }
   
RETURN IIF(HHasKey(hNames, cResourceName), hNames[cResourceName], cResourceName)

FUNCTION GetResourceDescription(cResourceName)
   LOCAL hDescriptions := {;
      "customers" => "Complete customer database with addresses and contact information",;
      "orders" => "All sales orders in the system";
   }
   
RETURN IIF(HHasKey(hDescriptions, cResourceName), hDescriptions[cResourceName], "Resource: " + cResourceName)

FUNCTION MCP_Resources_Read(hRequest, xId)
   LOCAL hParams := hRequest["params"]
   LOCAL cUri := hParams["uri"]
   LOCAL cResourceName, cFunctionName, cContent, hResourceData
   
   // Extract resource name from URI: trader://customers -> customers
   IF Left(cUri, 9) == "trader://"
      cResourceName := SubStr(cUri, 10)
      // Convert to function name: customers -> MCP_Resource_Customers
      cFunctionName := "MCP_Resource_" + cResourceName
      
      // Check if function exists and call it dynamically
      IF Type(cFunctionName + "()") != "U"
         hResourceData := HB_ExecFromArray(cFunctionName, {})
      
         cContent := HB_JsonEncode(hResourceData)
      ELSE
         RETURN CreateErrorResponse("Resource not found: " + cUri + " (function: " + cFunctionName + ")", xId)
      ENDIF
   ELSE
      RETURN CreateErrorResponse("Invalid resource URI: " + cUri, xId)
   ENDIF

RETURN CreateSuccessResponse({"contents"=>{{"uri"=>cUri,"mimeType"=>"application/json","text"=>cContent}}}, xId)

FUNCTION MCP_Resource_Customers()
   LOCAL hResult := {=>}
   LOCAL aCustomers := {}
   
   LOCAL hCustomer
   NetUse("engkund","ku")  // Ensure customer database is available
   ku->(dbSetOrder( 2 ))
   ku->(dbSeek( "K") )
   
   WHILE !ku->(Eof()) .AND. ku->Group == "K" 
      hCustomer := {=>}
      hCustomer["number"] := ku->nummer
      hCustomer["matchcode"] := Trim(ku->Kunde)
      hCustomer["name"] := AllTrim(ku->name1)
      hCustomer["city"] := AllTrim(ku->town)
      
      AAdd(aCustomers, hCustomer)
      
      ku->(DbSkip())
   ENDDO
   
   hResult["customers"] := aCustomers
   
RETURN hResult

// Removed - converted to MCP_Tool_Search_Articles
/*
FUNCTION MCP_Resource_Articles()
   LOCAL hResult := {=>}
   LOCAL aArticles := {}
   LOCAL nCount := 0
   LOCAL hArticle

   NetUse("artikel","art")  // Ensure article database is available

   art->(DbGoTop())
   
   WHILE !art->(Eof()) //.AND. nCount < 10  // Limit to first 10 for demo
      IF ! art->Obsolete
         hArticle := {=>}
         hArticle["matchcode"] := AllTrim(art->matchcode)
         hArticle["description"] := AllTrim(art->artikel)
         hArticle["stock"] := art->bestand
         
         AAdd(aArticles, hArticle)
         nCount++
      ENDIF
      art->(DbSkip())
   ENDDO
   
   hResult["articles"] := aArticles
   
RETURN hResult
*/

FUNCTION MCP_Resource_Orders()
   LOCAL hResult := {=>}
   LOCAL aOrders := {}
   LOCAL nCount := 0
   LOCAL hOrder,oPos

   NetUse("engauf","auf")
   auf->(DbGoTop())
   WHILE !auf->(Eof()) .AND. nCount < 10  // Limit to first 10 for demo
   
      hOrder := {=>}
      hOrder["order_number"] := auf->abnr
      hOrder["customer"] := auf->kundma
      hOrder["date"] := auf->besda
      hOrder["completed"] := AUF->BESTAT == 3 .OR. auf->bestat == 7
      hOrder["article"] := AllTrim(AUF->Matchcode)      
      hOrder["quantity"] := AUF->VkQty
      hOrder["open_quantity"] := AUF->VkQty - AUF->GelQty
      hOrder["price"] := AUF->VkPr/AUF->Pe
   

      
      AAdd(aOrders, hOrder)
      nCount++
      auf->(DbSkip())
   ENDDO
   
   hResult["orders"] := aOrders
   
RETURN hResult

FUNCTION CreateSuccessResponse(hResult, xId)
   LOCAL hResponse := {=>}
   
   hResponse["jsonrpc"] := "2.0"
   hResponse["id"] := xId
   hResponse["result"] := hResult
   
RETURN HB_JsonEncode(hResponse)

FUNCTION CreateErrorResponse(cMessage, xId)
   LOCAL hResponse := {=>}
   LOCAL hError := {=>}
   
   hError["code"] := -32603  // Internal error code
   hError["message"] := cMessage
   
   hResponse["jsonrpc"] := "2.0"
   hResponse["id"] := xId  // Keep original ID, even if null
   hResponse["error"] := hError
   
RETURN HB_JsonEncode(hResponse)

FUNCTION MCPErrorHandler(oError, nStdOut)
   LOCAL hResponse := {=>}
   LOCAL hError := {=>}
   LOCAL cErrorMsg,cResponse
   
   cResponse := CreateErrorResponse("Invalid JSON in request", "")

   /*// Build error message
   cErrorMsg := "Runtime Error: " + oError:description
   IF !Empty(oError:operation)
      cErrorMsg += " (" + oError:operation + ")"
   ENDIF
   IF !Empty(oError:filename)
      cErrorMsg += " in " + oError:filename + ":" + AllTrim(Str(oError:line))
   ENDIF
   
   // Create JSON-RPC error response
   hError["code"] := -32603  // Internal error
   hError["message"] := cErrorMsg
   hError["data"] := {;
      "subsystem"=>oError:subsystem,;
      "subcode"=>oError:subcode,;
      "severity"=>oError:severity;
   }
   
   hResponse["jsonrpc"] := "2.0"
   hResponse["id"] := ""
   hResponse["error"] := hError
   
   // Write error response to stdout
   FWrite(nStdOut, HB_JsonEncode(hResponse) + Chr(10))*/
   
    FWrite(nStdOut, cResponse + Chr(10))
   
RETURN NIL

//---------------------------------------------------------------------------
// David Inbox tools — read-only access to the Tobit David InfoCenter.
//
// These wrap the David OLE API exposed by source\david.prg (MailConnect /
// DV_GetMailAccount → oAccount) which is linked into the trader binary. All
// OLE access is guarded so a bad item or a missing David connection returns a
// clean status instead of crashing the MCP loop.
//---------------------------------------------------------------------------

// Convert a David (Windows-ANSI) string to UTF-8 for JSON output. Translate
// CP1252 (DEWIN) to UTF-8 directly instead of the old ANSI->OEM->UTF-8 chain,
// which silently depended on the process' selected codepage matching the OS
// OEM codepage.
STATIC FUNCTION DV_Utf8(cStr)
   IF ValType(cStr) != "C"
      RETURN ""
   ENDIF
RETURN hb_Translate(cStr, "DEWIN", "UTF8")

// Serialize a David message time (timestamp, occasionally a date) to a
// sortable ISO-ish string.
STATIC FUNCTION DV_DateStr(xTime)
   LOCAL cResult := ""
   BEGIN SEQUENCE
      DO CASE
      CASE ValType(xTime) == "T"
         cResult := HB_TSToStr(xTime)
      CASE ValType(xTime) == "D" .AND. ! Empty(xTime)
         cResult := StrZero(Year(xTime),4) + "-" + StrZero(Month(xTime),2) + "-" + StrZero(Day(xTime),2)
      OTHERWISE
         cResult := ""
      ENDCASE
   RECOVER
      cResult := ""
   END SEQUENCE
RETURN cResult

// Resolve the David archive object for the requested mailbox, connecting first.
// Returns NIL if David is not available.
STATIC FUNCTION Inbox_Archive(cMailbox)
   LOCAL oAccount, oArchive := NIL, nArchive

   IF ValType(cMailbox) != "C"
      cMailbox := "inbox"
   ENDIF
   nArchive := IIF(Lower(cMailbox) == "common", DvArchiveCommon, DvArchivePersonalIn)

   BEGIN SEQUENCE
      MailConnect()  // idempotent - no-op if already connected
      oAccount := DV_GetMailAccount()
      IF oAccount != NIL
         oArchive := oAccount:GetSpecialArchive(nArchive)
      ENDIF
   RECOVER
      oArchive := NIL
   END SEQUENCE
RETURN oArchive

// Read/unread state of a message via the documented DvApi archive-item
// property Viewed (Viewed = message has been read). Returns NIL when the
// property does not answer - callers then omit the field instead of guessing.
STATIC FUNCTION DV_Unread(oItem)
   LOCAL xVal := NIL

   BEGIN SEQUENCE
      xVal := oItem:Viewed
   RECOVER
      xVal := NIL
   END SEQUENCE
   IF ValType(xVal) == "N"  // numeric representation: 0 = not viewed
      xVal := xVal != 0
   ENDIF
RETURN IIF(ValType(xVal) == "L", ! xVal, NIL)

// Build a one-line summary hash for a single message. Each property read is
// guarded so one malformed item never aborts a listing.
STATIC FUNCTION Inbox_Summary(oItem)
   LOCAL hMsg := {=>}
   LOCAL xUnread

   hMsg["id"] := ""
   hMsg["subject"] := ""
   hMsg["sender"] := ""
   hMsg["date"] := ""
   hMsg["recipient_count"] := 0
   hMsg["attachment_count"] := 0
//oItem:_ID
//
   BEGIN SEQUENCE ; hMsg["id"]      := oItem:Fields:Item("FileName"):Value                  ; RECOVER ; END SEQUENCE
   BEGIN SEQUENCE ; hMsg["subject"] := DV_Utf8(oItem:Subject)        ; RECOVER ; END SEQUENCE
   BEGIN SEQUENCE ; hMsg["sender"] := DV_Utf8(oItem:Fields:Item("SRFrom"):Value); RECOVER; hMsg["sender"] := ""; END SEQUENCE
   BEGIN SEQUENCE ; hMsg["date"]    := DV_DateStr(oItem:StatusTime)  ; RECOVER ; END SEQUENCE
   BEGIN SEQUENCE ; hMsg["recipient_count"]  := oItem:Recipients:Count  ; RECOVER ; END SEQUENCE
   BEGIN SEQUENCE ; hMsg["attachment_count"] := oItem:Attachments:Count ; RECOVER ; END SEQUENCE
   xUnread := DV_Unread(oItem)
   IF xUnread != NIL
      hMsg["unread"] := xUnread
   ENDIF
RETURN hMsg

FUNCTION MCP_Tool_List_Inbox(hArgs)
   LOCAL hResult := {=>}
   LOCAL oArchive, oItem, nI, nCount
   LOCAL cMailbox := "inbox", nLimit := 50, nOffset := 0
   LOCAL nScan, nFirst
   LOCAL lUnreadOnly := .F., lAnyReadState := .F.
   LOCAL hMsg
   LOCAL aMessages := {}, aPage := {}

   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{;
            "mailbox"=>{"type"=>"string","enum"=>{"inbox","common"},"description"=>"Which mailbox to list: 'inbox' (personal Inbox, default) or 'common' (shared archive)"},;
            "unread_only"=>{"type"=>"boolean","description"=>"If true, return only unread messages (default false)"},;
            "limit"=>{"type"=>"integer","description"=>"Maximum number of messages to return (default 50)"},;
            "offset"=>{"type"=>"integer","description"=>"Number of newest messages to skip (default 0)"},;
            "scan_limit"=>{"type"=>"integer","description"=>"Maximum number of archive entries to inspect, newest end first (default 200, max 1000). Larger values are slower - every entry is a David API round-trip"};
         },;
         "required"=>{};
      }
      hResult["description"] := "List messages in the David Inbox (or Common archive), newest first, optionally unread only. " + ;
                                "Only the newest 'scan_limit' archive entries are inspected, so 'total' refers to the scanned window, not the whole mailbox"
      RETURN hResult
   ENDIF

   IF HHasKey(hArgs, "mailbox") .AND. ! Empty(hArgs["mailbox"])
      cMailbox := Lower(AllTrim(hArgs["mailbox"]))
   ENDIF
   lUnreadOnly := HHasKey(hArgs, "unread_only") .AND. HB_IsLogical(hArgs["unread_only"]) .AND. hArgs["unread_only"]
   IF HHasKey(hArgs, "limit") .AND. HB_IsNumeric(hArgs["limit"]) .AND. hArgs["limit"] > 0
      nLimit := hArgs["limit"]
   ENDIF
   IF HHasKey(hArgs, "offset") .AND. HB_IsNumeric(hArgs["offset"]) .AND. hArgs["offset"] > 0
      nOffset := hArgs["offset"]
   ENDIF

   // Reading a message summary is several OLE round-trips per item, so a full
   // scan of a big mailbox takes minutes and the MCP client times out long
   // before. Only inspect a window at the newest end of the archive (archive
   // entries are appended chronologically) and sort/page within that window.
   nScan := Max(nOffset + nLimit, 200)
   IF HHasKey(hArgs, "scan_limit") .AND. HB_IsNumeric(hArgs["scan_limit"]) .AND. hArgs["scan_limit"] > 0
      nScan := Max(nOffset + nLimit, Min(hArgs["scan_limit"], 1000))
   ENDIF

   oArchive := Inbox_Archive(cMailbox)
   IF oArchive == NIL
      hResult["status"] := "error"
      hResult["message"] := "David not connected"
      RETURN hResult
   ENDIF

   BEGIN SEQUENCE
      nCount := oArchive:MailItems:Count
      nFirst := Max(0, nCount - nScan)
      FOR nI := nCount - 1 TO nFirst STEP -1
         BEGIN SEQUENCE
            oItem := oArchive:MailItems:Item(nI)
            hMsg := Inbox_Summary(oItem)
            IF HHasKey(hMsg, "unread")
               lAnyReadState := .T.
            ENDIF
            // With unread_only, keep a message only when its read state is
            // known AND it is unread
            IF ! lUnreadOnly .OR. (HHasKey(hMsg, "unread") .AND. hMsg["unread"])
               AAdd(aMessages, hMsg)
            ENDIF
         RECOVER
         END SEQUENCE
      NEXT
   RECOVER
      hResult["status"] := "error"
      hResult["message"] := "Failed to read mailbox"
      RETURN hResult
   END SEQUENCE

   // Newest first. The date strings are ISO/timestamp form, so they sort chronologically.
   ASort(aMessages,,,{|x,y| x["date"] > y["date"]})

   // Apply offset/limit
   FOR nI := nOffset + 1 TO Min(nOffset + nLimit, Len(aMessages))
      AAdd(aPage, aMessages[nI])
   NEXT

   hResult["mailbox"]  := cMailbox
   hResult["mailbox_total"] := nCount
   hResult["scanned"]  := Min(nScan, nCount)
   hResult["unread_only"] := lUnreadOnly
   hResult["total"]    := Len(aMessages)
   hResult["count"]    := Len(aPage)
   hResult["messages"] := aPage
   hResult["status"]   := "success"
   IF lUnreadOnly .AND. Len(aMessages) == 0 .AND. ! lAnyReadState .AND. Min(nScan, nCount) > 0
      hResult["message"] := "The David API did not report a read state for any scanned message - " + ;
                            "the unread filter cannot be applied here"
   ELSEIF nFirst > 0
      hResult["message"] := "Scanned the newest " + AllTrim(Str(Min(nScan, nCount))) + " of " + ;
                            AllTrim(Str(nCount)) + " entries. Increase 'scan_limit' to look further back"
   ENDIF
RETURN hResult

FUNCTION MCP_Tool_Get_Inbox_Message(hArgs)
   LOCAL hResult := {=>}
   LOCAL oArchive, oItem, nX
   LOCAL cMailbox := "inbox", cId
   LOCAL aTo := {}, aCc := {}, aAttach := {}
   LOCAL xUnread

   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{;
            "id"=>{"type"=>"string","description"=>"The David message id (the 'id' returned by list_inbox)"},;
            "mailbox"=>{"type"=>"string","enum"=>{"inbox","common"},"description"=>"Which mailbox the message is in: 'inbox' (default) or 'common'"};
         },;
         "required"=>{"id"};
      }
      hResult["description"] := "Read a single David Inbox message by id, including body, recipients and attachment names"
      RETURN hResult
   ENDIF

   cId := hArgs["id"]
   IF HHasKey(hArgs, "mailbox") .AND. ! Empty(hArgs["mailbox"])
      cMailbox := Lower(AllTrim(hArgs["mailbox"]))
   ENDIF

   oArchive := Inbox_Archive(cMailbox)
   IF oArchive == NIL
      hResult["status"] := "error"
      hResult["message"] := "David not connected"
      RETURN hResult
   ENDIF

   BEGIN SEQUENCE
      oItem := oArchive:GetArchiveEntryByID(cId)
   RECOVER
      oItem := NIL
   END SEQUENCE

   IF oItem == NIL
      hResult["status"] := "not_found"
      hResult["message"] := "Message not found: " + cId
      RETURN hResult
   ENDIF

   hResult["id"]      := cId
   hResult["mailbox"] := cMailbox

   BEGIN SEQUENCE ; hResult["subject"] := DV_Utf8(oItem:Subject)       ; RECOVER ; hResult["subject"] := "" ; END SEQUENCE
   BEGIN SEQUENCE ; hResult["sender"] := DV_Utf8(oItem:Fields:Item("SRFrom"):Value); RECOVER; hResult["sender"] := ""; END SEQUENCE 
   BEGIN SEQUENCE ; hResult["date"]    := DV_DateStr(oItem:StatusTime) ; RECOVER ; hResult["date"]    := "" ; END SEQUENCE
   xUnread := DV_Unread(oItem)
   IF xUnread != NIL
      hResult["unread"] := xUnread
   ENDIF

   // Recipients (To)
   BEGIN SEQUENCE
      FOR nX := 0 TO oItem:Recipients:Count - 1
         AAdd(aTo, {"name"=>DV_Utf8(oItem:Recipients:Item(nX):DisplayName),"email"=>DV_Utf8(oItem:Recipients:Item(nX):Email)})
      NEXT
   RECOVER
   END SEQUENCE
   hResult["to"] := aTo

   // Carbon copies (CC)
   /*BEGIN SEQUENCE
      FOR nX := 0 TO oItem:Fields:Item("Cc"):Count - 1
         AAdd(aCc, {"name"=>DV_Utf8(oItem:Fields:Item("Cc"):Item(nX):DisplayName),"email"=>DV_Utf8(oItem:Fields:Item("Cc"):Item(nX):Email)})
      NEXT
   RECOVER
   END SEQUENCE
   hResult["cc"] := aCc*/

   // Bodies
   BEGIN SEQUENCE ; hResult["plain_body"] := DV_Utf8(oItem:Fields:Item("Content"):Value) ; RECOVER ; hResult["plain_body"] := "" ; END SEQUENCE
   BEGIN SEQUENCE ; hResult["html_body"]  := DV_Utf8(oItem:Fields:Item("HTMLDisplayContent"):Value)  ; RECOVER ; hResult["html_body"]  := "" ; END SEQUENCE

   // Attachment names (property name best-effort; guarded)
   BEGIN SEQUENCE
      FOR nX := 0 TO oItem:Attachments:Count - 1
         AAdd(aAttach, DV_Utf8(oItem:Attachments:Item(nX):FileName))
      NEXT
   RECOVER
   END SEQUENCE
   hResult["attachments"] := aAttach

   hResult["status"] := "found"
RETURN hResult

//---------------------------------------------------------------------------
// Email sending — hands mail to the David InfoCenter via the SendMail()
// procedure from source\david.prg (linked into the trader binary). Requires a
// working David connection (MailConnect), same as the inbox tools above.
//---------------------------------------------------------------------------

// Convert a UTF-8 string (JSON arguments arrive as UTF-8) to the Windows-ANSI
// (CP1252) form the David OLE API expects — the exact inverse of DV_Utf8.
// Characters that do not exist in CP1252 are replaced by "?".
STATIC FUNCTION DV_FromUtf8(cStr)
   IF ValType(cStr) != "C"
      RETURN ""
   ENDIF
RETURN hb_Translate(cStr, "UTF8", "DEWIN")

// Replace every non-ASCII character of an ANSI (CP1252) string with its
// numeric HTML entity, mirroring DV_HtmlEntities() in david.prg. The result
// is pure ASCII, so an HTML body survives whatever codepage conversion
// happens between here and the David OLE layer.
STATIC FUNCTION AnsiToHtmlEntities(cAnsi)
   LOCAL nI
   FOR nI := 128 TO 255
      IF Chr(nI) $ cAnsi
         cAnsi := StrTran(cAnsi, Chr(nI), "&#" + AllTrim(Str(nI)) + ";")
      ENDIF
   NEXT
RETURN cAnsi

STATIC FUNCTION DV_Join(aList, cSep)
   LOCAL cResult := "", cItem
   FOR EACH cItem IN aList
      IF ! Empty(cResult)
         cResult += cSep
      ENDIF
      cResult += cItem
   NEXT
RETURN cResult

// Split a comma/semicolon separated address list, append each address to aTo
// as a {email, name, type} entry (the shape SendMail() expects) and collect
// syntactically invalid addresses in aInvalid. Returns the number added.
STATIC FUNCTION AddRecipients(xList, cType, aTo, aInvalid)
   LOCAL aParts, cAddr, nAt
   LOCAL nAdded := 0

   IF ValType(xList) != "C" .OR. Empty(xList)
      RETURN 0
   ENDIF

   aParts := hb_ATokens(StrTran(xList, ",", ";"), ";")
   FOR EACH cAddr IN aParts
      cAddr := AllTrim(cAddr)
      IF Empty(cAddr)
         LOOP
      ENDIF
      nAt := At("@", cAddr)
      // minimal sanity check: one "@" (not first), a dot in the domain, no spaces
      IF nAt > 1 .AND. "." $ SubStr(cAddr, nAt + 2) .AND. ;
         At("@", SubStr(cAddr, nAt + 1)) == 0 .AND. !(" " $ cAddr)
         AAdd(aTo, {cAddr, "", cType})
         nAdded++
      ELSE
         AAdd(aInvalid, cAddr)
      ENDIF
   NEXT
RETURN nAdded

FUNCTION MCP_Tool_Send_Email(hArgs)
   LOCAL hResult := {=>}
   LOCAL aTo := {}, aInvalid := {}, aAttach := {}, aRecipients := {}
   LOCAL cSubject, cBody, cFrom := "", cFile
   LOCAL lHtml := .F., lDraft := .F.
   LOCAL nToCount := 0
   LOCAL oAccount, aRecipient

   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{;
            "to"=>{"type"=>"string","description"=>"Recipient email address(es). Multiple addresses separated by comma or semicolon"},;
            "cc"=>{"type"=>"string","description"=>"CC email address(es), separated by comma or semicolon"},;
            "bcc"=>{"type"=>"string","description"=>"BCC email address(es), separated by comma or semicolon"},;
            "subject"=>{"type"=>"string","description"=>"Subject line of the email"},;
            "body"=>{"type"=>"string","description"=>"Body of the email. Plain text by default, HTML when 'html' is true"},;
            "html"=>{"type"=>"boolean","description"=>"Set to true when body contains HTML (default: false = plain text)"},;
            "from"=>{"type"=>"string","description"=>"Sender email address, must be one of the user's configured outgoing addresses. Default: the David account's primary address"},;
            "attachments"=>{"type"=>"array","items"=>{"type"=>"string"},"description"=>"Full file paths (as seen by the Trader server) of files to attach"},;
            "draft"=>{"type"=>"boolean","description"=>"If true the email is saved to the David Drafts folder for manual review instead of being sent immediately (default: false)"};
         },;
         "required"=>{"to","subject","body"};
      }
      hResult["description"] := "Send an email through the David InfoCenter. " + ;
                                "Sends immediately unless 'draft' is true, in which case the mail is placed " + ;
                                "in the Drafts folder for manual review before sending"
      RETURN hResult
   ENDIF

   nToCount := AddRecipients(IIF(HHasKey(hArgs, "to"), hArgs["to"], ""), "TO", aTo, aInvalid)
   AddRecipients(IIF(HHasKey(hArgs, "cc"), hArgs["cc"], ""), "CC", aTo, aInvalid)
   AddRecipients(IIF(HHasKey(hArgs, "bcc"), hArgs["bcc"], ""), "BCC", aTo, aInvalid)

   IF Len(aInvalid) > 0
      RETURN "Invalid email address(es): " + DV_Join(aInvalid, ", ")
   ENDIF
   IF nToCount == 0
      RETURN "No valid 'to' recipient provided"
   ENDIF

   IF ValType(hArgs["subject"]) != "C" .OR. ValType(hArgs["body"]) != "C"
      RETURN "Parameters 'subject' and 'body' must be strings"
   ENDIF

   cSubject := DV_FromUtf8(hArgs["subject"])
   cBody := DV_FromUtf8(hArgs["body"])
   // JSON newlines arrive as LF; SendMail() strips LF and keeps CR, so
   // normalize CRLF/LF to CR to preserve line breaks in the plain body.
   cBody := StrTran(cBody, Chr(13) + Chr(10), Chr(13))
   cBody := StrTran(cBody, Chr(10), Chr(13))

   lHtml := HHasKey(hArgs, "html") .AND. HB_IsLogical(hArgs["html"]) .AND. hArgs["html"]
   lDraft := HHasKey(hArgs, "draft") .AND. HB_IsLogical(hArgs["draft"]) .AND. hArgs["draft"]
   IF HHasKey(hArgs, "from") .AND. ValType(hArgs["from"]) == "C"
      cFrom := AllTrim(hArgs["from"])
   ENDIF

   // Make HTML bodies pure ASCII (entities) so no later codepage conversion
   // can garble them. We pass lHtmlEntities=.F. to SendMail below because its
   // own DV_HtmlEntities() expects OEM input and would mangle our ANSI body.
   IF lHtml
      cBody := AnsiToHtmlEntities(cBody)
   ENDIF

   // Attachments must exist on disk before we hand them to David
   IF HHasKey(hArgs, "attachments") .AND. HB_IsArray(hArgs["attachments"])
      FOR EACH cFile IN hArgs["attachments"]
         IF ValType(cFile) != "C" .OR. Empty(cFile)
            LOOP
         ENDIF
         cFile := DV_FromUtf8(cFile)
         IF ! File(cFile)
            RETURN "Attachment not found: " + cFile
         ENDIF
         AAdd(aAttach, cFile)
      NEXT
   ENDIF

   // Connect to David (idempotent) and make sure we really have an account —
   // SendMail() itself just returns silently when there is no connection.
   BEGIN SEQUENCE
      MailConnect()
      oAccount := DV_GetMailAccount()
   RECOVER
      oAccount := NIL
   END SEQUENCE

   IF oAccount == NIL
      hResult["status"] := "error"
      hResult["message"] := "David not connected - email not sent"
      RETURN hResult
   ENDIF

   BEGIN SEQUENCE
      SendMail(aTo, cSubject, cBody, aAttach, .F., 0, lHtml, cFrom, lDraft, .F.)
   RECOVER
      hResult["status"] := "error"
      hResult["message"] := "Failed to " + IIF(lDraft, "save draft", "send email")
      RETURN hResult
   END SEQUENCE

   FOR EACH aRecipient IN aTo
      AAdd(aRecipients, aRecipient[3] + ": " + aRecipient[1])
   NEXT

   hResult["status"] := "success"
   hResult["mode"] := IIF(lDraft, "draft", "sent")
   hResult["recipients"] := aRecipients
   hResult["subject"] := hArgs["subject"]
   hResult["attachment_count"] := Len(aAttach)
   hResult["message"] := IIF(lDraft, ;
      "Email saved to the David Drafts folder", ;
      "Email handed to David for sending")
RETURN hResult

//---------------------------------------------------------------------------
// Reminder tool — creates a David Wiedervorlage via AddWiedervorlage() from
// source\david.prg, for the current user or another Trader user.
//---------------------------------------------------------------------------

FUNCTION MCP_Tool_Create_Reminder(hArgs)
   LOCAL hResult := {=>}
   LOCAL dDate, cSubject, cMessage
   LOCAL nUser := 0
   LOCAL oAccount, lOk := .F.

   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{;
            "date"=>{"type"=>"string","description"=>"Reminder date in YYYY-MM-DD format"},;
            "subject"=>{"type"=>"string","description"=>"Subject of the reminder"},;
            "message"=>{"type"=>"string","description"=>"Body text of the reminder (optional)"},;
            "user_number"=>{"type"=>"integer","description"=>"Trader user (buyer) number whose reminder folder receives the entry. Default: the current user"};
         },;
         "required"=>{"date","subject"};
      }
      hResult["description"] := "Create a reminder (Wiedervorlage) in the David InfoCenter that pops up on the given date, " + ;
                                "for the current user or another Trader user"
      RETURN hResult
   ENDIF

   IF ValType(hArgs["date"]) != "C"
      RETURN "Parameter 'date' must be a string in YYYY-MM-DD format"
   ENDIF
   dDate := SToD(StrTran(AllTrim(hArgs["date"]), "-", ""))
   IF Empty(dDate)
      RETURN "Invalid date: " + hArgs["date"] + " (expected YYYY-MM-DD)"
   ENDIF
   IF dDate < Date()
      RETURN "Reminder date " + hArgs["date"] + " is in the past"
   ENDIF

   cSubject := DV_FromUtf8(hArgs["subject"])
   cMessage := IIF(HHasKey(hArgs, "message") .AND. ValType(hArgs["message"]) == "C", DV_FromUtf8(hArgs["message"]), "")
   cMessage := StrTran(cMessage, Chr(13) + Chr(10), Chr(13))
   cMessage := StrTran(cMessage, Chr(10), Chr(13))

   IF HHasKey(hArgs, "user_number") .AND. HB_IsNumeric(hArgs["user_number"]) .AND. hArgs["user_number"] > 0
      nUser := hArgs["user_number"]
   ENDIF

   BEGIN SEQUENCE
      MailConnect()
      oAccount := DV_GetMailAccount()
   RECOVER
      oAccount := NIL
   END SEQUENCE

   IF oAccount == NIL
      hResult["status"] := "error"
      hResult["message"] := "David not connected - reminder not created"
      RETURN hResult
   ENDIF

   BEGIN SEQUENCE
      lOk := AddWiedervorlage(dDate, cSubject, cMessage, NIL, {}, nUser)
   RECOVER
      lOk := .F.
   END SEQUENCE

   IF lOk
      hResult["status"] := "success"
      hResult["date"] := dDate
      hResult["subject"] := hArgs["subject"]
      hResult["user_number"] := nUser
      hResult["message"] := "Reminder created"
   ELSE
      hResult["status"] := "error"
      hResult["message"] := "Failed to create reminder" + ;
         IIF(nUser > 0, " - user " + AllTrim(Str(nUser)) + " may not exist or has no David account linked", "")
   ENDIF
RETURN hResult

//---------------------------------------------------------------------------
// Quote and accounting tools — read-only access to the angebot (quote) and
// englsre (invoice ledger) tables.
//---------------------------------------------------------------------------

// Resolve a customer from the 'customer' (matchcode) / 'customer_number'
// arguments, same lookup as MCP_Tool_Get_Customer. Returns NIL if not found.
STATIC FUNCTION ResolveCustomer(hArgs)
   LOCAL oKunde := Adresse():New()
   LOCAL lFound := .F.

   IF HHasKey(hArgs, "customer_number") .AND. HB_IsNumeric(hArgs["customer_number"]) .AND. hArgs["customer_number"] > 0
      ku->(DbSetOrder(8))
      lFound := oKunde:Load(hArgs["customer_number"])
   ELSEIF HHasKey(hArgs, "customer") .AND. ! Empty(hArgs["customer"])
      lFound := oKunde:LoadMatchcode(Pad(Upper(AllTrim(hArgs["customer"])), 8), "K")
   ENDIF
RETURN IIF(lFound, oKunde, NIL)

// Coarse quote status from ang->Bestat: 0 = enquiry not yet quoted ("off"),
// 1/2 = quoted ("ang"), >= 3 = closed ("erl") - see angebot_browse.prg.
STATIC FUNCTION QuoteStatusLabel(nBestat)
RETURN IIF(nBestat >= 3, "closed", IIF(nBestat == 0, "enquiry", "quoted"))

// Discounted unit price of the current ang line (see angebot_print.prg:
// dis_count := vkpr - vkpr*rabatt/100; Pe is the price unit).
STATIC FUNCTION QuoteLinePrice()
RETURN (ang->VkPr - ang->VkPr * ang->Rabatt / 100) / IIF(ang->Pe == 0, 1, ang->Pe)

FUNCTION MCP_Tool_Get_Quote(hArgs)
   LOCAL hResult := {=>}
   LOCAL nQuote, hLine
   LOCAL aLines := {}
   LOCAL nTotal := 0
   LOCAL nOldSelect := Select()

   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{;
            "quote_number"=>{"type"=>"number","description"=>"Quote (Angebot) number"};
         },;
         "required"=>{"quote_number"};
      }
      hResult["description"] := "Retrieve a sales quote (Angebot) by number, including all line items, prices and status"
      RETURN hResult
   ENDIF

   IF ! HB_IsNumeric(hArgs["quote_number"])
      RETURN "Parameter 'quote_number' must be a number"
   ENDIF
   nQuote := hArgs["quote_number"]

   NetUse("angebot", "ang")
   ang->(DbSetOrder(1))  // Str(Angnr,6) + Str(Itmnr,3)

   IF ! ang->(DbSeek(Str(nQuote, 6)))
      DbSelectArea(nOldSelect)
      hResult["status"] := "not_found"
      hResult["message"] := "Quote not found: " + AllTrim(Str(nQuote))
      RETURN hResult
   ENDIF

   hResult["quote_number"] := nQuote
   hResult["customer"] := HB_StrToUTF8(AllTrim(ang->Kundma))
   hResult["date"] := ang->Besda
   hResult["buyer"] := HB_StrToUTF8(AllTrim(ang->Buyer))
   hResult["currency"] := IIF(Empty(ang->Money), "EUR", AllTrim(ang->Money))

   DO WHILE ! ang->(Eof()) .AND. ang->Angnr == nQuote
      hLine := {=>}
      hLine["item"] := ang->Itmnr
      hLine["article"] := HB_StrToUTF8(AllTrim(ang->Matchcode))
      hLine["description"] := HB_StrToUTF8(AllTrim(ang->Artikel))
      hLine["quantity"] := ang->VkQty
      hLine["price"] := QuoteLinePrice()
      hLine["discount_percent"] := ang->Rabatt
      hLine["status"] := QuoteStatusLabel(ang->Bestat)
      IF ang->Aufnr > 0
         hLine["order_number"] := ang->Aufnr  // quote line was converted to this order
      ENDIF
      hLine["line_total"] := Round(ang->VkQty * QuoteLinePrice(), 2)
      nTotal += hLine["line_total"]
      AAdd(aLines, hLine)
      ang->(DbSkip())
   ENDDO

   DbSelectArea(nOldSelect)

   hResult["lines"] := aLines
   hResult["total"] := Round(nTotal, 2)
   hResult["status"] := "found"
RETURN hResult

FUNCTION MCP_Tool_Get_Customer_Quotes(hArgs)
   LOCAL hResult := {=>}
   LOCAL oKunde, hQuotes := {=>}, hQuote, cKey
   LOCAL aQuotes := {}
   LOCAL cStatus := "all", cLineStatus
   LOCAL nMaxResults := 50
   LOCAL nOldSelect := Select()

   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{;
            "customer"=>{"type"=>"string","description"=>"Customer matchcode"},;
            "customer_number"=>{"type"=>"number","description"=>"Customer number"},;
            "status_filter"=>{"type"=>"string","enum"=>{"open","closed","all"},"description"=>"Only quotes with this status (default all). 'open' = enquiry received or quoted but not yet closed"},;
            "max_results"=>{"type"=>"number","description"=>"Maximum number of quotes to return, newest first (default 50)"};
         },;
         "anyOf"=>{{"customer", "customer_number"}};
      }
      hResult["description"] := "List sales quotes (Angebote) for a customer, newest first, with per-quote status and value"
      RETURN hResult
   ENDIF

   IF HHasKey(hArgs, "status_filter") .AND. hArgs["status_filter"] $ {"open", "closed"}
      cStatus := hArgs["status_filter"]
   ENDIF
   IF HHasKey(hArgs, "max_results") .AND. HB_IsNumeric(hArgs["max_results"]) .AND. hArgs["max_results"] > 0
      nMaxResults := Min(hArgs["max_results"], 200)
   ENDIF

   oKunde := ResolveCustomer(hArgs)
   IF oKunde == NIL
      hResult["status"] := "not_found"
      hResult["message"] := "Customer not found"
      RETURN hResult
   ENDIF

   NetUse("angebot", "ang")
   ang->(DbSetOrder(7))  // Kundma

   IF ang->(DbSeek(oKunde:Kunde))
      DO WHILE ! ang->(Eof()) .AND. ang->Kundma == oKunde:Kunde
         cLineStatus := QuoteStatusLabel(ang->Bestat)
         IF cStatus == "all" .OR. ;
            (cStatus == "open" .AND. cLineStatus != "closed") .OR. ;
            (cStatus == "closed" .AND. cLineStatus == "closed")

            cKey := Str(ang->Angnr, 6)
            IF ! HHasKey(hQuotes, cKey)
               hQuote := {=>}
               hQuote["quote_number"] := ang->Angnr
               hQuote["date"] := ang->Besda
               hQuote["buyer"] := HB_StrToUTF8(AllTrim(ang->Buyer))
               hQuote["currency"] := IIF(Empty(ang->Money), "EUR", AllTrim(ang->Money))
               hQuote["status"] := cLineStatus
               hQuote["line_count"] := 0
               hQuote["total"] := 0
               hQuotes[cKey] := hQuote
            ENDIF
            hQuotes[cKey]["line_count"] := hQuotes[cKey]["line_count"] + 1
            hQuotes[cKey]["total"] := Round(hQuotes[cKey]["total"] + ang->VkQty * QuoteLinePrice(), 2)
            // A quote with any line still open counts as open
            IF cLineStatus != "closed"
               hQuotes[cKey]["status"] := cLineStatus
            ENDIF
         ENDIF
         ang->(DbSkip())
      ENDDO
   ENDIF

   DbSelectArea(nOldSelect)

   FOR EACH hQuote IN hQuotes
      AAdd(aQuotes, hQuote)
   NEXT
   ASort(aQuotes,,, {|x, y| x["quote_number"] > y["quote_number"]})
   ASize(aQuotes, Min(Len(aQuotes), nMaxResults))

   hResult["customer"] := HB_StrToUTF8(AllTrim(oKunde:Kunde))
   hResult["customer_number"] := oKunde:Nummer
   hResult["count"] := Len(aQuotes)
   hResult["quotes"] := aQuotes
   hResult["status"] := IIF(Len(aQuotes) > 0, "found", "not_found")
   IF Len(aQuotes) == 0
      hResult["message"] := "No quotes found for this customer"
   ELSEIF Len(aQuotes) == nMaxResults
      hResult["message"] := "Result limited to " + AllTrim(Str(nMaxResults)) + " quotes"
   ENDIF
RETURN hResult

FUNCTION MCP_Tool_Get_Customer_Open_Items(hArgs)
   LOCAL hResult := {=>}
   LOCAL oKunde, cKunde
   LOCAL aItems := {}, hItem
   LOCAL hTotals := {=>}, cCur, nOpen
   LOCAL nOldSelect := Select()

   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{;
            "customer"=>{"type"=>"string","description"=>"Customer matchcode"},;
            "customer_number"=>{"type"=>"number","description"=>"Customer number"};
         },;
         "anyOf"=>{{"customer", "customer_number"}};
      }
      hResult["description"] := "List open (not fully paid) invoices and credit notes for a customer, " + ;
                                "with amount, paid amount, open balance and age in days. Use before payment reminders"
      RETURN hResult
   ENDIF

   oKunde := ResolveCustomer(hArgs)
   IF oKunde == NIL
      hResult["status"] := "not_found"
      hResult["message"] := "Customer not found"
      RETURN hResult
   ENDIF

   cKunde := Pad(oKunde:Kunde, 8)

   NetUse("englsre", "re", .F., 5)
   re->(DbSetOrder(2))  // Str(Reposnr,3) + Kunde; Reposnr 0 = invoice header

   IF re->(DbSeek("  0" + cKunde))
      DO WHILE ! re->(Eof()) .AND. re->Reposnr == 0 .AND. re->Kunde == cKunde
         // Open = not settled yet, same criteria as GetCustomerTurnover in
         // model/adresse.prg (status 0 and code <= 2)
         IF re->Status == 0 .AND. re->Code <= 2
            nOpen := Round(re->Poswt - re->AoQty - re->PaySkonto, 2)
            IF nOpen != 0
               hItem := {=>}
               hItem["invoice_number"] := re->Rechnr
               hItem["type"] := IIF(re->Poswt < 0, "credit_note", "invoice")
               hItem["date"] := re->Rechdat
               hItem["age_days"] := Date() - re->Rechdat
               hItem["amount"] := re->Poswt
               hItem["paid"] := re->AoQty
               hItem["discount"] := re->PaySkonto
               hItem["open"] := nOpen
               hItem["currency"] := IIF(Empty(re->Money), "EUR", AllTrim(re->Money))
               AAdd(aItems, hItem)

               cCur := hItem["currency"]
               IF ! HHasKey(hTotals, cCur)
                  hTotals[cCur] := 0
               ENDIF
               hTotals[cCur] := Round(hTotals[cCur] + nOpen, 2)
            ENDIF
         ENDIF
         re->(DbSkip())
      ENDDO
   ENDIF

   DbSelectArea(nOldSelect)

   // Oldest first - the order a dunning run would treat them
   ASort(aItems,,, {|x, y| x["date"] < y["date"]})

   hResult["customer"] := HB_StrToUTF8(AllTrim(oKunde:Kunde))
   hResult["customer_number"] := oKunde:Nummer
   hResult["count"] := Len(aItems)
   hResult["open_items"] := aItems
   hResult["open_total_by_currency"] := hTotals
   hResult["status"] := IIF(Len(aItems) > 0, "found", "none")
   IF Len(aItems) == 0
      hResult["message"] := "No open items - nothing unpaid for this customer"
   ENDIF
RETURN hResult

FUNCTION MCP_Tool_Get_Customer_Turnover(hArgs)
   LOCAL hResult := {=>}
   LOCAL oKunde, hTurn
   LOCAL hYears := {=>}, nVal

   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{;
            "customer"=>{"type"=>"string","description"=>"Customer matchcode"},;
            "customer_number"=>{"type"=>"number","description"=>"Customer number"};
         },;
         "anyOf"=>{{"customer", "customer_number"}};
      }
      hResult["description"] := "Revenue statistics for a customer: total and per-year turnover, current/last year, " + ;
                                "last 12 months and the currently open (unpaid) invoice amount. Net values in EUR"
      RETURN hResult
   ENDIF

   oKunde := ResolveCustomer(hArgs)
   IF oKunde == NIL
      hResult["status"] := "not_found"
      hResult["message"] := "Customer not found"
      RETURN hResult
   ENDIF

   // GetCustomerTurnover() lives in model/adresse.prg and is REQUESTed into
   // the trader binary - the same numbers the application itself shows.
   BEGIN SEQUENCE
      hTurn := GetCustomerTurnover(oKunde:Kunde)
   RECOVER
      hTurn := NIL
   END SEQUENCE

   IF ValType(hTurn) != "H"
      hResult["status"] := "error"
      hResult["message"] := "Failed to calculate turnover"
      RETURN hResult
   ENDIF

   // The years hash is keyed by numeric year - convert to string keys for JSON
   FOR EACH nVal IN hTurn["years"]
      hYears[AllTrim(Str(nVal:__enumKey()))] := Round(nVal, 2)
   NEXT

   hResult["customer"] := HB_StrToUTF8(AllTrim(oKunde:Kunde))
   hResult["customer_number"] := oKunde:Nummer
   hResult["currency"] := "EUR"
   hResult["total"] := Round(hTurn["total"], 2)
   hResult["current_year"] := Round(hTurn["current"], 2)
   hResult["last_year"] := Round(hTurn["last"], 2)
   hResult["year_before_last"] := Round(hTurn["before-last"], 2)
   hResult["last_3_years"] := Round(hTurn["last3"], 2)
   hResult["last_12_months"] := Round(hTurn["12-month"], 2)
   hResult["open_invoices"] := Round(hTurn["open"], 2)
   hResult["by_year"] := hYears
   hResult["status"] := "found"
RETURN hResult

FUNCTION MCP_Tool_Get_Invoice(hArgs)
   LOCAL hResult := {=>}
   LOCAL nRe, hLine
   LOCAL aLines := {}
   LOCAL nOldSelect := Select()

   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{;
            "invoice_number"=>{"type"=>"number","description"=>"Invoice (Rechnung) number"};
         },;
         "required"=>{"invoice_number"};
      }
      hResult["description"] := "Retrieve an outgoing invoice by number: header with customer, totals, tax, payment and " + ;
                                "dunning status, plus all line items. The sales order number (AB-Nr) is included on the " + ;
                                "header and on each line (collective invoices can bill several orders) and can be passed " + ;
                                "to get_order_details; a line's item number equals the item number in that order"
      RETURN hResult
   ENDIF

   IF ! HB_IsNumeric(hArgs["invoice_number"])
      RETURN "Parameter 'invoice_number' must be a number"
   ENDIF
   nRe := hArgs["invoice_number"]

   NetUse("englsre", "re", .F., 5)
   re->(DbSetOrder(12))  // Str(Rechnr,6) + Str(Reposnr,3); Reposnr 0 = header

   IF ! re->(DbSeek(Str(nRe, 6) + Str(0, 3)))
      DbSelectArea(nOldSelect)
      hResult["status"] := "not_found"
      hResult["message"] := "Invoice not found: " + AllTrim(Str(nRe))
      RETURN hResult
   ENDIF

   // Header row - field meanings per the map in model/rechnung.prg
   // (PosWt=gross total, Preis=tax, Kurs=tax rate, ofqty=shipping,
   //  AoQty=paid amount, Code>=2 printed, Code>=3+Status==3 paid)
   hResult["invoice_number"] := nRe
   hResult["customer"] := HB_StrToUTF8(AllTrim(re->Kunde))
   hResult["date"] := re->Rechdat
   IF re->AbNr > 0
      hResult["order_number"] := re->AbNr
   ENDIF
   hResult["currency"] := IIF(Empty(re->Money), "EUR", AllTrim(re->Money))
   hResult["total_gross"] := re->PosWt
   hResult["tax"] := re->Preis
   hResult["tax_rate"] := re->Kurs
   hResult["total_net"] := Round(re->PosWt - re->Preis, 2)
   hResult["shipping"] := re->OfQty
   hResult["discount_percent"] := re->Rabatt
   hResult["paid_amount"] := re->AoQty
   hResult["paid"] := re->Code >= 3 .AND. re->Status == 3
   hResult["printed"] := re->Code >= 2
   hResult["shipped"] := re->Packed
   IF ! Empty(re->PayDate)
      hResult["payment_date"] := re->PayDate
   ENDIF
   IF ! Empty(re->MaDate)
      hResult["dunning"] := re->Rem
      hResult["dunning_date"] := re->MaDate
   ENDIF

   re->(DbSkip())  // move past the header row
   DO WHILE ! re->(Eof()) .AND. re->Rechnr == nRe
      IF re->Reposnr != 0
         hLine := {=>}
         hLine["item"] := re->Reposnr  // equals the item number in the billed order (model/rechpos.prg)
         hLine["article"] := HB_StrToUTF8(AllTrim(re->Matchcode))
         hLine["description"] := HB_StrToUTF8(AllTrim(re->Artikel))
         hLine["quantity"] := re->AoQty
         hLine["unit"] := HB_StrToUTF8(AllTrim(re->Me))
         hLine["unit_price"] := Round((re->Preis / IIF(re->Pe == 0, 1, re->Pe)) * (1 - re->Rabatt / 100), 4)
         IF re->Zuschlag != 0
            hLine["surcharge"] := re->Zuschlag
         ENDIF
         // Same line total formula as Rechnung:UpdateTotal() in model/rechnung.prg
         hLine["line_total"] := Round((re->AoQty * re->Preis / IIF(re->Pe == 0, 1, re->Pe)) * (1 - re->Rabatt / 100), 2) + re->Zuschlag
         IF re->AbNr > 0
            hLine["order_number"] := re->AbNr
         ENDIF
         AAdd(aLines, hLine)
      ENDIF
      re->(DbSkip())
   ENDDO

   DbSelectArea(nOldSelect)

   hResult["lines"] := aLines
   hResult["line_count"] := Len(aLines)
   hResult["status"] := "found"
RETURN hResult

FUNCTION MCP_Tool_Get_Purchase_Order(hArgs)
   LOCAL hResult := {=>}
   LOCAL nPo, hLine, aLines := {}
   LOCAL nTotal := 0, nPriceEur
   LOCAL nOldSelect := Select()

   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{;
            "po_number"=>{"type"=>"number","description"=>"Purchase order (Bestellung) number"};
         },;
         "required"=>{"po_number"};
      }
      hResult["description"] := "Retrieve a purchase order (Bestellung) by number, including all line items with " + ;
                                "ordered/delivered quantities, delivery dates, confirmation status and prices"
      RETURN hResult
   ENDIF

   IF ! HB_IsNumeric(hArgs["po_number"])
      RETURN "Parameter 'po_number' must be a number"
   ENDIF
   nPo := hArgs["po_number"]

   NetUse("engbes", "bes")
   bes->(DbSetOrder(1))  // Str(Besnr,6) + Str(Posnr,3)

   IF ! bes->(DbSeek(Str(nPo, 6)))
      DbSelectArea(nOldSelect)
      hResult["status"] := "not_found"
      hResult["message"] := "Purchase order not found: " + AllTrim(Str(nPo))
      RETURN hResult
   ENDIF

   hResult["po_number"] := nPo
   hResult["supplier"] := HB_StrToUTF8(AllTrim(bes->Liefma))
   hResult["date"] := bes->Besda
   hResult["currency"] := IIF(Empty(bes->Money), "EUR", AllTrim(bes->Money))

   DO WHILE ! bes->(Eof()) .AND. bes->Besnr == nPo
      hLine := {=>}
      hLine["item"] := bes->Posnr
      hLine["article"] := HB_StrToUTF8(AllTrim(bes->Matchcode))
      hLine["quantity"] := bes->BeQty
      hLine["delivered_quantity"] := bes->GelQty
      hLine["open_quantity"] := IIF(bes->Bestat < 3, bes->BeQty - bes->GelQty, 0)
      // Discounted unit price in the document currency
      hLine["unit_price"] := Round((bes->EkPr / IIF(bes->Pe == 0, 1, bes->Pe)) * (100 - bes->Rabatt) / 100, 4)
      // Effective EUR unit price via BesGetEkPrice() (model/bestellungpos.prg):
      // includes exchange rate and linked surcharge/reference positions
      BEGIN SEQUENCE
         nPriceEur := BesGetEkPrice()
      RECOVER
         nPriceEur := NIL
      END SEQUENCE
      IF nPriceEur != NIL
         hLine["unit_price_eur"] := Round(nPriceEur, 4)
      ENDIF
      hLine["delivery_date"] := bes->Lterm
      hLine["requested_date"] := bes->Wterm
      hLine["confirmed"] := Upper(AllTrim(bes->Confirmed)) == "Y"  // stored as "Y"/"N"
      hLine["status"] := IIF(bes->Bestat < 3, "open", "completed")
      IF bes->AbNr > 0
         hLine["sales_order"] := bes->AbNr  // linked customer order
      ENDIF
      IF bes->ContrNo > 0
         hLine["frame_order"] := bes->ContrNo  // call-off from this blanket PO
      ENDIF
      hLine["line_total"] := Round(bes->BeQty * hLine["unit_price"], 2)
      nTotal += hLine["line_total"]
      AAdd(aLines, hLine)
      bes->(DbSkip())
   ENDDO

   DbSelectArea(nOldSelect)

   hResult["lines"] := aLines
   hResult["total"] := Round(nTotal, 2)
   hResult["status"] := "found"
RETURN hResult

FUNCTION MCP_Tool_Mark_Message_Read(hArgs)
   LOCAL hResult := {=>}
   LOCAL oArchive, oItem
   LOCAL cMailbox := "inbox", cId
   LOCAL lRead := .T., lSet := .F.
   LOCAL xUnread

   // Return schema and description when called without arguments
   IF hArgs == NIL .OR. ValType(hArgs) != "H" .OR. Len(hArgs) == 0
      hResult["schema"] := {;
         "type"=>"object",;
         "properties"=>{;
            "id"=>{"type"=>"string","description"=>"The David message id (the 'id' returned by list_inbox)"},;
            "mailbox"=>{"type"=>"string","enum"=>{"inbox","common"},"description"=>"Which mailbox the message is in: 'inbox' (default) or 'common'"},;
            "read"=>{"type"=>"boolean","description"=>"true (default) marks the message as read, false marks it as unread again"};
         },;
         "required"=>{"id"};
      }
      hResult["description"] := "Mark a David message as read (or unread) via its Viewed state. " + ;
                                "The new state is read back after setting, so success means the change actually took effect"
      RETURN hResult
   ENDIF

   cId := hArgs["id"]
   IF HHasKey(hArgs, "mailbox") .AND. ! Empty(hArgs["mailbox"])
      cMailbox := Lower(AllTrim(hArgs["mailbox"]))
   ENDIF
   IF HHasKey(hArgs, "read") .AND. HB_IsLogical(hArgs["read"])
      lRead := hArgs["read"]
   ENDIF

   oArchive := Inbox_Archive(cMailbox)
   IF oArchive == NIL
      hResult["status"] := "error"
      hResult["message"] := "David not connected"
      RETURN hResult
   ENDIF

   BEGIN SEQUENCE
      oItem := oArchive:GetArchiveEntryByID(cId)
   RECOVER
      oItem := NIL
   END SEQUENCE

   IF oItem == NIL
      hResult["status"] := "not_found"
      hResult["message"] := "Message not found: " + cId
      RETURN hResult
   ENDIF

   BEGIN SEQUENCE
      oItem:Viewed := lRead
      lSet := .T.
   RECOVER
      lSet := .F.
   END SEQUENCE

   IF lSet
      // Persist if the API requires it; ignore failure - the verification
      // read below decides whether the change took effect.
      BEGIN SEQUENCE
         oItem:Save()
      RECOVER
      END SEQUENCE
   ENDIF

   // Verify by reading the state back (DV_Unread: unread = ! Viewed)
   xUnread := DV_Unread(oItem)

   hResult["id"] := cId
   hResult["mailbox"] := cMailbox
   IF lSet .AND. ValType(xUnread) == "L" .AND. xUnread == ! lRead
      hResult["unread"] := xUnread
      hResult["status"] := "success"
      hResult["message"] := "Message marked as " + IIF(lRead, "read", "unread")
   ELSEIF ! lSet
      hResult["status"] := "error"
      hResult["message"] := "Setting the Viewed state failed - the David API rejected the write"
   ELSE
      hResult["status"] := "error"
      hResult["message"] := "Viewed state was set but the change could not be verified"
   ENDIF
RETURN hResult

// Convert all string values in a hash from OEM to ANSI
STATIC FUNCTION _HashToUtf8(hHash)
   LOCAL cKey, xValue
   IF ValType(hHash) != "H"
      RETURN hHash
   ENDIF
   FOR EACH cKey IN HB_HKeys(hHash)
      xValue := hHash[cKey]
      IF ValType(xValue) == "C"
         hHash[cKey] := Hb_StrToUtf8(xValue)               
      ENDIF
   NEXT
RETURN hHash


//#include "shopware_api.prg"  // Include Shopware API class