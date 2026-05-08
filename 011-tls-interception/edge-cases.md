# S011 — Edge Cases

## S011-EC-001 [P2] Upstream pins certificates (HSTS / HPKP / app pinning)

Many SaaS providers pin certificates at the application layer. When the
proxy presents its CA-signed leaf, the agent's TLS library accepts it (the
CA is in the trust store), but the application or the OS HSTS preload may
reject the chain anyway.

**Behaviour:** the proxy has no signal that this happened — the failure
is in the agent's process, not at the proxy. The proxy treats the
connection as a normal TLS session that the client closed early.

**Operator UX:** document the symptom (intermittent connection resets to
specific hosts) and recommend `mode: proxy` (no interception) for pinned
hosts. A future feature **MAY** add a known-pinned-hosts allowlist that
forces those hosts back to S006 even if a matching `mode: intercept` rule
exists.

## S011-EC-002 [P2] ALPN mismatch

The agent advertises `h2` in its ClientHello; the upstream offers only
`http/1.1`, or vice versa.

**Behaviour:** fail closed. The proxy returns `502` to the client with
`X-Outcall-Failure-Reason: alpn_mismatch`. A retry handshake on the
client's side may succeed at HTTP/1.1 if the client falls back.

## S011-EC-003 [P2] Agent does not trust the CA

Container started without the CA installed in its trust store.

**Behaviour:** the agent's TLS library rejects the leaf cert during the
client handshake. The proxy sees the handshake fail and emits
`client_handshake_failed reason=untrusted_ca` in logs. The agent's process
sees an SSL verification error appropriate to its language.

## S011-EC-004 [P2] CA key on disk is unreadable

`--ca-key` is set but the file does not exist or is not readable by the
daemon's user.

**Behaviour:** the daemon exits non-zero on startup with a clear stderr
message (`cannot read CA key: <path>: <errno>`). Interception is never
enabled. Existing rules with `mode: intercept` would have already failed
validation in `rules reload`, so this case shouldn't bring down a running
daemon — but it does prevent startup.

## S011-EC-005 [P2] Body exceeds buffer cap

`egress.match_body: true` is set but the request body exceeds
`--intercept-body-cap-bytes`.

**Behaviour:** the proxy stops buffering at the cap, evaluates the rule
with `http.body == null`, and continues to stream the request to upstream
on ALLOW. A structured warning log identifies the rule and the body size.
The agent receives the upstream response unchanged.

## S011-EC-006 [P3] Streaming response (chunked / SSE)

Upstream responds with `Transfer-Encoding: chunked` or
`text/event-stream`.

**Behaviour:** the proxy streams chunks to the client without buffering.
Response body is **not** matched against rules in v1 (rules see only
request body). Connection lifetime is controlled by the slower of the two
sides.

## S011-EC-007 [P3] WebSocket upgrade over intercepted TLS

The agent issues `GET wss://...` with `Upgrade: websocket`.

**Behaviour:** the proxy evaluates the upgrade request normally (method,
path, headers including `Sec-WebSocket-Protocol`). On ALLOW, the proxy
opens an upstream WebSocket and bridges frames in both directions. Frame
contents are not inspected. On BLOCK, the upgrade returns 403, the
WebSocket never opens.

## S011-EC-008 [P2] Cache eviction during in-flight handshake

Two requests arrive simultaneously; the leaf cache is full; the existing
entry is evicted to make room while the second handshake is using it.

**Behaviour:** generated leaves are reference-counted; eviction from the
cache only removes the lookup entry. Active handshakes hold their cert
until the handshake completes. New requests after eviction generate a
fresh leaf.

## S011-EC-009 [P2] Client uses TLS 1.2 only

Some agents (older Python builds, Java 8) negotiate TLS 1.2 only.

**Behaviour:** the proxy supports both TLS 1.2 and 1.3 on the client side.
ALPN works identically. No special handling required.

## S011-EC-010 [P3] mTLS (client certificate) request

Upstream requires a client certificate. The agent has it; the proxy does
not.

**Behaviour:** in v1, the proxy fails the upstream handshake and returns
`502` with `X-Outcall-Failure-Reason: upstream_handshake_failed`. mTLS
bridging requires forwarding the client's certificate decision through
the proxy, which is out of scope for this spec.

**Operator UX:** document that mTLS-protected hosts must use `mode: proxy`
(no interception), where the original tunnel is preserved end-to-end.

## S011-EC-011 [P2] Daemon shutdown with active intercepted tunnels

A `SIGTERM` arrives while N intercepted tunnels are open.

**Behaviour:** the proxy stops accepting new connections immediately. In-
flight tunnels enter a drain phase with a configurable grace (default 30s).
After grace, remaining tunnels are forcibly closed (RST to client and
upstream). All cached leaves are dropped from memory; the CA private key
is zeroed before unmap.

## S011-EC-012 [P3] HTTP/3 / QUIC

QUIC runs over UDP. The proxy never sees it.

**Behaviour:** out of scope. The DNS filter (S007) blocks resolution for
non-allow-listed hosts; the bridge nftables ruleset blocks UDP egress
that doesn't match a `direct_ip` rule. So a misbehaving HTTP/3 client
either falls back to TCP/TLS (intercepted) or fails at L3.
