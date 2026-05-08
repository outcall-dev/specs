# S011 — Acceptance Scenarios

All scenarios assume a running `outcalld` reachable at the default socket
and an agent container connected to an outcall network. Where a scenario
involves interception, the daemon is started with `--ca-cert` and
`--ca-key` and the container has the CA installed in its trust store.

## S011-AS-001 [P2] Method-scoped HTTPS rule allows POST and blocks GET

**Given** a rule:

```yaml
- id: anthropic-post-only
  condition: http.host == "api.anthropic.com" && http.method == "POST"
  action: allow
  egress: { mode: intercept }
```

**When** the agent issues `POST https://api.anthropic.com/v1/messages`
**Then** the proxy returns the upstream response unchanged (e.g. 401 if
auth is missing — the upstream sees the call).

**When** the agent issues `GET https://api.anthropic.com/v1/messages`
**Then** the proxy returns 403 with `X-Outcall-Block-Reason:
anthropic-post-only` (or `default policy` if no other rule matches).

## S011-AS-002 [P2] Path-scoped HTTPS rule allows /v1/x and blocks /v1/y

**Given** a rule allowing only `path.startsWith("/v1/messages")` for
`api.anthropic.com` with `egress.mode: intercept`.

**When** the agent calls `POST https://api.anthropic.com/v1/messages`
**Then** the proxy forwards the request and the agent gets the upstream
response.

**When** the agent calls `POST https://api.anthropic.com/v1/files`
**Then** the proxy returns 403, never opens an upstream connection for
that request.

## S011-AS-003 [P2] Rule with `mode: intercept` rejected when no CA loaded

**Given** the daemon was started without `--ca-cert` / `--ca-key`.
**When** `outcall rules reload` is invoked with a file containing
`egress.mode: intercept`,
**Then** the reload exits non-zero, prints the offending file and rule
ID, and the previous rule set remains active. `outcall rules list` still
shows the old set.

## S011-AS-004 [P2] Daemon starts without `--ca-cert` (interception disabled)

**Given** no CA flags.
**When** `outcalld` starts and a rule set with no `mode: intercept`
entries is loaded,
**Then** the daemon comes up healthy. `outcall ca status` exits 6 with
`{"loaded": false}` (JSON mode) or `no CA loaded` (text). Existing S006
behaviour is unchanged.

## S011-AS-005 [P2] Pinned upstream returns clear error to agent

**Given** an intercept rule allowing `accounts.google.com` (a host that
pins certificates).
**When** the agent attempts `GET https://accounts.google.com/`,
**Then** the agent's TLS client rejects the proxy's leaf cert and surfaces
a TLS handshake error. The proxy logs `subsystem=proxy_intercept
event=client_handshake_failed reason=cert_pin host=accounts.google.com`,
allowing the operator to add the host to a non-intercept rule.

## S011-AS-006 [P2] Leaf cert cached across requests to same host

**Given** an intercept rule covering `api.openai.com`.
**When** the agent makes 100 sequential requests,
**Then** `outcall ca status --json` shows `leaf_cache_size: 1` for that
host (one leaf cert generated, reused). Cache TTL not exceeded during the
test.

## S011-AS-007 [P3] Body matcher allows JSON-payload rule

**Given** a rule with `match_body: true`:

```yaml
- id: anthropic-no-system-override
  condition: |
    http.host == "api.anthropic.com" &&
    http.method == "POST" &&
    http.body != null &&
    !http.body.contains('"role":"system"')
  action: allow
  egress: { mode: intercept, match_body: true }
```

**When** the agent POSTs a body without `"role":"system"`,
**Then** the request is forwarded.

**When** the agent POSTs a body containing `"role":"system"`,
**Then** the proxy returns 403.

## S011-AS-008 [P2] Non-intercept rule on same daemon unchanged

**Given** the daemon has a CA loaded, and the rule set contains both an
intercept rule for `api.anthropic.com` and a plain `mode: proxy` rule
for `github.com`.

**When** the agent calls `https://github.com/some/repo.git`,
**Then** the proxy uses the S006 path: SNI peek, no decryption, no leaf
cert generated. `outcall ca status --json` shows no `github.com` entry
in the leaf cache.

## S011-AS-009 [P2] `outcall ca init` produces 4096-bit RSA CA valid 10 years

**When** `outcall ca init --out /tmp/test-ca`,
**Then** `/tmp/test-ca/ca.crt` and `/tmp/test-ca/ca.key` exist with
permissions `0644` and `0600`. `openssl x509 -in /tmp/test-ca/ca.crt
-noout -text` shows a self-signed CA with 4096-bit RSA, validity 10
years, BasicConstraints `CA:TRUE`. The command prints the SHA-256
fingerprint to stdout.

## S011-AS-010 [P2] `outcall ca bundle` emits PEM to stdout

**Given** the daemon was started with `--ca-cert /etc/outcall/ca/ca.crt`.
**When** `outcall ca bundle` is invoked,
**Then** stdout begins with `-----BEGIN CERTIFICATE-----` and ends with
`-----END CERTIFICATE-----`, exit code 0. The output **MUST** be byte-equal
to the file at `--ca-cert`.

## S011-AS-011 [P2] Daemon refuses to start with world-readable CA key

**Given** a CA key file with permissions `0644`.
**When** `outcalld --ca-cert ./ca.crt --ca-key ./ca.key` is invoked,
**Then** the daemon exits non-zero with a stderr message naming the file
and required permissions. The proxy never starts.
