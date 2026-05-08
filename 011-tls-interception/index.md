# S011: TLS Interception (optional)

| Field | Value |
|-------|-------|
| Spec | S011 |
| Feature | TLS Interception (optional MITM) |
| Date | 2026-05-05 |
| Status | Implemented |
| Author | @marktopper |

## Overview

Outcall's HTTP proxy (S006) does not decrypt HTTPS by default — it makes
verdicts on the CONNECT hostname and the TLS SNI, then tunnels the encrypted
bytes verbatim. That preserves end-to-end confidentiality but limits HTTPS
matching to host and port.

Some operators need more. To enforce per-method, per-path, or per-payload
policy on HTTPS endpoints, the proxy must terminate TLS, evaluate the
plaintext request against the rule engine, then re-encrypt and forward.

This spec defines an **opt-in, per-rule** TLS interception mode. It is
**off by default**. When a rule sets `egress.mode: intercept`, the proxy
performs MITM on requests matching that rule using a CA the operator
provisioned and the agent container trusts. Every other rule continues to
operate at SNI level (S006).

### Why opt-in, per-rule

TLS interception trades end-to-end encryption for visibility. The cost is
real:

- **Pinned hosts will reject the proxy.** Many SaaS providers pin
  certificates; intercepting them returns TLS errors to the agent.
- **mTLS breaks.** Client certificates terminate at the proxy.
- **PII enters the proxy.** Request and (optionally) response bodies are
  decrypted, which expands the trust boundary of the daemon.
- **CA key compromise = trust compromise.** A leaked CA key lets anyone
  impersonate every site the agent talks to.

Because of these costs, interception is per-rule, off by default, and
gated by an explicit `--ca-cert` / `--ca-key` daemon flag. Operating
without the flag disables the mode entirely — a rule that requests
`mode: intercept` against a daemon with no CA loaded fails validation at
`outcall rules reload`.

### How it works

1. Operator initialises a CA: `outcall ca init --out /etc/outcall/ca/`.
   This produces `ca.crt` and `ca.key`. The CA cert is the trust anchor
   the agent container must install.
2. Operator starts `outcalld` with `--ca-cert /etc/outcall/ca/ca.crt
   --ca-key /etc/outcall/ca/ca.key`. The proxy now has the material to
   sign per-host leaf certificates on demand.
3. Operator authors a rule with `egress.mode: intercept`:

   ```yaml
   version: "1"
   rules:
     - id: anthropic-messages-only
       condition: |
         http.host == "api.anthropic.com" &&
         http.method == "POST" &&
         http.path.startsWith("/v1/messages")
       action: allow
       egress:
         mode: intercept
   ```

4. Agent container is launched with the CA cert mounted into its trust
   store (e.g.
   `-v /etc/outcall/ca/ca.crt:/usr/local/share/ca-certificates/outcall.crt:ro`
   on Debian/Ubuntu, then `update-ca-certificates`). For Python, Node, Go,
   and curl, this is the standard CA path; for languages with their own
   bundles (e.g. Python's `certifi`), `SSL_CERT_FILE` is the override.
5. When the agent makes an HTTPS request whose CONNECT hostname matches
   an intercept rule:
   - Proxy evaluates the rule on the CONNECT hostname (S006 path).
   - Proxy sends `200 Connection Established`.
   - Proxy generates a leaf certificate for the hostname, signed by the
     CA, valid for 24h (cached in-memory keyed by hostname).
   - Proxy performs a real TLS handshake with the agent, presenting the
     leaf cert and negotiating ALPN.
   - Proxy opens its own TLS connection to upstream, negotiating the same
     ALPN.
   - Proxy reads the decrypted request, populates a full HTTP context
     (`http.method`, `http.path`, `http.headers.*`, `http.body_size`,
     optionally `http.body`), evaluates the rule engine.
   - On ALLOW: re-encrypts and forwards. On BLOCK: returns 403 over the
     established TLS session.
6. For rules that do not opt into interception, S006 behaviour is
   unchanged. The same proxy listens on the same port; the dispatch is
   per-rule.

### Tech stack

- `rcgen` to generate the CA-signed leaf certificates per hostname
- `rustls` for both client-side TLS (proxy ↔ agent) and upstream TLS
  (proxy ↔ origin), with HTTP/1.1 and HTTP/2 ALPN
- `hyper` for HTTP/1.1 and HTTP/2 request parsing on the decrypted side
- An LRU cache (max ~1024 hostnames) for generated leaf certs

## User Scenarios

S011-US-001 [P2] As a host operator, I want to allow specific HTTPS API methods and paths only, so I can enforce least-privilege access to APIs my agents call.

S011-US-002 [P2] As a host operator, I want to opt into TLS interception per rule, not globally, so I can keep most traffic untouched and only decrypt where necessary.

S011-US-003 [P2] As a host operator, I want a CLI command to generate a fresh CA, so I do not need an external PKI tool to get started.

S011-US-004 [P2] As a host operator, I want the daemon to refuse to load intercept rules when no CA is configured, so misconfiguration cannot silently degrade to default-allow.

S011-US-005 [P3] As a host operator, I want to inspect or block on request body content (e.g. forbid certain shell commands inside an HTTPS POST body), so I can catch egress that hides intent in the payload.

S011-US-006 [P2] As a host operator, I want clear feedback when interception fails (e.g. pinned host, ALPN mismatch), so I can diagnose without packet capture.

S011-US-007 [P3] As a host operator, I want a way to obtain the CA bundle from the daemon for distribution to containers, so I do not have to copy files between hosts manually.

## Requirements Summary

| ID | Type | Priority | Title | Status |
|----|------|----------|-------|--------|
| S011-FR-001 | Functional | P2 | CA load via daemon flags | Draft |
| S011-FR-002 | Functional | P2 | CA initialisation CLI command | Draft |
| S011-FR-003 | Functional | P2 | Per-rule `egress.mode: intercept` | Draft |
| S011-FR-004 | Functional | P2 | Validation: intercept requires CA | Draft |
| S011-FR-005 | Functional | P2 | Leaf certificate generation | Draft |
| S011-FR-006 | Functional | P2 | Leaf certificate cache (LRU + TTL) | Draft |
| S011-FR-007 | Functional | P2 | Client-side TLS handshake | Draft |
| S011-FR-008 | Functional | P2 | Upstream TLS handshake | Draft |
| S011-FR-009 | Functional | P2 | ALPN negotiation parity | Draft |
| S011-FR-010 | Functional | P2 | HTTP/1.1 request parsing on decrypted side | Draft |
| S011-FR-011 | Functional | P2 | HTTP/2 request parsing on decrypted side | Draft |
| S011-FR-012 | Functional | P2 | CEL context: full http.* fields | Draft |
| S011-FR-013 | Functional | P3 | CEL context: optional http.body | Draft |
| S011-FR-014 | Functional | P2 | Body buffer cap (default 1 MiB) | Draft |
| S011-FR-015 | Functional | P2 | BLOCK verdict response within TLS | Draft |
| S011-FR-016 | Functional | P2 | ALLOW verdict re-encryption + forward | Draft |
| S011-FR-017 | Functional | P2 | Fail-closed on interception error | Draft |
| S011-FR-018 | Functional | P2 | CA cert bundle CLI export | Draft |
| S011-FR-019 | Functional | P2 | Structured logging of intercepted requests | Draft |
| S011-FR-020 | Functional | P3 | Per-rule body matching opt-in | Draft |
| S011-FR-021 | Functional | P2 | Configurable leaf cert TTL | Draft |
| S011-FR-022 | Functional | P2 | Backwards compatible: no CA → no behaviour change | Draft |
| S011-AS-001 | Acceptance | P2 | Method-scoped HTTPS rule allows POST and blocks GET | Draft |
| S011-AS-002 | Acceptance | P2 | Path-scoped HTTPS rule allows /v1/x and blocks /v1/y | Draft |
| S011-AS-003 | Acceptance | P2 | Rule with `mode: intercept` rejected when no CA loaded | Draft |
| S011-AS-004 | Acceptance | P2 | Daemon starts without `--ca-cert` (interception disabled) | Draft |
| S011-AS-005 | Acceptance | P2 | Pinned upstream returns clear error to agent | Draft |
| S011-AS-006 | Acceptance | P2 | Leaf cert cached across requests to same host | Draft |
| S011-AS-007 | Acceptance | P3 | Body matcher allows JSON-payload rule | Draft |
| S011-AS-008 | Acceptance | P2 | Non-intercept rule on same daemon unchanged | Draft |
| S011-AS-009 | Acceptance | P2 | `outcall ca init` produces 4096-bit RSA CA valid 10 years | Draft |
| S011-AS-010 | Acceptance | P2 | `outcall ca bundle` emits PEM to stdout | Draft |
| S011-IF-001 | Interface | P2 | Daemon flag `--ca-cert <path>` | Draft |
| S011-IF-002 | Interface | P2 | Daemon flag `--ca-key <path>` | Draft |
| S011-IF-003 | Interface | P2 | Daemon flag `--intercept-leaf-ttl-secs <n>` | Draft |
| S011-IF-004 | Interface | P2 | Daemon flag `--intercept-body-cap-bytes <n>` | Draft |
| S011-IF-005 | Interface | P2 | Rule schema: `egress.mode: intercept` | Draft |
| S011-IF-006 | Interface | P3 | Rule schema: `egress.match_body: true` | Draft |
| S011-IF-007 | Interface | P2 | CLI: `outcall ca init [--out <dir>]` | Draft |
| S011-IF-008 | Interface | P2 | CLI: `outcall ca bundle` | Draft |
| S011-IF-009 | Interface | P2 | CLI: `outcall ca status` | Draft |
| S011-IF-010 | Interface | P2 | CEL context: `http.method`, `http.path`, `http.headers.*`, `http.body_size` | Draft |
| S011-IF-011 | Interface | P3 | CEL context: `http.body` (string, present when body matching enabled) | Draft |
| S011-EC-001 | Edge Case | P2 | Upstream pins certs (HSTS/HPKP) — agent gets TLS error | Draft |
| S011-EC-002 | Edge Case | P2 | ALPN mismatch (agent wants h2, upstream offers http/1.1) | Draft |
| S011-EC-003 | Edge Case | P2 | Agent does not trust CA — handshake fails locally | Draft |
| S011-EC-004 | Edge Case | P2 | CA key on disk is unreadable | Draft |
| S011-EC-005 | Edge Case | P2 | Body exceeds buffer cap | Draft |
| S011-EC-006 | Edge Case | P3 | Streaming response (chunked / SSE) | Draft |
| S011-EC-007 | Edge Case | P3 | WebSocket upgrade over intercepted TLS | Draft |
| S011-EC-008 | Edge Case | P2 | Cache eviction during in-flight handshake | Draft |
| S011-EC-009 | Edge Case | P2 | Client uses TLS 1.2 only | Draft |
| S011-EC-010 | Edge Case | P3 | mTLS (client cert) request — reject with documented error | Draft |
| S011-EC-011 | Edge Case | P2 | Daemon shutdown with active intercepted tunnels | Draft |
| S011-EC-012 | Edge Case | P3 | HTTP/3 / QUIC — out of scope, document explicitly | Draft |
| S011-SC-001 | Success | P2 | Decrypted method/path enforced for HTTPS endpoint | Draft |
| S011-SC-002 | Success | P2 | Default-off: daemon without CA preserves S006 behaviour exactly | Draft |
| S011-SC-003 | Success | P2 | Cache prevents re-signing on every request | Draft |
| S011-SC-004 | Success | P2 | Rule validation rejects intercept without CA | Draft |
| S011-SC-005 | Success | P2 | CA initialisation CLI produces a working CA | Draft |
| S011-SC-006 | Success | P3 | Body matching catches a known payload pattern | Draft |
| S011-SC-007 | Success | P2 | Interception logs include matched rule and outcome | Draft |
| S011-SC-008 | Success | P2 | Pinned host failure surfaces a clear operator-facing error | Draft |

## Out of Scope

- **HTTP/3 / QUIC interception** — UDP, separate handshake protocol, not handled here.
- **Default-on interception** — interception is always per-rule and opt-in.
- **Response body inspection** — only request bodies (and optionally), to keep memory and latency bounded.
- **Custom CA chains / intermediates** — v1 supports a single root CA; intermediate chains are a future extension.
- **Hardware key storage (HSM, PKCS#11)** — v1 reads key material from disk; HSM integration is a future extension.
- **TLS interception of non-HTTP protocols** — only HTTP/1.1 and HTTP/2 over TLS.
- **mTLS bridging** — interception breaks client certs by definition; this spec rejects mTLS handshakes with a documented error rather than attempting to bridge.

## Cross-Spec Dependencies

- **Depends on:** [S003](../003-rule-engine/index.md) (extended CEL context for decrypted requests)
- **Depends on:** [S006](../006-http-proxy/index.md) (this spec extends the proxy's CONNECT path)
- **Depends on:** [S007](../007-dns-filter/index.md) (DNS filter still gates which hostnames resolve at all)

## Shared Types (outcall-api)

### Constants

```rust
pub const INTERCEPT_LEAF_TTL_SECS_DEFAULT: u64 = 86_400;       // 24h
pub const INTERCEPT_BODY_CAP_BYTES_DEFAULT: usize = 1_048_576; // 1 MiB
pub const INTERCEPT_LEAF_CACHE_MAX: usize = 1024;
```

### Types

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CaConfig {
    pub cert_path: PathBuf,
    pub key_path: PathBuf,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum EgressMode {
    Proxy,      // S006: SNI-only
    DirectIp,   // S009: nftables verdict
    Intercept,  // S011: TLS termination + decrypted L7
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InterceptConfig {
    pub leaf_ttl_secs: u64,
    pub body_cap_bytes: usize,
    pub match_body: bool,        // per-rule opt-in (FR-020)
}

#[derive(Debug, Clone)]
pub struct InterceptedRequestContext {
    pub hostname: String,
    pub method: String,
    pub path: String,
    pub headers: HashMap<String, String>,
    pub body_size: usize,
    pub body: Option<String>,    // present when match_body=true and ≤ cap
}
```
