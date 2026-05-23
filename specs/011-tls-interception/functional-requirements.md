# S011 — Functional Requirements

> Per-rule, opt-in TLS interception that extends the S006 HTTP proxy. All
> requirements are **P2** unless marked otherwise. Default behaviour
> (without `--ca-cert`) MUST be byte-identical to S006.

## CA loading and lifecycle

S011-FR-001 [P2] `outcalld` **MUST** accept optional flags `--ca-cert <path>`
and `--ca-key <path>`. When both are provided and readable, the daemon
loads the CA into the proxy's signing context. When either is absent or
unreadable, interception is disabled.

S011-FR-002 [P2] The `outcall ca init [--out <dir>]` CLI command **MUST**
generate a fresh root CA: a 4096-bit RSA key (or P-384 ECDSA, configurable),
a self-signed certificate valid for ten years, and write `ca.crt` and
`ca.key` to the requested directory with file permissions `0600` for the key
and `0644` for the cert.

S011-FR-022 [P2] When neither `--ca-cert` nor `--ca-key` is supplied, the
daemon **MUST** behave exactly as S006: SNI-only matching, no MITM, no
certificate generation. Interception code paths **MUST NOT** allocate or
initialise.

## Rule schema and validation

S011-FR-003 [P2] The rule YAML schema **MUST** accept `egress.mode:
intercept` as a third value alongside `proxy` and `direct_ip`.

S011-FR-004 [P2] On `outcall rules reload` (or its host-API equivalent),
any rule with `egress.mode: intercept` **MUST** be rejected if the daemon
has no CA loaded. The reload **MUST** fail atomically — the previous rule
set stays active.

S011-FR-020 [P3] Rules **MAY** opt into request body matching via
`egress.match_body: true`. When false (default), `http.body` is `null` in
the CEL context.

## Proxy behaviour for intercept rules

S011-FR-005 [P2] On a CONNECT whose pre-SNI evaluation matched a rule with
`egress.mode: intercept`, the proxy **MUST**:
1. Send `200 Connection Established` to the client.
2. Generate or fetch a leaf certificate for the CONNECT hostname.
3. Perform a TLS handshake with the client, presenting the leaf cert.
4. Open an upstream TLS connection to the resolved host and port.
5. Read the decrypted request, evaluate the rule engine with the full
   HTTP context.
6. On ALLOW: forward to upstream, copy response back to client, in both
   directions, until the connection closes.
7. On BLOCK: return an HTTP `403 Forbidden` over the established TLS
   session (NOT a TLS alert), with `X-Outcall-Block-Reason` populated.

S011-FR-006 [P2] Leaf certificates **MUST** be cached in-process keyed by
hostname. The cache **MUST** be a bounded LRU of size
`INTERCEPT_LEAF_CACHE_MAX` (default 1024). The cache **MUST** evict the
oldest entry when full.

S011-FR-021 [P2] Leaf certificates **MUST** carry a configurable validity
window, defaulting to `INTERCEPT_LEAF_TTL_SECS_DEFAULT` (24 hours). Expired
entries **MUST** be regenerated on next use.

## TLS implementation

S011-FR-007 [P2] The client-side handshake (proxy ↔ agent) **MUST** use
`rustls`. The proxy **MUST** advertise `h2` and `http/1.1` in ALPN.

S011-FR-008 [P2] The upstream handshake (proxy ↔ origin) **MUST** use
`rustls`. The proxy **MUST** verify the upstream certificate against the
system trust store. The proxy **MUST NOT** disable certificate verification
for upstream.

S011-FR-009 [P2] The proxy **MUST** negotiate the same ALPN protocol with
the upstream as it negotiated with the client. If the client wants `h2` and
the upstream offers only `http/1.1` (or vice versa), the proxy **MUST**
fail closed and return `502` to the client.

## Decrypted request handling

S011-FR-010 [P2] HTTP/1.1 requests on the decrypted side **MUST** be
parsed using `hyper`. Headers, method, path, and the optional body **MUST**
be reflected in the rule engine's CEL context.

S011-FR-011 [P2] HTTP/2 requests on the decrypted side **MUST** be
parsed using `hyper`'s HTTP/2 server. Each stream **MUST** be evaluated
independently; a BLOCK on one stream **MUST NOT** affect other streams on
the same connection.

S011-FR-012 [P2] The CEL context for an intercepted request **MUST**
include: `http.method` (uppercase verb), `http.path` (path + query),
`http.host` (Host header / `:authority`), `http.scheme` ("https"),
`http.headers.<name>` (lower-cased), `http.body_size` (bytes).

S011-FR-013 [P3] When `egress.match_body: true` and `http.body_size <=
INTERCEPT_BODY_CAP_BYTES`, the proxy **MUST** buffer the body and expose
it as `http.body` (UTF-8 string; non-UTF-8 bytes replace with U+FFFD).

S011-FR-014 [P2] When the body exceeds `INTERCEPT_BODY_CAP_BYTES`, the
proxy **MUST NOT** buffer further bytes. It **MUST** stream the body
through to upstream after evaluation completes against `http.body == null`,
and emit a structured warning log identifying the rule.

## Verdict response

S011-FR-015 [P2] A BLOCK verdict on an intercepted request **MUST** result
in a synthetic `403 Forbidden` HTTP response over the same TLS session,
with body `Blocked by outcall: <reason>` and headers:

```
Content-Type: text/plain
Content-Length: <n>
X-Outcall-Block-Reason: <rule-id-or-default>
Connection: close
```

S011-FR-016 [P2] An ALLOW verdict **MUST** forward the request verbatim
to upstream, including all headers (subject to S006-FR-020 hop-by-hop
stripping), and stream the response back to the client.

## Failure handling

S011-FR-017 [P2] Any failure in the interception chain — leaf cert
generation, client handshake, upstream handshake, ALPN mismatch, body
buffering — **MUST** result in fail-closed behaviour: the request is
dropped, the client receives an appropriate error (`502` for upstream
failure, TLS alert for client-side handshake failure), and the failure
**MUST** be logged with the rule ID and a stable reason code.

## Operator surfaces

S011-FR-018 [P2] The `outcall ca bundle` CLI command **MUST** print the
loaded CA certificate to stdout in PEM format, suitable for piping into a
container's trust store. If no CA is loaded, the command **MUST** exit with
code 6 (resource not found) and a stderr message.

S011-FR-019 [P2] Every intercepted request **MUST** produce a structured
log entry containing: `subsystem: "proxy_intercept"`, the matched rule ID,
the verdict, the host, the method (decrypted), the path (decrypted), and
the body size. Body content **MUST NOT** be logged.
