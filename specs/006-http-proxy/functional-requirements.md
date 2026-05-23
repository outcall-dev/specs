# S006 Functional Requirements

### Proxy lifecycle

S006-FR-001 [P1] The HTTP proxy **MUST** run as a Tokio task within the `outcalld` process. There **MUST NOT** be a separate proxy process.

S006-FR-002 [P1] The proxy **MUST** listen on a configurable `<address>:<port>`. The default **MUST** be the network gateway address (e.g. `10.200.0.1`) on port `8080`. The listen address **MUST** be overridable via `outcalld` configuration.

S006-FR-015 [P1] On `outcalld` shutdown, the proxy **MUST** stop accepting new connections and **MUST** drain active tunnels within a grace period (default 5 seconds). After the grace period, remaining connections **MUST** be dropped.

S006-FR-022 [P2] The proxy **SHOULD** expose a health check on `GET /outcall-health` that returns HTTP 200. This endpoint **MUST NOT** be forwarded upstream.

### HTTP direct forwarding

S006-FR-003 [P1] For plain HTTP requests (non-CONNECT), the proxy **MUST** parse the absolute-form URI to extract the target hostname, port, method, path, and headers. It **MUST** forward the request to the upstream server and relay the response back to the client.

S006-FR-020 [P2] The proxy **SHOULD** strip hop-by-hop headers (`Connection`, `Proxy-Connection`, `Keep-Alive`, `Transfer-Encoding`, `TE`, `Trailer`, `Upgrade`, `Proxy-Authorization`, `Proxy-Authenticate`) before forwarding requests upstream.

S006-FR-019 [P1] The proxy **MUST** resolve upstream hostnames via the system DNS resolver. DNS resolution failures **MUST** result in an HTTP 502 response to the client.

### HTTPS CONNECT tunneling

S006-FR-004 [P1] For HTTPS, the proxy **MUST** handle the HTTP `CONNECT` method. Upon receiving `CONNECT host:port`, the proxy **MUST** peek at the initial TLS ClientHello from the client to extract the SNI hostname before making a forwarding decision.

S006-FR-005 [P1] SNI extraction **MUST** use `rustls` to parse the TLS ClientHello. The proxy **MUST** read enough bytes to parse the ClientHello without consuming them -- the original bytes **MUST** be forwarded to the upstream server if the connection is allowed.

S006-FR-017 [P1] The proxy **MUST NOT** decrypt TLS traffic. It **MUST NOT** terminate the TLS connection. The proxy acts as a transparent tunnel after the initial SNI peek.

S006-FR-018 [P2] If the TLS ClientHello does not contain an SNI extension, the proxy **SHOULD** use the hostname from the `CONNECT` request line as the evaluation hostname. If that is an IP address, the proxy **MUST** evaluate rules with the IP address as the hostname value.

### Rule engine integration

S006-FR-006 [P1] Before forwarding any request (HTTP or HTTPS), the proxy **MUST** evaluate it against the rule engine (S003). The proxy **MUST NOT** forward traffic without a rule evaluation.

S006-FR-007 [P1] The proxy **MUST** populate the following CEL context variables for rule evaluation:
S006-FR-007.a `network.hostname` -- the target hostname (from the Host header for HTTP, from SNI or CONNECT line for HTTPS)
S006-FR-007.b `http.method` -- the HTTP method (e.g. `GET`, `POST`). For CONNECT requests, this **MUST** be `"CONNECT"`.
S006-FR-007.c `http.path` -- the request path. For CONNECT requests, this **MUST** be `"/"`.
S006-FR-007.d `http.headers.<name>` -- request headers, lowercased. For CONNECT requests, only the headers on the CONNECT request itself are available.

S006-FR-009 [P1] When the rule engine returns ALLOW, the proxy **MUST** forward the request (HTTP) or send `200 Connection Established` and begin tunneling (HTTPS CONNECT).

S006-FR-008 [P1] When the rule engine returns BLOCK, the proxy **MUST** return HTTP 403 to the client. The response body **MUST** include the block reason from the rule engine. For CONNECT requests, the 403 **MUST** be sent before any `200 Connection Established` response.

### Timeouts and resource limits

S006-FR-010 [P2] The proxy **MUST** enforce a connect timeout when establishing the upstream connection. The default **MUST** be 10 seconds. The timeout **MUST** be configurable.

S006-FR-011 [P2] The proxy **MUST** enforce an idle timeout on tunneled connections. If no data flows in either direction for the idle timeout period (default 300 seconds), the proxy **MUST** close both sides of the tunnel.

S006-FR-012 [P2] The proxy **MUST** enforce a maximum number of concurrent connections (default 1024). When the limit is reached, new connections **MUST** receive HTTP 503 Service Unavailable and be closed.

### Logging

S006-FR-013 [P2] The proxy **MUST** log every BLOCK verdict at `warn` level, including: source IP, target hostname, HTTP method, path (if available), and the block reason.

S006-FR-013.a [P2] The proxy **SHOULD** log every ALLOW verdict at `debug` level with the same fields.

### Authentication

S006-FR-014 [P3] The proxy **MAY** support optional proxy authentication via the `Proxy-Authorization` header. When enabled, unauthenticated requests **MUST** receive HTTP 407 Proxy Authentication Required. When disabled (the default), the proxy **MUST NOT** require authentication.

### Container configuration

S006-FR-016 [P1] When launching agent containers, `outcalld` **MUST** set the following environment variables:
S006-FR-016.a `HTTP_PROXY` set to `http://<proxy_addr>:<proxy_port>`
S006-FR-016.b `HTTPS_PROXY` set to `http://<proxy_addr>:<proxy_port>`
S006-FR-016.c `http_proxy` set to the same value as `HTTP_PROXY` (lowercase variant for compatibility)
S006-FR-016.d `https_proxy` set to the same value as `HTTPS_PROXY` (lowercase variant for compatibility)

### Error handling

S006-FR-021 [P1] When the upstream server is unreachable (connection refused, timeout, DNS failure), the proxy **MUST** return an appropriate HTTP error to the client:
S006-FR-021.a DNS resolution failure: HTTP 502 Bad Gateway
S006-FR-021.b Connection refused: HTTP 502 Bad Gateway
S006-FR-021.c Connect timeout: HTTP 504 Gateway Timeout

### Fail-closed

S006-FR-022 [P1] If the rule engine returns an error or is unavailable, the proxy **MUST** return HTTP 403 Forbidden (default BLOCK). This behavior **MUST NOT** be configurable.
