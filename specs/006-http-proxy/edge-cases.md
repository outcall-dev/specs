# S006 Edge Cases

| ID | Scenario | Expected Behavior |
|----|----------|-------------------|
| S006-EC-001 | SNI absent from TLS ClientHello | Fall back to hostname from the CONNECT request line. If that is an IP address, evaluate rules with the IP. |
| S006-EC-002 | Upstream connection refused | Return HTTP 502 Bad Gateway to the client. Log the failure at `warn` level. |
| S006-EC-003 | Upstream DNS resolution failure | Return HTTP 502 Bad Gateway to the client. The response body **MUST** indicate DNS failure. |
| S006-EC-004 | Client disconnects mid-tunnel | Close the upstream connection. Clean up resources. No error response needed. |
| S006-EC-005 | Upstream disconnects mid-tunnel | Close the client connection. Clean up resources. No error response needed (data already partially sent). |
| S006-EC-006 | Extremely large headers (> 8 KiB) | Return HTTP 431 Request Header Fields Too Large. Do not forward. |
| S006-EC-007 | Non-standard HTTP method (e.g. PATCH, DELETE) | Evaluate against the rule engine like any other method. The proxy does not restrict HTTP methods -- only the rule engine decides. |
| S006-EC-008 | Rule engine unavailable or errors | Default to BLOCK. Return HTTP 403 with reason `"rule engine unavailable"`. Log at `error` level. |
| S006-EC-009 | CONNECT to non-443 port (e.g. `CONNECT host:8443`) | Proceed normally. The proxy **MUST NOT** restrict CONNECT to port 443 only. The full `host:port` is used for upstream connection. |
| S006-EC-010 | Proxy address not reachable from container | Container HTTP client will fail to connect. This is a network configuration issue, not a proxy error. The proxy logs nothing (no connection received). |
| S006-EC-011 | HTTP/2 CONNECT (RFC 8441) | Not supported. The proxy **MUST** operate at HTTP/1.1. HTTP/2 clients talking to the proxy **MUST** downgrade to HTTP/1.1. |
| S006-EC-012 | Rapid reconnect flood from a single container | The max-connections limit applies globally. Individual connections are cheap. If the limit is hit, new connections receive 503. No per-client rate limiting in v1. |
| S006-EC-013 | Daemon shutdown with active tunnels | Stop accepting new connections. Wait up to the grace period (default 5s) for active tunnels. After the grace period, forcibly close remaining tunnels. |
| S006-EC-014 | WebSocket upgrade (`Connection: Upgrade, Upgrade: websocket`) via HTTP/1.1 | Treat as a normal HTTP request for rule evaluation (hostname, path, method). If ALLOW, forward the request including hop-by-hop headers (`Connection`, `Upgrade`, `Sec-WebSocket-*`) and tunnel the upgraded connection bidirectionally, same as CONNECT. |
