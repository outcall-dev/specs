# S011 — Interface Requirements

## Daemon flags

S011-IF-001 [P2] `--ca-cert <path>` — PEM file containing the root CA
certificate. Optional. Required for any rule that opts into interception.

S011-IF-002 [P2] `--ca-key <path>` — PEM file containing the root CA
private key. Optional. Required when `--ca-cert` is set. The daemon
**MUST** refuse to start if the key file is world-readable
(permissions broader than `0600`).

S011-IF-003 [P2] `--intercept-leaf-ttl-secs <n>` — Validity window for
generated leaf certs, in seconds. Default 86400 (24h). Range: 60 to
604800 (1 minute to 7 days).

S011-IF-004 [P2] `--intercept-body-cap-bytes <n>` — Maximum bytes the
proxy will buffer for `http.body` matching. Default 1048576 (1 MiB).
Range: 0 (disabled) to 16777216 (16 MiB).

## Rule YAML schema

S011-IF-005 [P2] `egress.mode: intercept` — opt-in interception for the
rule. The proxy will terminate TLS for traffic that matches this rule's
condition on its CONNECT hostname / SNI.

S011-IF-006 [P3] `egress.match_body: true|false` — when true, the proxy
buffers the request body up to the cap and exposes it as `http.body` to
the rule engine. Defaults to false. Has no effect unless `mode: intercept`.

Example combining both flags:

```yaml
version: "1"
rules:
  - id: anthropic-messages-no-system
    description: "POST /v1/messages, but reject prompts that try to override the system role"
    condition: |
      http.host == "api.anthropic.com" &&
      http.method == "POST" &&
      http.path.startsWith("/v1/messages") &&
      !http.body.contains('"role":"system"')
    action: allow
    egress:
      mode: intercept
      match_body: true
```

## CLI commands

S011-IF-007 [P2] `outcall ca init [--out <dir>] [--algorithm rsa|ecdsa]`

Generates a new CA. Default output directory is the current working
directory. Default algorithm is `rsa` (4096 bits). Writes `ca.crt`
(0644) and `ca.key` (0600). Prints the SHA-256 fingerprint of the cert
to stdout. Refuses to overwrite existing files.

S011-IF-008 [P2] `outcall ca bundle`

Prints the loaded CA certificate (PEM) to stdout. Exit code 0 on success,
6 if no CA is loaded. Useful for distributing the trust anchor:

```sh
outcall ca bundle | docker exec -i my-agent \
    tee /usr/local/share/ca-certificates/outcall.crt
docker exec my-agent update-ca-certificates
```

S011-IF-009 [P2] `outcall ca status`

Prints a human-readable summary of the loaded CA: subject, fingerprint,
validity period, and number of leaf certs in the cache. Exit code 0 if a
CA is loaded, 6 otherwise.

`--json` outputs:

```json
{
  "loaded": true,
  "subject": "CN=outcall.local",
  "fingerprint_sha256": "ab:cd:…",
  "not_before": "2026-05-05T00:00:00Z",
  "not_after": "2036-05-05T00:00:00Z",
  "leaf_cache_size": 17,
  "leaf_cache_max": 1024
}
```

## CEL context (intercepted requests)

S011-IF-010 [P2] On an intercepted request, the rule engine context
includes:

| Field | Type | Notes |
|---|---|---|
| `http.host` | string | Host header or HTTP/2 `:authority` |
| `http.method` | string | Uppercased verb |
| `http.path` | string | Path + query string |
| `http.scheme` | string | Always `"https"` |
| `http.headers.<name>` | string | Per-header; names lower-cased |
| `http.body_size` | int | Bytes (request body) |
| `http.body` | string | See IF-011 |

S011-IF-011 [P3] `http.body` — populated only when **all** of:
1. The matching rule has `egress.match_body: true`.
2. The body size is `<=` `--intercept-body-cap-bytes`.
3. The body parses as valid UTF-8 (or after lossy replacement).

Otherwise `http.body` is `null`. Rules using `http.body` should test
nullness explicitly (`http.body != null && http.body.contains("…")`).

## Host API endpoints

S011-IF-012 [P2] `GET /api/v1/proxy/intercept` — returns `InterceptStatus`:

```json
{
  "ca_loaded": true,
  "leaf_cache_size": 17,
  "leaf_cache_max": 1024,
  "intercepted_today": 4203,
  "blocked_today": 18
}
```

S011-IF-013 [P2] `POST /api/v1/proxy/intercept/cache/flush` — drops every
cached leaf cert. Useful when rotating the CA. Returns count of evicted
entries.

## Error contract

S011-IF-014 [P2] On an intercepted request that produces a verdict of
BLOCK, the agent receives:

```
HTTP/1.1 403 Forbidden
Content-Type: text/plain
Content-Length: <n>
X-Outcall-Block-Reason: <rule-id>

Blocked by outcall: <rule-id>
```

S011-IF-015 [P2] On any interception failure (cert generation, ALPN
mismatch, upstream handshake), the agent receives:

```
HTTP/1.1 502 Bad Gateway
Content-Type: text/plain
Content-Length: <n>
X-Outcall-Failure-Reason: <stable-code>

Outcall could not complete the request: <human reason>
```

Stable reason codes: `cert_gen_failed`, `client_handshake_failed`,
`upstream_handshake_failed`, `alpn_mismatch`, `body_decode_failed`.
