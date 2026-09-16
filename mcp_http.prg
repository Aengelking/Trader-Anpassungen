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
 * The server is multithreaded: the main thread accepts connections and hands
 * each socket to a fixed pool of worker threads (uhttpd-style, via a
 * hb_mutex job queue). Read tools run concurrently, so one slow scan no longer
 * blocks every other client. Each worker owns its LetoDB connection and work
 * areas (both thread-local in Harbour MT). Tools that write, or that touch the
 * process-global Trader user context (Tr_GetIni(28) / SystemUser), run one at
 * a time on a shared serialize mutex (MCP_Http_DispatchSerial); that lock is
 * also the only place the global user context is switched. David/OLE (COM)
 * tools were removed precisely because they cannot run on a worker pool.
 * Pool size: -threads N (default 4, clamp 1..32); -threads 1 restores serial.
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

#include "hbthread.ch"    // HB_THREAD_INHERIT_MEMVARS for the worker pool
#include "hbmemory.ch"    // HB_MEM_USED for the dashboard memory line

// GUI dashboard layout: a status header on top, a scrolling log region below.
#define MCP_DASH_SEPROW    8    // separator line row
#define MCP_LOG_FIRSTROW   9    // first row of the scrolling log region

STATIC s_nMcpSessionSeq  := 0     // monotonic counter for session-id uniqueness
STATIC s_lMcpHttpStop    := .F.   // set when a "shutdown" request arrives
STATIC s_lMcpHttpVerbose := .T.   // per-request console logging on/off
STATIC s_cMcpLogSink     := ""    // "QOUT" or "STDERR"; decided from the GT on first use
STATIC s_hMcpKeys        := NIL   // API-key table from mcp_keys.json (NIL = auth disabled)
STATIC s_cMcpKeysStamp   := ""    // file stamp of the loaded key table
STATIC s_lMcpAuthWarned  := .F.   // "running without authentication" warned once
STATIC s_cMcpSrcStamp    := ""    // stamp of the MCP source files for auto-reload
STATIC s_hMcpClients     := {=>}  // connected-client overview, keyed by session id (fallback peer#user)
STATIC s_nSlashHits      := 0     // cumulative health-check pings (/, /health, /healthz) since start
STATIC s_nLastReloadCheck := -1   // Seconds() of the last source-stamp check (-1 = unset)

// --- Multithreading (see the pool section below) --------------------------
// The accept loop runs on the main thread and hands each accepted socket to a
// fixed pool of worker threads through s_hMcpQueue. Read tools run in parallel;
// tools that write or touch the process-global user context are serialized on
// s_hMcpSerialize. Shared server state (client table, slash stats, log device)
// is guarded by s_hMcpState. Per-request context that used to live in module
// STATICs is now THREAD STATIC so each worker keeps its own.
STATIC s_hMcpQueue       := NIL   // job queue: main thread notifies, workers subscribe (carries sockets)
STATIC s_hMcpSerialize   := NIL   // held for the whole dispatch of a serial-lane (write/user-context) tool
STATIC s_hMcpState       := NIL   // guards s_hMcpClients, slash stats and the log device
STATIC s_aMcpWorkers     := {}    // worker thread handles (for join on shutdown)
STATIC s_nMcpPoolSize    := 0     // number of worker threads (resolved in MCP_Http)

// --- Dashboard (GUI split view: stats header on top, scrolling log below) --
// Live counters shown in the header; all mutated under s_hMcpState.
STATIC s_lMcpDash        := .F.   // split-view active (GUI GT with a real screen)
STATIC s_nMcpActiveReq   := 0     // requests currently being served (in-flight)
STATIC s_nMcpMaxActive   := 0     // high-water mark of concurrent requests
STATIC s_nMcpTotalReq    := 0     // total JSON-RPC requests dispatched
STATIC s_nMcpSlowReq     := 0     // requests that took >= 1s
STATIC s_nMcpStartSecs   := -1    // Seconds() at server start (for uptime)
STATIC s_nMcpDashPort    := 0     // listen port, for the header
STATIC s_nMcpLogRow      := 0     // next log row within the scroll region (GUI)

THREAD STATIC t_lMcpQuietReq := .F. // current request is routine "/" traffic in GUI mode - suppress 2xx response log
THREAD STATIC t_nReqUser     := 0   // current request's authenticated user (fed into client tracking)
THREAD STATIC t_cReqName     := ""  // current request's user name
THREAD STATIC t_cReqPeer     := ""  // current request's peer address
THREAD STATIC t_lReqReadOnly := .F. // current request's API key is read-only (write tools blocked)
THREAD STATIC t_lLetoReady   := .F. // this worker has established its own LetoDB connection

FUNCTION MCP_Http( nPort, cBindAddr, lVerbose, lAutoReload )
   LOCAL nStdErr := hb_GetStdErr()
   LOCAL hListen, hSocket
   LOCAL lRestart := .F.
   LOCAL nX

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

   // Resolve the pool size now so it can be shown in the dashboard header, and
   // set up the GUI split view (stats header on top, scrolling log below).
   // Under a non-GUI GT this is a no-op and logging stays line-based on stderr.
   s_nMcpPoolSize := MCP_Http_PoolSize()
   MCP_Http_DashInit( nPort )

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

   // ---- Start the worker pool ------------------------------------------
   // Accept runs here on the main thread; each accepted socket is handed to a
   // free worker via s_hMcpQueue. Read tools run concurrently, so one slow
   // scan no longer blocks every other client. Writes and user-context tools
   // are serialized inside the workers (MCP_Http_DispatchSerial).
   s_hMcpQueue     := hb_mutexCreate()
   s_hMcpSerialize := hb_mutexCreate()
   s_hMcpState     := hb_mutexCreate()
   s_aMcpWorkers   := {}
   FOR nX := 1 TO s_nMcpPoolSize
      AAdd( s_aMcpWorkers, hb_threadStart( HB_THREAD_INHERIT_MEMVARS, @MCP_Http_Worker(), nX ) )
   NEXT
   MCP_Http_Log( "Worker-Pool: " + LTrim( Str( s_nMcpPoolSize ) ) + ;
      " Thread(s) - parallele Lesezugriffe, serialisierte Schreibzugriffe" )
   MCP_Http_DashHeader()   // first full paint now that the pool is up

   DO WHILE ! s_lMcpHttpStop
      hSocket := hb_InetAccept( hListen )
      IF hSocket == NIL
         // Accept timed out (no pending connection) - keep the UI responsive
         // and handle a 'C' keypress (connected-client overview).
         MCP_Http_PumpKeys()
         MCP_Http_MaybeReload( nPort, lAutoReload, @hListen, @lRestart )
         LOOP
      ENDIF

      // Bound how long one (possibly stalled) client can occupy its worker:
      // each socket read/write times out after 10s.
      hb_InetTimeout( hSocket, 10000 )

      // Hand the connection to a free worker; it is served in parallel.
      hb_mutexNotify( s_hMcpQueue, hSocket )

      // Housekeeping runs on the accept thread, so 'C', the reload check and
      // the heartbeat stay responsive even while all workers are busy.
      MCP_Http_PumpKeys()
      MCP_Http_MaybeReload( nPort, lAutoReload, @hListen, @lRestart )
   ENDDO

   // ---- Stop the pool: one NIL per worker, then wait for them ----------
   // In-flight requests are allowed to finish (join), so a reload/shutdown
   // never interrupts a write mid-transaction.
   MCP_Http_Log( "Beende Worker-Pool (" + LTrim( Str( Len( s_aMcpWorkers ) ) ) + " Thread(s))..." )
   AEval( s_aMcpWorkers, {|| hb_mutexNotify( s_hMcpQueue, NIL ) } )
   AEval( s_aMcpWorkers, {|h| hb_threadJoin( h ) } )
   s_aMcpWorkers := {}

   IF hListen != NIL
      hb_InetClose( hListen )
   ENDIF
   hb_InetCleanup()
   dbCloseAll()

   IF s_lMcpDash
      SetCursor( 1 )   // restore the cursor the dashboard hid (SC_NORMAL)
   ENDIF

   IF lRestart
      MCP_Http_Log( "Alte Instanz wird beendet." )
      QUIT
   ENDIF


RETURN NIL

//---------------------------------------------------------------------------
// Worker pool (uhttpd-style). The accept loop notifies s_hMcpQueue with a
// socket; each worker subscribes, serves one connection and closes it. Harbour
// work areas AND the LetoDB connection are thread-local, so every worker opens
// its own connection once at startup and its own aliases lazily on first use.
//---------------------------------------------------------------------------

// Number of worker threads: -threads N on the command line, else 4. Clamped to
// [1, 32]. Setting it to 1 gives back the old serial behaviour (a safe
// fallback if the linked LetoDB RDD turns out not to like per-thread sessions).
STATIC FUNCTION MCP_Http_PoolSize()
   LOCAL nX, cArg, nSize := 4
   FOR nX := 1 TO HB_ArgC()
      cArg := Lower( HB_ArgV(nX) )
      IF ( cArg == "-threads" .OR. cArg == "--threads" ) .AND. nX < HB_ArgC()
         nSize := Val( HB_ArgV(nX + 1) )
      ENDIF
   NEXT
   IF nSize < 1
      nSize := 1
   ELSEIF nSize > 32
      nSize := 32
   ENDIF
RETURN nSize

// One pool worker. Owns its LetoDB connection + work areas (both thread-local
// in Harbour MT) and serves connections handed to it via s_hMcpQueue until it
// receives a NIL shutdown token. Read tools run here concurrently; serial-lane
// tools take s_hMcpSerialize inside MCP_Http_DispatchSerial.
STATIC FUNCTION MCP_Http_Worker( nWorker )
   LOCAL hSocket

   // Route runtime errors to this worker's per-connection RECOVER instead of
   // aborting the thread. ErrorBlock is thread-local, so this is per-worker.
   ErrorBlock( {|oErr| Break( oErr ) } )

   // BATCHMODE is already set process-wide by MCP_Http() before the pool
   // starts (config is a process-global store), so no per-worker write here -
   // it would only race other workers on the same hash.

   // Each worker needs its OWN LetoDB connection: work areas are thread-local
   // and bind to the connection current in THIS thread.
   MCP_Http_ConnectLeto( nWorker )

   DO WHILE .T.
      hSocket := NIL
      hb_mutexSubscribe( s_hMcpQueue,, @hSocket )   // block until a socket (or NIL) arrives
      IF hSocket == NIL
         EXIT                                        // shutdown token
      ENDIF

      BEGIN SEQUENCE
         MCP_Http_ServeConnection( hSocket )
      RECOVER
         // A single bad connection must never take a worker down.
         MCP_Http_Log( "  !! Fehler bei der Verarbeitung - Verbindung wird geschlossen" )
      END SEQUENCE

      hb_InetClose( hSocket )
   ENDDO

   dbCloseAll()   // close this worker's own work areas / connection
RETURN NIL

// Establish this worker thread's own LetoDB connection (once). NetUse decides
// LETO vs. local from getConfigValue("leto_server"); when that is empty the
// build uses local drivers and no connect is needed. Guarded so a missing
// LETO_Connect symbol or a connect failure logs rather than kills the worker.
//
// IMPORTANT: the main Trader connects with ZombieCheck ON (tr_002.prg), so a
// second LETO_Connect using the SAME username makes the server kill the older
// session with that name. Each worker therefore connects under a UNIQUE
// username (<winuser>-mcpN) so it can never tear down the main app's - or a
// sibling worker's - session.
STATIC FUNCTION MCP_Http_ConnectLeto( nWorker )
   LOCAL cServer := ""
   LOCAL cUser
   LOCAL lOk := .T.

   IF t_lLetoReady
      RETURN .T.
   ENDIF

   cUser := HB_UserName() + "-mcp" + LTrim( Str( IIF( HB_IsNumeric( nWorker ), nWorker, 0 ) ) )

   // No RETURN inside BEGIN SEQUENCE in this build (E0025) - use a flag.
   BEGIN SEQUENCE
      cServer := getConfigValue( "leto_server" )
   RECOVER
      cServer := ""
   END SEQUENCE

   IF ! Empty( cServer )
      BEGIN SEQUENCE
         IF LETO_Connect( cServer, cUser ) < 0
            MCP_Http_Log( "  !! Worker " + cUser + " ohne LetoDB-Verbindung (" + cServer + ") - Anfragen dieses Threads schlagen fehl" )
            lOk := .F.
         ENDIF
      RECOVER
         MCP_Http_Log( "  !! LETO_Connect im Worker fehlgeschlagen (" + cUser + " @ " + cServer + ")" )
         lOk := .F.
      END SEQUENCE
   ENDIF

   IF lOk
      t_lLetoReady := .T.
   ENDIF
RETURN lOk

// Routine health / uptime-monitor endpoints. Their traffic is muted in the
// GUI log (still counted in the dashboard's health-check total).
STATIC FUNCTION MCP_Http_IsHealthPath( cPath )
RETURN cPath == "/" .OR. cPath == "/health" .OR. cPath == "/healthz"

// Tools that modify data. A read-only API key may not call these, and they
// run one-at-a-time (see MCP_Http_IsSerialTool).
STATIC FUNCTION MCP_Http_IsWriteTool( cToolName )
   LOCAL cName := Lower( AllTrim( cToolName ) )
RETURN cName == "set_supplier_holiday" .OR. ;
       cName == "book_shipping_confirmation" .OR. ;
       cName == "add_delivery_schedule" .OR. ;
       cName == "add_supplier_quote" .OR. ;
       cName == "confirm_purchase_order"

// Tools that must run one-at-a-time: every write tool, plus the ones that
// read/switch the process-global Trader user context (Tr_GetIni(28) /
// SystemUser). Every other tool is a pure read and runs concurrently.
STATIC FUNCTION MCP_Http_IsSerialTool( cToolName )
RETURN MCP_Http_IsWriteTool( cToolName ) .OR. ;
       Lower( AllTrim( cToolName ) ) == "get_current_user"

// Tool name of a tools/call request ("" for anything else).
STATIC FUNCTION MCP_Http_ReqToolName( hReq )
   LOCAL hParams
   IF ValType( hReq ) == "H" .AND. HHasKey( hReq, "params" )
      hParams := hReq["params"]
      IF ValType( hParams ) == "H" .AND. HHasKey( hParams, "name" ) .AND. ValType( hParams["name"] ) == "C"
         RETURN hParams["name"]
      ENDIF
   ENDIF
RETURN ""

// Serial-lane dispatch: hold s_hMcpSerialize for the whole call so writes never
// overlap, and switch the process-global user context (entry 28) to the caller
// for the duration - this is the ONLY place that global is mutated, so reads
// running in parallel never observe a half-switched identity. Restored (and the
// lock released) even when the dispatch errors out.
STATIC FUNCTION MCP_Http_DispatchSerial( hReq )
   LOCAL cResponse, nOldUser, oErr

   hb_mutexLock( s_hMcpSerialize )
   nOldUser := Tr_GetIni( 28 )
   IF t_nReqUser > 0
      Tr_GetIni( 28, t_nReqUser )
   ENDIF
   BEGIN SEQUENCE
      cResponse := ProcessMCPRequest( hReq )
   RECOVER USING oErr
      Tr_GetIni( 28, nOldUser )
      hb_mutexUnlock( s_hMcpSerialize )
      Break( oErr )
   END SEQUENCE
   Tr_GetIni( 28, nOldUser )
   hb_mutexUnlock( s_hMcpSerialize )
RETURN cResponse

//---------------------------------------------------------------------------
// GUI dashboard: a status header (port, worker pool, live request/client
// counters, uptime) painted on top, and a scrolling log region below - the
// uhttpd layout. Only active under a GUI GT (QOUT sink); headless runs keep
// plain line logging on stderr. All screen writes use hb_DispOutAt/hb_Scroll
// (MT-safe positional output) and are serialized with the other GT writes via
// s_hMcpState inside MCP_Http_Log / MCP_Http_DashHeader.
//---------------------------------------------------------------------------

// Enable the split view (GUI only): clear the screen, hide the cursor and set
// the log region to start empty below the header.
STATIC FUNCTION MCP_Http_DashInit( nPort )
   IF MCP_Http_LogSink() != "QOUT"
      RETURN NIL                 // headless / stderr: keep plain line logging
   ENDIF
   s_lMcpDash      := .T.
   s_nMcpDashPort  := nPort
   s_nMcpStartSecs := Seconds()
   SetColor( "W/N" )
   CLS
   SetCursor( 0 )                // hide cursor (SC_NONE)
   MCP_Http_DashHeader()
RETURN NIL

// Format a duration in seconds as HH:MM:SS.
STATIC FUNCTION MCP_Http_Hms( nSecs )
   LOCAL nH, nM, nS
   nSecs := Int( nSecs )
   nH := Int( nSecs / 3600 )
   nM := Int( ( nSecs % 3600 ) / 60 )
   nS := nSecs % 60
RETURN StrZero( nH, 2 ) + ":" + StrZero( nM, 2 ) + ":" + StrZero( nS, 2 )

// Repaint the status header. Called from the accept-thread housekeeping
// (MCP_Http_PumpKeys), so it refreshes about once a second when idle and after
// every accepted connection under load.
STATIC FUNCTION MCP_Http_DashHeader()
   LOCAL nActive := 0, cKey, nAge, nNow := Seconds(), nUp, nKnown
   LOCAL lLock

   IF ! s_lMcpDash
      RETURN NIL
   ENDIF

   // The mutex only exists once the pool is up; the first paint (from
   // MCP_Http_DashInit) runs single-threaded before that.
   lLock := ( s_hMcpState != NIL )
   IF lLock
      hb_mutexLock( s_hMcpState )
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
   nKnown := Len( s_hMcpClients )

   nUp := nNow - s_nMcpStartSecs
   IF nUp < 0
      nUp += 86400
   ENDIF

   hb_DispOutAt( 0, 0, PadR( " Trader MCP-Server   Port " + LTrim( Str( s_nMcpDashPort ) ) + ;
      "   " + LTrim( Str( s_nMcpPoolSize ) ) + " Worker-Threads   Streamable HTTP", MaxCol() ), "N/W" )

   hb_DispOutAt( 2, 2, PadR( "Aktive Anfragen : " + Str( s_nMcpActiveReq, 4 ) + ;
      "  (max " + LTrim( Str( s_nMcpMaxActive ) ) + ")", 38 ) )
   hb_DispOutAt( 3, 2, PadR( "Anfragen gesamt : " + Str( s_nMcpTotalReq, 8 ), 38 ) )
   hb_DispOutAt( 4, 2, PadR( "Langsam (>=1s)  : " + Str( s_nMcpSlowReq, 8 ), 38 ) )

   hb_DispOutAt( 2, 42, PadR( "Clients aktiv : " + Str( nActive, 4 ) + " / " + ;
      LTrim( Str( nKnown ) ) + " bekannt", MaxCol() - 42 ) )
   hb_DispOutAt( 3, 42, PadR( "Health-Checks : " + Str( s_nSlashHits, 8 ), MaxCol() - 42 ) )
   hb_DispOutAt( 4, 42, PadR( "Laufzeit      : " + MCP_Http_Hms( nUp ), MaxCol() - 42 ) )

   hb_DispOutAt( 6, 2, PadR( "Speicher " + LTrim( Str( Int( Memory( HB_MEM_USED ) ) ) ) + ;
      "    Zeit " + Time() + "    Taste 'C' = Client-Uebersicht", MaxCol() - 2 ) )

   hb_DispOutAt( MCP_DASH_SEPROW, 0, Replicate( "-", MaxCol() ) )

   IF lLock
      hb_mutexUnlock( s_hMcpState )
   ENDIF
RETURN NIL

// Request accounting for the dashboard counters (called around each dispatch).
STATIC FUNCTION MCP_Http_ReqBegin()
   IF s_hMcpState != NIL
      hb_mutexLock( s_hMcpState )
   ENDIF
   s_nMcpActiveReq++
   s_nMcpTotalReq++
   IF s_nMcpActiveReq > s_nMcpMaxActive
      s_nMcpMaxActive := s_nMcpActiveReq
   ENDIF
   IF s_hMcpState != NIL
      hb_mutexUnlock( s_hMcpState )
   ENDIF
RETURN NIL

STATIC FUNCTION MCP_Http_ReqEnd( nMs )
   IF s_hMcpState != NIL
      hb_mutexLock( s_hMcpState )
   ENDIF
   IF s_nMcpActiveReq > 0
      s_nMcpActiveReq--
   ENDIF
   IF HB_IsNumeric( nMs ) .AND. nMs >= 1000
      s_nMcpSlowReq++
   ENDIF
   IF s_hMcpState != NIL
      hb_mutexUnlock( s_hMcpState )
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

// Resolve a Trader user (buyer record number) from an e-mail address, for the
// OAuth path: the buyer's Email field is matched case-insensitively and the
// user must be active. cName is returned by reference; 0 when not found. The
// buyer record number is the user id used throughout (Tr_GetIni(28), DbGoTo).
STATIC FUNCTION MCP_Http_UserByEmail( cEmail, cName )
   LOCAL nUser := 0, nOld := Select()
   LOCAL cWant := Lower( AllTrim( cEmail ) )

   cName := ""
   IF Empty( cWant )
      RETURN 0
   ENDIF
   NetUse( "buyer", "buy" )
   buy->( DbGoTop() )
   DO WHILE ! buy->( Eof() )
      IF buy->Aktive .AND. Lower( AllTrim( buy->Email ) ) == cWant
         nUser := buy->( RecNo() )
         cName := AllTrim( buy->Buyer )
         EXIT
      ENDIF
      buy->( DbSkip() )
   ENDDO
   DbSelectArea( nOld )
RETURN nUser

// Check the Authorization header against the key table and resolve the
// Trader user. Returns NIL when the request may proceed (nUser/cUserName/
// lReadOnly by reference; nUser stays 0 and lReadOnly .F. when authentication
// is disabled), otherwise the error text for the 401 response.
STATIC FUNCTION MCP_Http_Auth( hHeaders, cUrlKey, nUser, cUserName, lReadOnly )
   LOCAL hKeys := MCP_Http_LoadKeys()
   LOCAL cAuth, cApiKey, xEntry

   nUser := 0
   cUserName := ""
   lReadOnly := .F.

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
      // A key can be marked read-only: its requests may call read tools only.
      IF HHasKey( xEntry, "readonly" ) .AND. ValType( xEntry["readonly"] ) == "L"
         lReadOnly := xEntry["readonly"]
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
   LOCAL cAuthErr, nAuthUser := 0, cAuthName := "", lReadOnly := .F.
   LOCAL cEmail
   LOCAL cUrlKey := "", cQPart
   LOCAL lQuiet, cPeer

   // In GUI mode (QOUT log sink) the routine "/" traffic is not logged - it
   // would flood the visible console. Warnings, errors and requests to other
   // paths stay visible; the stderr sink keeps logging everything.
   lQuiet := ( MCP_Http_LogSink() == "QOUT" )
   cPeer := MCP_Http_Peer( hSocket )
   t_lMcpQuietReq := .F.  // set once the path is known; early sends stay logged

   // Request context for the connected-client overview (see MCP_Http_TrackClient).
   // Peer is known now; the user/name follow once authentication succeeds.
   t_cReqPeer := cPeer
   t_nReqUser := 0
   t_cReqName := ""
   t_lReqReadOnly := .F.

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

   // Routine health/monitoring traffic (/, /health, /healthz - e.g. Uptime
   // Kuma) is muted in GUI mode: it would flood the log and is already counted
   // in the dashboard's health-check total. This also mutes the matching 2xx
   // response line in MCP_Http_Send (errors are always logged there).
   t_lMcpQuietReq := lQuiet .AND. MCP_Http_IsHealthPath( cPath )

   // Log the request line (method, path, and body size for POST). All parts
   // come from the wire - print them filtered so binary/garbage input cannot
   // corrupt the console. Health/monitoring calls are hidden in GUI mode.
   IF ! lQuiet .OR. ! MCP_Http_IsHealthPath( cPath )
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
         s_nSlashHits++      // cumulative health-check count for the dashboard
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

   // OAuth path (public endpoint via mcp.ashx): the IIS handler has already
   // validated the Keycloak JWT and passes the caller's e-mail in X-Auth-Email.
   // We trust it because port 8765 is localhost-only and only mcp.ashx forwards
   // here. Map the e-mail to a Trader user and act as that user. This is the
   // OAuth-only path; the API-key path below stays for direct/local use.
   IF HHasKey( hHeaders, "X-AUTH-EMAIL" ) .AND. ! Empty( hHeaders["X-AUTH-EMAIL"] )
      cEmail := AllTrim( hHeaders["X-AUTH-EMAIL"] )
      nAuthUser := MCP_Http_UserByEmail( cEmail, @cAuthName )
      IF nAuthUser == 0
         MCP_Http_Log( "  403: kein aktiver Trader-Benutzer fuer " + cEmail + IIF( lQuiet, " [" + cPeer + "]", "" ) )
         MCP_Http_Send( hSocket, 403, "application/json", ;
            hb_jsonEncode( {"error"=>"no_trader_user", "error_description"=>"No active Trader user for " + cEmail} ), aCors )
         RETURN NIL
      ENDIF
      t_nReqUser := nAuthUser
      t_cReqName := cAuthName
      t_lReqReadOnly := .F.   // authenticated per-user identity acts as itself
      IF ! lQuiet
         MCP_Http_Log( "  OAuth-Benutzer: " + cAuthName + " (" + LTrim( Str( nAuthUser ) ) + ") <" + cEmail + ">" )
      ENDIF
      MCP_Http_HandleMessage( hSocket, cBody, cSessionId, aCors )
      RETURN NIL
   ENDIF

   // Per-user API-key authentication (mcp_keys.json); see above. The 401 body
   // uses the OAuth Bearer error format of RFC 6750 ({"error": "<string>",
   // "error_description": ...}) - that is what MCP clients like mcp-remote
   // parse on a 401; a JSON-RPC error object here makes them fail ("expected
   // string, received object"). The right client setup is a static header
   // (e.g. mcp-remote --header "Authorization: Bearer <key>").
   cAuthErr := MCP_Http_Auth( hHeaders, cUrlKey, @nAuthUser, @cAuthName, @lReadOnly )
   IF cAuthErr != NIL
      MCP_Http_Log( "  401: " + cAuthErr + IIF( lQuiet, " [" + cPeer + "]", "" ) )
      AAdd( aCors, 'WWW-Authenticate: Bearer realm="Trader MCP", error="invalid_token", error_description="' + cAuthErr + '"' )
      MCP_Http_Send( hSocket, 401, "application/json", ;
         hb_jsonEncode( {"error"=>"invalid_token", "error_description"=>cAuthErr} ), aCors )
      RETURN NIL
   ENDIF

   // Remember the authenticated user for this request (thread-local). The
   // process-global user context (entry 28) is NOT switched here anymore:
   // read tools run in parallel and must not touch that global. Only
   // serial-lane tools switch it, under the serialize lock (DispatchSerial).
   t_nReqUser := nAuthUser
   t_cReqName := cAuthName
   t_lReqReadOnly := lReadOnly
   IF nAuthUser > 0 .AND. ! lQuiet
      MCP_Http_Log( "  Benutzer: " + cAuthName + " (" + LTrim( Str( nAuthUser ) ) + ")" + ;
         IIF( lReadOnly, " [read-only]", "" ) )
   ENDIF

   // The worker's per-connection RECOVER (MCP_Http_Worker) catches dispatch
   // errors, so no local error trap is needed here.
   MCP_Http_HandleMessage( hSocket, cBody, cSessionId, aCors )

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
            MCP_Http_ReqBegin()
            cItem := MCP_Http_DispatchOne( xMsg[nX], cSessionId, @lIsInitialize, @cNewSession )
            MCP_Http_ReqEnd( 0 )
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

   MCP_Http_ReqBegin()
   nT0 := Seconds()
   cResponse := MCP_Http_DispatchOne( hReq, cSessionId, @lIsInitialize, @cNewSession )
   nMs := Int( ( Seconds() - nT0 ) * 1000 )
   IF nMs < 0                       // clock passed midnight during the request
      nMs += 86400000
   ENDIF
   MCP_Http_ReqEnd( nMs )
   // Surface slow requests - a slow serial-lane call can still make queued
   // writes wait. Only >=1s is logged, to avoid noise.
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

   // A read-only API key may not call write tools.
   IF cMethod == "tools/call" .AND. t_lReqReadOnly .AND. MCP_Http_IsWriteTool( MCP_Http_ReqToolName( hReq ) )
      RETURN CreateErrorResponse( "This API key is read-only - the write tool '" + ;
         MCP_Http_ReqToolName( hReq ) + "' is not permitted", ;
         IIF( HHasKey( hReq, "id" ), hReq["id"], "" ) )
   ENDIF

   // Write / user-context tools go through the serialized lane; everything
   // else (reads, initialize, tools/list, notifications) runs in parallel.
   IF cMethod == "tools/call" .AND. MCP_Http_IsSerialTool( MCP_Http_ReqToolName( hReq ) )
      RETURN MCP_Http_DispatchSerial( hReq )
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
   // (t_lMcpQuietReq, see ServeConnection); errors are always logged.
   IF ! t_lMcpQuietReq .OR. nStatus >= 400
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
   LOCAL lLock

   IF ! s_lMcpHttpVerbose
      RETURN NIL
   ENDIF

   IF Empty( s_cMcpLogSink )
      s_cMcpLogSink := MCP_Http_LogSink()
   ENDIF

   cLine := "[MCP-HTTP " + Time() + "] " + cMsg

   // Serialize the log device across worker threads so lines from concurrent
   // requests do not interleave. The mutex exists only once the pool is up;
   // before that (startup) there is a single thread, so no lock is needed.
   lLock := ( s_hMcpState != NIL )
   IF lLock
      hb_mutexLock( s_hMcpState )
   ENDIF
   IF s_lMcpDash
      // Split view: scroll the log region up by one and write the newest line
      // at the bottom, leaving the status header untouched.
      hb_Scroll( MCP_LOG_FIRSTROW, 0, MaxRow(), MaxCol(), 1 )
      hb_DispOutAt( MaxRow(), 0, PadR( cLine, MaxCol() ) )
   ELSEIF s_cMcpLogSink == "QOUT"
      QOut( cLine )
   ELSE
      FWrite( hb_GetStdErr(), cLine + Chr(10) )
   ENDIF
   IF lLock
      hb_mutexUnlock( s_hMcpState )
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
// recently. Requests are served by a worker pool, so a "client" is tracked by
// its MCP session id across requests; clients that send no session id are
// collapsed onto one peer+user entry. The shared table is guarded by
// s_hMcpState because workers update it concurrently.
//---------------------------------------------------------------------------

STATIC FUNCTION MCP_Http_TrackClient( cSessionId, cNewSession, cMethod )
   LOCAL cKey, hRec, lNew := .F.
   LOCAL nNow := Seconds()

   hb_mutexLock( s_hMcpState )

   cKey := IIF( ! Empty( cSessionId ), cSessionId, ;
           IIF( ! Empty( cNewSession ), cNewSession, ;
                t_cReqPeer + "#" + LTrim( Str( t_nReqUser ) ) ) )

   IF ! HHasKey( s_hMcpClients, cKey )
      s_hMcpClients[ cKey ] := { "user"=>t_nReqUser, "name"=>t_cReqName, "peer"=>t_cReqPeer, ;
         "first"=>nNow, "count"=>0, "last"=>nNow, "lasttime"=>Time(), "method"=>"" }
      lNew := .T.
   ENDIF
   hRec := s_hMcpClients[ cKey ]
   hRec[ "count" ]++
   hRec[ "last" ]     := nNow
   hRec[ "lasttime" ] := Time()
   hRec[ "method" ]   := cMethod
   IF t_nReqUser > 0        // identity may have been unknown on the very first hit
      hRec[ "user" ] := t_nReqUser
      hRec[ "name" ] := t_cReqName
   ENDIF
   IF ! Empty( t_cReqPeer )
      hRec[ "peer" ] := t_cReqPeer
   ENDIF

   IF lNew
      MCP_Http_Log( "Neuer Client verbunden: " + MCP_Http_ClientLabel( hRec ) + "  [Sitzung " + Left( cKey, 32 ) + "]" )
   ENDIF

   hb_mutexUnlock( s_hMcpState )
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

   hb_mutexLock( s_hMcpState )

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

   hb_mutexUnlock( s_hMcpState )
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
   MCP_Http_DashHeader()        // refresh the GUI status header (no-op if off)
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
