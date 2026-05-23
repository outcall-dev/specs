# S006: HTTP Proxy

| Field | Value |
|-------|-------|
| Spec | S006 |
| Feature | HTTP Proxy |
| Date | 2026-04-21 |
| Status | Implemented |
| Author | @marktopper |

## Overview

Provide L7 (application layer) inspection of outbound HTTP and HTTPS traffic
from agent containers. The proxy runs as a Tokio task inside `outcalld` --
there is no separate process. Agent containers reach the proxy via standard
`HTTP_PROXY` / `HTTPS_PROXY` environment variables.

For plain HTTP, the proxy sees the full request (method, path, headers,
hostname) and evaluates it against the rule engine before forwarding. For
HTTPS, the proxy receives an HTTP `CONNECT` request, peeks at the TLS
ClientHello to extract the SNI hostname, evaluates rules, and either tunnels
the raw bytes or returns a 403.

### How it works

1. `outcalld` starts the proxy listener as part of its normal startup.
2. Agent containers are launched with `HTTP_PROXY` and `HTTPS_PROXY` pointing
   at the proxy address (e.g. `http://10.200.0.1:8080`).
3. The proxy receives requests:
   - **HTTP**: direct request with full URL -- proxy inspects and forwards.
   - **HTTPS**: `CONNECT host:443` -- proxy peeks at TLS SNI, inspects, then
     tunnels if allowed.
4. Each request is evaluated against the rule engine (S003). The CEL context
   is populated with `network.hostname`, `http.method`, `http.path`, and
   `http.headers.*`.
5. If the verdict is ALLOW, traffic is forwarded/tunneled.
6. If the verdict is BLOCK, the proxy returns HTTP 403 with a reason body.

### Tech stack

- `hyper` for HTTP handling (request parsing, response generation)
- `rustls` for TLS ClientHello / SNI parsing (no decryption)

## User Scenarios

S006-US-001 [P1] As a host operator, I want all outbound HTTP/HTTPS traffic from agent containers to pass through an inspecting proxy so that rule-based access control is enforced at the application layer.

S006-US-002 [P1] As a host operator, I want the proxy to evaluate each request against the rule engine so that I can allow or block traffic by hostname, path, method, or header values.

S006-US-003 [P1] As a host operator, I want HTTPS connections to be inspected by SNI without decrypting the traffic so that hostname-based rules work while preserving end-to-end encryption.

S006-US-004 [P2] As a host operator, I want the proxy to log blocked requests with the reason so that I can audit policy violations.

S006-US-005 [P2] As a host operator, I want connection limits and timeouts so that a misbehaving agent cannot exhaust proxy resources.

## Requirements Summary

| ID | Type | Priority | Title | Status |
|----|------|----------|-------|--------|
| S006-FR-001 | Functional | P1 | In-process Tokio task | Draft |
| S006-FR-002 | Functional | P1 | Listen address configuration | Draft |
| S006-FR-003 | Functional | P1 | HTTP direct forwarding | Draft |
| S006-FR-004 | Functional | P1 | HTTPS CONNECT tunneling | Draft |
| S006-FR-005 | Functional | P1 | SNI extraction from ClientHello | Draft |
| S006-FR-006 | Functional | P1 | Rule engine integration | Draft |
| S006-FR-007 | Functional | P1 | CEL context population | Draft |
| S006-FR-008 | Functional | P1 | BLOCK verdict response | Draft |
| S006-FR-009 | Functional | P1 | ALLOW verdict forwarding | Draft |
| S006-FR-010 | Functional | P2 | Connection timeout | Draft |
| S006-FR-011 | Functional | P2 | Idle timeout | Draft |
| S006-FR-012 | Functional | P2 | Max concurrent connections | Draft |
| S006-FR-013 | Functional | P2 | Request logging | Draft |
| S006-FR-014 | Functional | P3 | Proxy authentication | Draft |
| S006-FR-015 | Functional | P1 | Graceful shutdown | Draft |
| S006-FR-016 | Functional | P1 | Container env var injection | Draft |
| S006-FR-017 | Functional | P1 | No TLS decryption | Draft |
| S006-FR-018 | Functional | P2 | SNI-absent HTTPS handling | Draft |
| S006-FR-019 | Functional | P1 | Upstream DNS resolution | Draft |
| S006-FR-020 | Functional | P2 | Hop-by-hop header stripping | Draft |
| S006-FR-021 | Functional | P1 | Error propagation | Draft |
| S006-FR-022 | Functional | P2 | Health check endpoint | Draft |
| S006-AS-001 | Acceptance | P1 | HTTP GET allowed | Draft |
| S006-AS-002 | Acceptance | P1 | HTTP GET blocked | Draft |
| S006-AS-003 | Acceptance | P1 | HTTPS CONNECT allowed | Draft |
| S006-AS-004 | Acceptance | P1 | HTTPS CONNECT blocked | Draft |
| S006-AS-005 | Acceptance | P1 | SNI hostname extraction | Draft |
| S006-AS-006 | Acceptance | P1 | Rule engine verdict BLOCK | Draft |
| S006-AS-007 | Acceptance | P2 | Connection timeout | Draft |
| S006-AS-008 | Acceptance | P2 | Max connections reached | Draft |
| S006-AS-009 | Acceptance | P1 | Proxy startup and shutdown | Draft |
| S006-AS-010 | Acceptance | P2 | No SNI in ClientHello | Draft |
| S006-AS-011 | Acceptance | P1 | Multiple agents concurrent | Draft |
| S006-AS-012 | Acceptance | P2 | Upstream unreachable | Draft |
| S006-AS-013 | Acceptance | P2 | Blocked request logging | Draft |
| S006-IF-001 | Interface | P1 | Proxy listen address | Draft |
| S006-IF-002 | Interface | P1 | HTTP CONNECT protocol | Draft |
| S006-IF-003 | Interface | P1 | HTTP direct proxy protocol | Draft |
| S006-IF-004 | Interface | P1 | 403 BLOCK response format | Draft |
| S006-IF-005 | Interface | P1 | Container environment variables | Draft |
| S006-IF-006 | Interface | P2 | Health check endpoint | Draft |
| S006-IF-007 | Interface | P1 | CEL context variables | Draft |
| S006-EC-001 | Edge Case | P1 | SNI absent from ClientHello | Draft |
| S006-EC-002 | Edge Case | P1 | Upstream connection refused | Draft |
| S006-EC-003 | Edge Case | P1 | Upstream DNS failure | Draft |
| S006-EC-004 | Edge Case | P2 | Client disconnects mid-tunnel | Draft |
| S006-EC-005 | Edge Case | P2 | Upstream disconnects mid-tunnel | Draft |
| S006-EC-006 | Edge Case | P2 | Extremely large headers | Draft |
| S006-EC-007 | Edge Case | P2 | Non-CONNECT non-HTTP method | Draft |
| S006-EC-008 | Edge Case | P1 | Rule engine unavailable | Draft |
| S006-EC-009 | Edge Case | P2 | Port other than 443 in CONNECT | Draft |
| S006-EC-010 | Edge Case | P2 | Proxy address not reachable from container | Draft |
| S006-EC-011 | Edge Case | P3 | HTTP/2 CONNECT | Draft |
| S006-EC-012 | Edge Case | P2 | Rapid reconnect flood | Draft |
| S006-EC-013 | Edge Case | P1 | Daemon shutdown with active tunnels | Draft |
| S006-EC-014 | Edge Case | P2 | WebSocket upgrade handling | Draft |
| S006-SC-001 | Success | P1 | HTTP request forwarded when allowed | Draft |
| S006-SC-002 | Success | P1 | HTTPS tunnel established when allowed | Draft |
| S006-SC-003 | Success | P1 | Blocked requests return 403 | Draft |
| S006-SC-004 | Success | P1 | SNI hostname matches rule engine evaluation | Draft |
| S006-SC-005 | Success | P1 | Proxy starts and stops with outcalld | Draft |
| S006-SC-006 | Success | P1 | No TLS decryption occurs | Draft |
| S006-SC-007 | Success | P2 | Blocked requests are logged | Draft |
| S006-SC-008 | Success | P1 | Multiple concurrent agents served | Draft |
| S006-SC-009 | Success | P2 | Timeouts enforce resource limits | Draft |
| S006-SC-010 | Success | P1 | Container env vars point to proxy | Draft |

## Out of Scope

- **TLS decryption / MITM** -- the proxy inspects SNI only, never decrypts
- **Request body inspection** -- L7 inspection covers method, path, headers, hostname; not body content
- **WebSocket upgrade handling** -- initial HTTP upgrade request is evaluated, but the proxy does not inspect WebSocket frames
- **HTTP/2 multiplexing** -- the proxy operates at HTTP/1.1 level between client and proxy
- **Caching** -- the proxy is not a caching proxy
- **Content modification** -- the proxy does not rewrite request or response bodies
- **Non-HTTP protocols** -- only HTTP and HTTPS (via CONNECT) are handled
- **Per-container proxy bypass** -- all containers on the network use the same proxy; bypass is not supported

## Cross-Spec Dependencies

- **Depends on:** [S003](../003-rule-engine/index.md) (rule evaluation for each request)
- **Depends on:** [S002](../002-network-management/index.md) (proxy binds to the network gateway address)
- **Required by:** Container management (future spec -- sets HTTP_PROXY/HTTPS_PROXY env vars)

## Shared Types (outcall-api)

### Constants

```rust
pub const PROXY_DEFAULT_PORT: u16 = 8080;
pub const PROXY_CONNECT_TIMEOUT_SECS: u64 = 10;
pub const PROXY_IDLE_TIMEOUT_SECS: u64 = 300;
pub const PROXY_MAX_CONNECTIONS: usize = 1024;
pub const PROXY_MAX_HEADER_SIZE: usize = 8192;
```

### Types

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProxyConfig {
    pub listen_addr: SocketAddr,
    pub connect_timeout_secs: u64,
    pub idle_timeout_secs: u64,
    pub max_connections: usize,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProxyStatus {
    pub listening: bool,
    pub listen_addr: SocketAddr,
    pub active_connections: usize,
    pub total_requests: u64,
    pub total_blocked: u64,
}

/// Populated for each request and passed to the rule engine.
#[derive(Debug, Clone)]
pub struct ProxyRequestContext {
    pub hostname: String,
    pub method: Option<String>,
    pub path: Option<String>,
    pub headers: HashMap<String, String>,
    pub is_connect: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ProxyVerdict {
    Allow,
    Block { reason: String },
}
```
