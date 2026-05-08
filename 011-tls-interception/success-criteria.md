# S011 — Success Criteria

A reviewer can declare S011 implemented when every criterion below is
verifiable from a clean checkout, with the daemon and CLI built from
`HEAD`.

## S011-SC-001 [P2] Decrypted method/path enforced for HTTPS endpoint

A rule allowing only `POST /v1/messages` on `api.anthropic.com` results
in:
- `POST /v1/messages` → forwarded (status from upstream).
- `GET /v1/messages` → 403 from the proxy with `X-Outcall-Block-Reason`.
- `POST /v1/files` → 403.

Verified by an E2E test in `application/outcalld/tests/intercept_e2e.rs`
against a local httpbin-equivalent.

## S011-SC-002 [P2] Default-off: daemon without CA preserves S006 behaviour

Without `--ca-cert`, `outcalld` starts and behaves byte-identically to
S006 for every existing acceptance scenario in
`specs/006-http-proxy/acceptance-scenarios.md`. Verified by re-running
the S006 test suite with no environment changes.

## S011-SC-003 [P2] Cache prevents re-signing on every request

Two thousand sequential requests to a single intercepted host produce
exactly one leaf certificate generation event in `proxy_intercept` logs
(`event=leaf_generated`).

## S011-SC-004 [P2] Rule validation rejects intercept without CA

`outcall rules reload` exits non-zero, with the offending file path and
rule ID in stderr, when any rule has `mode: intercept` and the daemon
has no CA loaded. The previous rule set is still active afterward.

## S011-SC-005 [P2] CA initialisation CLI produces a working CA

`outcall ca init --out /tmp/ca` produces files that, when passed to
`outcalld --ca-cert /tmp/ca/ca.crt --ca-key /tmp/ca/ca.key`, allow a
following intercept rule to function end-to-end. Verified by:
1. `outcall ca init --out /tmp/ca`
2. `outcalld --ca-cert /tmp/ca/ca.crt --ca-key /tmp/ca/ca.key &`
3. Container with `/tmp/ca/ca.crt` mounted into trust store
4. Intercept rule for `api.openai.com`
5. `curl https://api.openai.com/...` returns the upstream response (not a
   TLS error).

## S011-SC-006 [P3] Body matching catches a known payload pattern

A rule with `match_body: true` and a CEL condition referencing
`http.body.contains(...)` produces correct verdicts for matching and
non-matching POST bodies under the configured cap.

## S011-SC-007 [P2] Interception logs include matched rule and outcome

For every intercepted request, exactly one structured log entry exists
with all of: `subsystem=proxy_intercept`, `rule=<id>`, `verdict=allow|block`,
`host=<hostname>`, `method=<verb>`, `path=<path>`, `body_size=<bytes>`.

Logs **MUST NOT** contain request bodies, response bodies, headers other
than the host, or any token-shaped strings (Authorization, Cookie,
Bearer-prefixed values). Verified by a log-shape test in
`outcalld/tests/intercept_logging.rs`.

## S011-SC-008 [P2] Pinned host failure surfaces a clear operator error

When an agent connects to a known-pinned host through an intercept rule,
the operator sees a single log line containing `event=client_handshake_failed
reason=cert_pin host=<host>` (or a generic `untrusted_chain` if pinning
cannot be distinguished from an untrusted CA). The agent's process
receives a TLS error appropriate to its TLS library.

## S011-SC-009 [P2] CA key file permissions are enforced

`outcalld` refuses to start when `--ca-key` points at a file with
permissions broader than `0600`. The error message names the file and
the required permissions. Verified by a unit test in `tests/`.

## S011-SC-010 [P2] No leakage of CA key material in process inspection

After daemon startup, `cat /proc/<pid>/maps` and a heap dump (where
permitted) contain no readable copy of the CA private key in PEM form.
Key material is held in the rustls signing context only and zeroed on
shutdown. Verified by a manual test documented in
`docs/tests/ca-key-handling.md`.

## S011-SC-011 [P2] Mixed rule set: intercept + proxy + direct_ip coexist

A single daemon serves all three modes from one rule file:
- `mode: proxy` for pinned hosts (e.g. Google Auth).
- `mode: intercept` for APIs needing path-level enforcement.
- `mode: direct_ip` for raw-socket workloads.

All three behave according to their respective specs (S006, S011, S009).
Verified by E2E test in `application/outcalld/tests/mixed_modes_e2e.rs`.
