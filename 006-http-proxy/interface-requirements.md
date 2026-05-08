# S006 Interface Requirements

### S006-IF-001 Proxy listen address [P1]

The proxy **MUST** listen on a TCP socket. The default address **MUST** be the
network gateway IP (e.g. `10.200.0.1`) on port `8080`.

Configuration override via `outcalld` flags:

```
outcalld --proxy-addr 10.200.0.1:9090    # custom port
outcalld --proxy-addr 0.0.0.0:8080       # all interfaces (not recommended)
outcalld --no-proxy                       # disable the proxy entirely
```

When `--no-proxy` is specified, the proxy task **MUST NOT** start and
container env vars **MUST NOT** include `HTTP_PROXY`/`HTTPS_PROXY`.

### S006-IF-002 HTTP CONNECT protocol [P1]

The proxy **MUST** implement the HTTP CONNECT method per RFC 7231 Section 4.3.6.

**Client sends:**

```
CONNECT api.github.com:443 HTTP/1.1
Host: api.github.com:443

```

**Proxy response (allowed):**

```
HTTP/1.1 200 Connection Established

```

After sending `200 Connection Established`, the proxy **MUST** tunnel raw bytes
bidirectionally. The proxy peeks at the first bytes from the client (the TLS
ClientHello) to extract the SNI hostname before establishing the upstream
connection and beginning the tunnel.

**Proxy response (blocked):**

```
HTTP/1.1 403 Forbidden
Content-Type: text/plain
Content-Length: <length>
X-Outcall-Block-Reason: <reason>

Blocked by outcall: <reason>
```

### S006-IF-003 HTTP direct proxy protocol [P1]

For non-CONNECT HTTP requests, the proxy **MUST** accept absolute-form URIs
per RFC 7230 Section 5.3.2.

**Client sends:**

```
GET http://api.example.com/v1/data HTTP/1.1
Host: api.example.com
Accept: application/json

```

The proxy extracts the target from the absolute URI, evaluates rules, and
forwards the request (rewritten to origin-form) to the upstream server.

**Proxy response (blocked):**

```
HTTP/1.1 403 Forbidden
Content-Type: text/plain
Content-Length: <length>
X-Outcall-Block-Reason: <reason>

Blocked by outcall: <reason>
```

**Proxy response (upstream error):**

```
HTTP/1.1 502 Bad Gateway
Content-Type: text/plain
Content-Length: <length>

Upstream connection failed: <detail>
```

### S006-IF-004 403 BLOCK response format [P1]

All blocked responses **MUST** use the following format:

| Field | Value |
|-------|-------|
| Status | `403 Forbidden` |
| Content-Type | `text/plain` |
| X-Outcall-Block-Reason | The rule engine's block reason string |
| Body | `Blocked by outcall: <reason>` |

The `X-Outcall-Block-Reason` header enables programmatic detection of proxy
blocks by agent tooling.

### S006-IF-005 Container environment variables [P1]

When launching an agent container on an outcall network with the proxy enabled,
`outcalld` **MUST** set these environment variables:

```
HTTP_PROXY=http://10.200.0.1:8080
HTTPS_PROXY=http://10.200.0.1:8080
http_proxy=http://10.200.0.1:8080
https_proxy=http://10.200.0.1:8080
NO_PROXY=localhost,127.0.0.1
no_proxy=localhost,127.0.0.1
```

The address and port **MUST** match the proxy's actual listen address.
`NO_PROXY` **MUST** include `localhost` and `127.0.0.1` so that
container-internal traffic bypasses the proxy.

### S006-IF-006 Health check endpoint [P2]

```
GET /outcall-health HTTP/1.1
Host: 10.200.0.1:8080
```

**Response:**

```
HTTP/1.1 200 OK
Content-Type: application/json
Content-Length: <length>

{
  "status": "ok",
  "active_connections": 42,
  "total_requests": 1500,
  "total_blocked": 37
}
```

This endpoint **MUST NOT** be forwarded upstream. It is identified by the
exact path `/outcall-health` with no query string.

### S006-IF-007 CEL context variables [P1]

The proxy **MUST** populate the following variables in the CEL evaluation
context passed to the rule engine (S003):

| Variable | Type | Source | Example |
|----------|------|--------|---------|
| `network.hostname` | `string` | Host header (HTTP), SNI or CONNECT line (HTTPS) | `"api.github.com"` |
| `http.method` | `string` | HTTP method | `"GET"`, `"POST"`, `"CONNECT"` |
| `http.path` | `string` | Request path (HTTP) or `"/"` (CONNECT) | `"/v1/data"` |
| `http.headers.<name>` | `string` | Request headers, name lowercased | `http.headers.accept` = `"application/json"` |

For CONNECT requests:
- `http.method` **MUST** be `"CONNECT"`
- `http.path` **MUST** be `"/"`
- `http.headers.*` **MUST** contain only the headers from the CONNECT request line, not headers from the tunneled TLS traffic

For HTTP requests:
- `http.method` **MUST** be the actual HTTP method
- `http.path` **MUST** be the path component of the request URI
- `http.headers.*` **MUST** contain the request headers
