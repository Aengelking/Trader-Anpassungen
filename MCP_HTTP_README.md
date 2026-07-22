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

It also ships a built-in **OAuth 2.1 layer** (on by default), because Claude's
remote-connector flow — in both claude.ai and Claude Desktop — always performs
OAuth with Dynamic Client Registration and refuses to connect without it. See
[OAuth 2.1](#oauth-21-required-by-claude-connectors) below. You can turn it off
for a pure authless server.

## Why there is no TLS in the Harbour code

Harbour's raw sockets do not speak TLS unless linked against `hbssl`
(OpenSSL). The supported and recommended setup here is:

```
Client ──HTTPS──▶ Reverse proxy (Caddy/nginx)  ──HTTP──▶ MCP_Http() on 127.0.0.1:8765
        (TLS)      terminates TLS, same host             (plaintext, localhost only)
```

`MCP_Http()` binds to `127.0.0.1` by default, so only a proxy on the same host
can reach it. The proxy owns the certificate and the public port.

## OAuth 2.1 (required by Claude connectors)

Claude's remote-connector flow (claude.ai **and** Claude Desktop) always tries
to authenticate via OAuth 2.1 with **Dynamic Client Registration** and will not
connect to a server that offers no OAuth. A plain authless endpoint fails with
*"Registrierung beim Anmeldedienst … fehlgeschlagen" / "Couldn't register with
sign-in service"*.

Therefore `mcp_http.prg` implements the full OAuth flow as an **auto-approve
shim** — there is no real user login; it simply satisfies the protocol so
Claude can connect:

| Endpoint | RFC | Purpose |
|----------|-----|---------|
| `GET /.well-known/oauth-protected-resource`   | 9728 | points Claude at the authorization server |
| `GET /.well-known/oauth-authorization-server` | 8414 | advertises the endpoints below |
| `POST /register` | 7591 | Dynamic Client Registration (accepts any client) |
| `GET /authorize` | 6749 | auto-approves, redirects back with a code (PKCE **S256**) |
| `POST /token`    | 6749 | issues a signed **JWT** access + refresh token |

An unauthenticated `POST` to the MCP endpoint returns `401` with a
`WWW-Authenticate: Bearer resource_metadata="…"` header, which is what kicks the
flow off. All artefacts (client_id, authorization code, access/refresh tokens)
are self-contained JWTs signed with a keychain secret, so the server keeps **no
OAuth state in memory** and survives a restart (clients just silently re-run the
OAuth dance).

### Setup (one-time)

1. **Create the signing secret** in the Trader keychain under the name
   **`MCP-OAUTH-SECRET`** (any long random string). Without it, `MCP_Http()`
   refuses to start while OAuth is on and prints a clear message to stderr.
   The JWT signing reuses `Trader/lib/jwt.prg` (HS256 / `hb_HMAC_SHA256`).
2. **Set the public base URL** so the discovery metadata advertises correct
   `https://…` URLs. Most robust is the config key **`MCP_HTTP_PUBLIC_URL`**
   (e.g. `https://mcp.example.com`). If unset, the server derives it from the
   `X-Forwarded-Proto` / `X-Forwarded-Host` (or `Host`) headers — so the proxy
   must forward the **original Host** (see the proxy sections below).
3. **Mount the connector at the domain root.** Point Claude at
   `https://mcp.example.com/` (not a sub-path), so the well-known and
   `/authorize` `/token` `/register` paths line up with the advertised metadata.
   If you must use a sub-path, set `MCP_HTTP_PUBLIC_URL` to that exact base.

The reverse-proxy rules already shown forward **every** path to the listener, so
`/authorize`, `/token`, `/register` and the `/.well-known/*` documents are
covered automatically — no extra proxy rules are needed.

### Build note

PKCE S256 uses `hb_SHA256`, which `mcp_http.prg` forces into the link with
`REQUEST HB_SHA256`. If your build strips it, add `HB_SHA256` to the `EXTERNAL`
list in `tr_001.prg`.

### Turning OAuth off (pure authless)

For local testing or a network where you don't want the shim, start with
`MCP_Http( 8765, "127.0.0.1", .F. )` or set the config key **`MCP_HTTP_OAUTH=0`**.
Then the MCP endpoint answers without a token and the `/.well-known/*` and OAuth
endpoints are disabled.

### Security note

The shim **grants a token to anyone who can reach the endpoint** — it is not a
real identity check. The actual access boundary is the network / reverse proxy
in front of it. Keep the listener bound to `127.0.0.1`, keep the public port
behind TLS, and restrict who can reach the proxy (VPN, IP allow-list, etc.). If
you need genuine per-user authentication, this shim is the wrong tool — front
the server with a real identity provider instead.

> Note: Anthropic has an open report ([claude-ai-mcp#457](https://github.com/anthropics/claude-ai-mcp/issues/457))
> where even a fully correct OAuth+DCR server is occasionally rejected by the
> **claude.ai web** connector. Claude **Desktop** is the reliable target for
> this setup.

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
MCP_Http( 8765 )                       // 127.0.0.1:8765, OAuth on (default)
MCP_Http( 8765, "0.0.0.0" )            // all interfaces (only if not proxying)
MCP_Http( 8765, "127.0.0.1", .F. )     // OAuth OFF (pure authless)
```

Quick smoke test — health and OAuth discovery are open even with OAuth on:

```bash
curl -s http://127.0.0.1:8765/healthz
# -> ok

curl -s http://127.0.0.1:8765/.well-known/oauth-authorization-server
# -> {"issuer":"https://…","authorization_endpoint":"…/authorize", …}
```

With OAuth **on**, a `POST` to the MCP endpoint without a Bearer token returns
`401` (that is expected — it starts the OAuth flow):

```bash
curl -s -i http://127.0.0.1:8765/ \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}'
# -> HTTP/1.1 401 Unauthorized
#    WWW-Authenticate: Bearer resource_metadata="…/.well-known/oauth-protected-resource"
```

To exercise the JSON-RPC dispatch directly, start with OAuth **off**
(`MCP_Http( 8765, "127.0.0.1", .F. )` or `MCP_HTTP_OAUTH=0`):

```bash
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

- **`POST /`** (any path except the OAuth ones) — a JSON-RPC message. With
  OAuth on it requires a valid `Authorization: Bearer <token>`, else `401` with
  a `WWW-Authenticate` challenge. Returns the JSON-RPC response
  (`application/json`). A JSON-RPC *notification* (no `id`) returns `202
  Accepted` with an empty body; a *batch* (array) returns an array of the
  responses that carry an `id`.
- **`GET /healthz`**, `GET /health` — health check, returns `ok` (always open).
- **OAuth endpoints** (only when OAuth is on): `GET /.well-known/oauth-protected-resource`,
  `GET /.well-known/oauth-authorization-server`, `POST /register`,
  `GET /authorize`, `POST /token` — see [OAuth 2.1](#oauth-21-required-by-claude-connectors).
- **`GET`** on any other path — `405` (single-response mode offers no SSE
  stream). With OAuth **off**, `GET /` returns `ok` as a health check.
- **`OPTIONS`** — CORS preflight, returns `204`.

The MCP endpoint path is otherwise ignored, but mount the connector at the
domain **root** so the OAuth well-known paths resolve (or set
`MCP_HTTP_PUBLIC_URL`).

### Sessions

On `initialize` the server issues an `Mcp-Session-Id` response header. If a
client then sends an `Mcp-Session-Id` request header that the server does not
recognise, it answers `404` so the client knows to re-initialise. Clients that
send no session id keep working (lenient by design).

### Origins / CORS

By default any `Origin` is accepted, which is safe while the listener is bound
to localhost behind a trusted proxy. To lock the endpoint down to specific
browser front-ends, return an allow-list from `MCP_Http_AllowedOrigins()` in
`mcp_http.prg`, e.g.:

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

When you add it as a custom connector, Claude runs the OAuth dance
automatically (discovery → registration → `/authorize` → `/token`). Because the
`/authorize` step **auto-approves**, there is no login screen — Claude gets its
token and connects. Make sure the keychain secret `MCP-OAUTH-SECRET` exists and
`MCP_HTTP_PUBLIC_URL` (or a Host-preserving proxy) is set, otherwise the token
step fails.

## Notes / limitations (single-response mode)

- Single-threaded: one request is served at a time, matching the STDIO loop, so
  the global work areas / LetoDBF state used by the tools stay serialised and
  need no extra locking. Going multi-threaded later means giving each worker
  its own work-area/DB session.
- No SSE streaming yet: long tools return only their final result, not
  incremental progress. Adding a `text/event-stream` branch to
  `MCP_Http_HandleMessage()` is the natural next step and does not affect any
  tool code.
