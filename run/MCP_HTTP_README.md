# MCP over Streamable HTTP(S)

The Trader MCP server is exposed over **two** transports that share the exact
same dispatch (`ProcessMCPRequest()`) and the exact same `MCP_Tool_*`
implementations:

| Transport | Entry function | Source file     | Use for |
|-----------|----------------|-----------------|---------|
| STDIO     | `MCP_StdIO()`  | `mcp_stdio.prg` | Local launch by Claude Desktop (spawns the exe per client). |
| HTTP      | `MCP_Http()`   | `mcp_http.prg`  | A long-running server reachable over the network / behind HTTPS. |

`mcp_http.prg` is not self-contained: it reuses the public
`ProcessMCPRequest()` / `CreateErrorResponse()` functions (and, through them,
every `MCP_Tool_*`) defined in `mcp_stdio.prg`, so **both files must be built
together**.

The HTTP transport implements the MCP **Streamable HTTP** transport in its
*single JSON response* mode: the client `POST`s one JSON-RPC message to a
single endpoint and gets one JSON-RPC response back with
`Content-Type: application/json`. No SSE stream is opened yet (it can be added
later without touching any tool code).

## Why there is no TLS in the Harbour code

Harbour's raw sockets do not speak TLS unless linked against `hbssl`
(OpenSSL). The supported and recommended setup here is:

```
Client ──HTTPS──▶ Reverse proxy (Caddy/nginx)  ──HTTP──▶ MCP_Http() on 127.0.0.1:8765
        (TLS)      terminates TLS, same host             (plaintext, localhost only)
```

`MCP_Http()` binds to `127.0.0.1` by default, so only a proxy on the same host
can reach it. The proxy owns the certificate and the public port.

## Build

`mcp_stdio.prg` and `mcp_http.prg` are compiled together with the rest of
Trader (they call `Adresse()`, `Auftrag()`, `NetUse()`, …), so no separate
build target is required — the `MCP_Http` / `MCP_Http_*` functions are part of
the same binary. Ensure `mcp_http.prg` is included in the build alongside
`mcp_stdio.prg`, then rebuild Trader as usual, e.g.:

```bash
hbmk2 trader.hbp
```

## Run

Start the HTTP listener (default port 8765, bound to localhost):

```bash
trader.exe -F mcp_http            # if launched by run-script name/entry
# or, however this run-script's entry function is selected in your launcher,
# call MCP_Http() instead of MCP_StdIO().
```

Override the port on the command line:

```bash
trader.exe ... -port 9000
```

Or call it directly from code / a launcher:

```harbour
MCP_Http( 8765 )                  // 127.0.0.1:8765
MCP_Http( 8765, "0.0.0.0" )       // all interfaces (only if not proxying)
```

Quick smoke test (no proxy needed):

```bash
curl -s http://127.0.0.1:8765/healthz
# -> ok

curl -s http://127.0.0.1:8765/ \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}'
# -> {"jsonrpc":"2.0","id":1,"result":{...}}   plus an Mcp-Session-Id response header

curl -s http://127.0.0.1:8765/ \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":2,"method":"tools/list"}'
```

## Auto-reload on source changes

The listener watches `run\mcp_http.prg` and `run\mcp_stdio.prg` (checked
roughly every 10 idle seconds, never during a request). When either file
changes, the server frees the port, launches a **new instance with the same
command line** (`WAPI_ShellExecute` + `Exename()`/`DosParam()`, the same
relaunch idiom as `tr_001.prg`) and quits — deploying a new server version is
just copying the file. If the relaunch fails, the old instance re-binds the
port and keeps running on the old code (logged). Disable with the fourth
parameter: `MCP_Http( , , , .F. )`.

Note that the source check only advances on **idle** ticks (between requests).
The relaunch itself never waits for clients — it frees the port and spawns the
new instance regardless — but under constant request load the idle ticks needed
to notice the change come rarely, so a reload can lag until traffic quiets. Use
the client overview below to see whether clients are still hammering the server.

## GUI dashboard (split view)

Under a GUI GT the server window shows a **status header** on top and a
**scrolling log** below (the uhttpd layout). The header refreshes ~once a
second and shows: port and worker-thread count, in-flight requests (with the
concurrency high-water mark), total requests, slow requests (>=1s), active vs.
known clients, health-check count, uptime, memory and the clock. New log lines scroll
in at the bottom of the lower region; the header is never overwritten. Under a
headless/NUL GT this is skipped and logging stays line-based on stderr.

## Connected-client overview (GUI)

In GUI mode press **`C`** in the server window to log an overview of the
currently connected clients. Accept runs on the main thread and hands each
connection to a worker pool; a "client" is tracked by its MCP session id across
requests (clients that send none are collapsed onto one peer+user entry). Each
line shows the user (from the API key), the peer address, the request count and
the time / age of the last request; "aktiv" means a request within the last
120 seconds. A `Neuer Client verbunden` line is logged the first time a session
is seen. The table is pruned after an hour of inactivity per client.

## Authentication: OAuth (per-user) vs. API keys

There are two ways the acting Trader user is determined:

1. **OAuth (per-user)** — used for the public endpoint. An IIS handler
   (`Trader-www/mcp/mcp.ashx`) terminates TLS, validates the caller's Keycloak
   JWT (issuer, audience, RS256 via JWKS), and forwards the request to this
   server on `127.0.0.1:8765` with the caller's e-mail in an **`X-Auth-Email`**
   header. When that header is present this server maps the e-mail to the
   active Trader user (buyer) with that Email and acts as that user
   (`MCP_Http_UserByEmail`). Each person signs in with their own M365 account,
   so writes are stamped to the real user. Trust is safe because 8765 is
   localhost-only and only `mcp.ashx` (after verifying the JWT) sets the header
   — never expose 8765 publicly. Setup: `Trader-www/mcp/DEPLOY-MCP-IIS.md`
   (Keycloak + Entra + IIS on `https://api.engelking.de:2000/mcp`).

2. **API keys** — for direct/local use (STDIO, or hitting 8765 without the
   OAuth proxy). See below.

Without either the server is **open** — anyone who can reach the port
can call every tool under the user context of the process that started the
server. To restore per-user boundaries, create `mcp_keys.json` in the
**config folder below the data path** (`<DATA>\config\mcp_keys.json`).
Protect the file with an ACL so that only the Windows account running the
server can read it:

```json
{
  "keys": {
    "K7f3x…long-random-string…":  { "user": 5, "name": "Amos" },
    "Q9zd…another-random-key…":   { "user": 12, "name": "Elias" },
    "S1de…sidekick-key…":         { "user": 9, "name": "Sidekick", "readonly": true },
    "legacy-short-form-key":      7
  }
}
```

* `user` is the Trader user (buyer) record number; the user must exist and be
  active. The short form (key → number) is also accepted.
* `readonly: true` restricts a key to **read tools only** — the write tools
  (`set_supplier_holiday`, `book_shipping_confirmation`,
  `add_delivery_schedule`, `confirm_purchase_order`) return a JSON-RPC error
  ("This API key is read-only …"). Recommended for external integrations such
  as chayns/Sidekick, where all users share the one key's identity.
* As soon as the file contains at least one key, every `POST` must send
  `Authorization: Bearer <key>` (a bare key without `Bearer` is accepted
  too); anything else gets `401`. `OPTIONS` (CORS preflight) and
  `GET /healthz` stay open.
* The Trader user context (`trader.ini` entry 28 / `DNUM`) is switched to the
  key's user only for **serial-lane** tools (writes and `get_current_user`),
  which run one at a time under a shared lock — so the global switch never
  races. Parallel read tools do not touch that global. The context is restored
  after every serial call, also on errors.
* The file is re-read automatically when its timestamp changes; keys can be
  added/revoked without restarting the server.
* **No file (or an empty `keys` map) = authentication off** — the server
  logs a warning and behaves as before, so the rollout cannot lock anyone
  out.
* Keys travel in plain text unless HTTPS is terminated in front of the
  server — use one of the proxy setups below for anything beyond localhost.
* Suggested ACL (as the server's Windows account or an admin):
  `icacls "<DATA>\config\mcp_keys.json" /inheritance:r /grant:r "%USERNAME%:R" "SYSTEM:F"`
* Note: David/OLE tools (inbox, e-mail, reminders, SMS and the document
  archive) have been **removed** from the MCP server — the Tobit David COM
  API is apartment-threaded and cannot run on the worker pool.

Claude Desktop / MCP clients: pass the key either as a header
`Authorization: Bearer <key>` **or in the URL as `?key=<key>`**. The URL form
is the recommended one for `mcp-remote`: its `--header` argument is mangled by
npx/cmd on Windows (spaces get split), which ends in a `401` and a doomed
OAuth probe. With the key in the URL no header is needed and the OAuth path
is never entered:

```json
{
  "mcpServers": {
    "trader": {
      "command": "npx",
      "args": ["mcp-remote", "https://mcp.example.com/?key=<key>"]
    }
  }
}
```

(Keys in URLs can end up in proxy logs — with the recommended local
proxy-only exposure that is the same trust domain as the server log.)

Note: a `401` answers in the OAuth Bearer error format of RFC 6750
(`{"error":"invalid_token","error_description":"…"}`) plus a matching
`WWW-Authenticate` header — that is the shape MCP clients parse on auth
failures. There is no OAuth flow behind it: unknown endpoints such as
`/register` return `404`, so OAuth-probing clients fail fast with a clear
message instead of looping. Fix a 401 by correcting the static key.

## HTTPS with Caddy (simplest — automatic certificates)

`Caddyfile`:

```
mcp.example.com {
    reverse_proxy 127.0.0.1:8765
}
```

```bash
caddy run
```

That is the whole configuration — Caddy obtains and renews the certificate and
forwards plaintext to the local listener.

## HTTPS with nginx

```nginx
server {
    listen 443 ssl;
    server_name mcp.example.com;

    ssl_certificate     /etc/ssl/certs/mcp.example.com.pem;
    ssl_certificate_key /etc/ssl/private/mcp.example.com.key;

    location / {
        proxy_pass         http://127.0.0.1:8765;
        proxy_http_version 1.1;
        proxy_set_header   Host        $host;
        proxy_set_header   X-Real-IP   $remote_addr;
        # Let the MCP session header pass through unchanged.
        proxy_pass_header  Mcp-Session-Id;
    }
}
```

## HTTPS with IIS (Windows)

> **Engelking deployment note:** the public site is already served by IIS from
> the `Trader-www` repo, and that server has **URL Rewrite but not ARR** and
> uses small `.ashx` forwarding handlers (see `webui/api.ashx`). A ready-to-use,
> no-ARR MCP handler lives in **`Trader-www/mcp/`** (`mcp.ashx` + `web.config` +
> `DEPLOY-MCP-IIS.md`): mount that folder as the `/mcp` IIS application
> (anonymous auth) and register `https://<host>/mcp` in chayns. Use the generic
> ARR variant below only if you prefer a dedicated proxy site.

Since Trader runs on Windows, IIS is often the most convenient proxy — it can
terminate TLS and forward to the localhost listener. IIS is not a reverse proxy
out of the box; you add two free Microsoft modules:

1. **URL Rewrite** — https://www.iis.net/downloads/microsoft/url-rewrite
2. **Application Request Routing (ARR)** — https://www.iis.net/downloads/microsoft/application-request-routing

### One-time setup

1. Install both modules (Web Platform Installer, or the standalone MSIs above),
   then restart IIS (`iisreset`).
2. **Enable the proxy** (ARR is a proxy only after this is switched on):
   IIS Manager → select the **server** node → *Application Request Routing
   Cache* → *Server Proxy Settings…* (right pane) → tick **Enable proxy** →
   *Apply*.
3. Create a site (or reuse *Default Web Site*) and add an **https binding** with
   your certificate:
   IIS Manager → site → *Bindings…* → *Add…* → type `https`, port `443`, host
   name `mcp.example.com`, pick the TLS certificate. For a free/auto-renewing
   certificate use **win-acme** (https://www.win-acme.com/), which installs the
   cert straight into the IIS binding.

### Site `web.config`

Drop this into the site's root (it forwards every request to the local
`MCP_Http()` listener on `127.0.0.1:8765`):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
  <system.webServer>
    <rewrite>
      <rules>
        <rule name="MCP reverse proxy" stopProcessing="true">
          <match url="(.*)" />
          <action type="Rewrite" url="http://127.0.0.1:8765/{R:1}" />
        </rule>
      </rules>
    </rewrite>
    <!-- Optional: redirect plain HTTP to HTTPS -->
    <httpRedirect enabled="false" />
  </system.webServer>
</configuration>
```

ARR forwards request and response headers unchanged, so the `Mcp-Session-Id`
header travels through in both directions without extra configuration.

### Streaming / buffering (for when SSE is added later)

The current single-response mode returns a complete JSON body, so buffering is
harmless. If/when the server is extended to emit a `text/event-stream`, turn off
ARR's response buffering or the client will not receive events incrementally:

- IIS Manager → **server** node → *Application Request Routing Cache* → *Server
  Proxy Settings…* → set **Response buffer threshold (KB)** to `0` (and
  *Response buffer (KB)* to `0`) → *Apply*.

Also consider raising the ARR **Time-out (seconds)** on that same page if any
tool can run longer than the default 120 s.

### Notes

- Keep `MCP_Http()` bound to `127.0.0.1` (the default). IIS on the same host
  reaches it; nothing else can.
- If you host the endpoint under a **sub-path** (e.g. `https://host/mcp/…`),
  either rewrite the path away as shown (`{R:1}` preserves it and the Harbour
  server ignores the path anyway) or point the MCP client URL at that sub-path —
  both work.
- WebSockets are **not** required; the transport is plain HTTP request/response
  (plus, later, one-way SSE), so no WebSocket module or `webSocket` binding is
  needed.

## Endpoint behaviour

- **`POST /`** (any path) — a JSON-RPC message. Returns the JSON-RPC response
  (`application/json`). A JSON-RPC *notification* (no `id`) returns `202
  Accepted` with an empty body. A JSON-RPC *batch* (array) returns an array of
  the responses that carry an `id`.
- **`GET /healthz`**, `GET /health` — health check, always returns `ok`.
  Meant for uptime monitors (e.g. Uptime Kuma). This traffic is **not logged**
  in GUI mode (it would flood the log); instead it is counted in the
  dashboard's *Health-Checks* total.
- **`GET /`** — returns `ok` for a plain health probe (also muted/counted as a
  health check), but `405` when the client asks for the server→client SSE
  stream (`Accept: text/event-stream`). Single-response mode offers no stream,
  and per the MCP spec `405` tells the client to stop; answering such a stream
  GET with `200 ok` made some clients retry the GET in a loop (a source of
  request storms on `/`).
- **`GET`** on any other path — `405` (single-response mode offers no SSE
  stream).
- **`OPTIONS`** — CORS preflight, returns `204`.

Path is otherwise ignored, so mounting the proxy at a sub-path that rewrites to
`/` works fine.

### Sessions

On `initialize` the server issues an `Mcp-Session-Id` response header. If a
client then sends an `Mcp-Session-Id` request header that the server does not
recognise, it answers `404` so the client knows to re-initialise. Clients that
send no session id keep working (lenient by design).

### Origins / CORS

By default any `Origin` is accepted, which is safe while the listener is bound
to localhost behind a trusted proxy. To lock the endpoint down to specific
browser front-ends, return an allow-list from `MCP_Http_AllowedOrigins()` in
`mcp_stdio.prg`, e.g.:

```harbour
STATIC FUNCTION MCP_Http_AllowedOrigins()
RETURN { "https://app.example.com" }
```

## Configuring Claude / an MCP client

Point the client at the proxied HTTPS URL as a Streamable HTTP server, e.g.:

```json
{
  "mcpServers": {
    "trader": {
      "type": "http",
      "url": "https://mcp.example.com/"
    }
  }
}
```

## Multithreading (worker pool)

The HTTP server uses a fixed pool of worker threads (uhttpd-style): the main
thread accepts connections and hands each socket to a free worker through a
`hb_mutex` job queue. This means one slow query (a large scan) no longer blocks
every other client.

- **Read tools run in parallel.** Harbour work areas and the LetoDB connection
  are thread-local, so each worker opens its **own** LetoDB connection once at
  startup (under a unique username `<winuser>-mcpN`, so the main app's
  ZombieCheck connection is never killed) and its own work areas lazily.
- **Writes are serialized.** Tools that write (`set_supplier_holiday`,
  `book_shipping_confirmation`, `add_delivery_schedule`,
  `confirm_purchase_order`) and the one tool that reads the global user context
  (`get_current_user`) run one at a time under a shared lock. That lock is also
  the only place the process-global Trader user context (entry 28) is switched,
  so a parallel read never observes a half-switched identity. LetoDB record
  locking handles read-during-write at the server, exactly as for normal
  multi-user Trader clients.
- **Pool size:** `-threads N` on the command line (default **4**, clamped
  1..32). `-threads 1` restores fully serial behaviour — a safe fallback if the
  linked LetoDB RDD turns out not to support per-thread sessions.
- **David/OLE removed:** the Tobit David COM API is apartment-threaded and
  cannot run on a worker pool, so all David-backed tools (inbox, e-mail,
  reminders, SMS, document archive) were removed.

> Verify once on the target build that the linked LetoDB client RDD supports
> one connection per thread (start with a small pool and watch for cross-talk
> between concurrent requests). If in doubt, run with `-threads 1` first.

## Notes / limitations (single-response mode)

- No SSE streaming yet: long tools return only their final result, not
  incremental progress. Adding a `text/event-stream` branch to
  `MCP_Http_HandleMessage()` is the natural next step and does not affect any
  tool code.
