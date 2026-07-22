# MCP over Streamable HTTP(S)

`mcp_stdio.prg` now exposes the Trader MCP server over **two** transports that
share the exact same dispatch (`ProcessMCPRequest()`) and the exact same
`MCP_Tool_*` implementations:

| Transport | Entry function | Use for |
|-----------|----------------|---------|
| STDIO     | `MCP_StdIO()`  | Local launch by Claude Desktop (spawns the exe per client). |
| HTTP      | `MCP_Http()`   | A long-running server reachable over the network / behind HTTPS. |

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

`mcp_stdio.prg` is compiled together with the rest of Trader (it calls
`Adresse()`, `Auftrag()`, `NetUse()`, …), so no separate build target is
required — the new `MCP_Http` / `MCP_Http_*` functions are part of the same
binary. Rebuild Trader as usual, e.g.:

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
