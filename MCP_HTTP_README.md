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
- **`GET /healthz`**, `GET /health`, `GET /` — health check, returns `ok`.
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

## Notes / limitations (single-response mode)

- Single-threaded: one request is served at a time, matching the STDIO loop, so
  the global work areas / LetoDBF state used by the tools stay serialised and
  need no extra locking. Going multi-threaded later means giving each worker
  its own work-area/DB session.
- No SSE streaming yet: long tools return only their final result, not
  incremental progress. Adding a `text/event-stream` branch to
  `MCP_Http_HandleMessage()` is the natural next step and does not affect any
  tool code.
