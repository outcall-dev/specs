# S012: Test Coverage

| Field | Value |
|-------|-------|
| Spec | S012 |
| Feature | Test coverage targets and integration test inventory |
| Date | 2026-05-05 |
| Status | Draft |
| Author | @marktopper |

## Overview

This is a working spec, not a feature. It catalogues the current state of
Outcall's automated tests, names the gaps, and sets pragmatic coverage
targets per crate / module. New work that adds a subsystem **MUST** also
add the integration test file named in the requirements below.

The motivation: Outcall enforces a security boundary. A subsystem that
has no integration test on the wire is a subsystem we cannot honestly
say works. Code coverage by itself is a weak proxy — what matters is
that every layer (bridge, DNS, proxy, agent API, dynamic rules) has at
least one integration test that exercises the public seam.

## Current state (verified by grep, 2026-05-05)

```
69 unit tests across the workspace, 1 integration test.

outcalld/src/rules/engine.rs        16    rule eval, reload, dynamic merge
outcalld/src/proxy/mod.rs           12    SNI extract, parsers, CRLF
outcalld/src/network/mod.rs         11    subnet allocation
outcalld/src/agent_api/mod.rs        7    permission-check protocol
outcalld/src/docker/mod.rs           7    docker network paths
outcalld/src/dynamic/mod.rs          5    dynamic rule merge
outcall-agent/src/main.rs            4    tool-call invocation parsing
outcalld/src/dns/mod.rs              3    happy path + cache
outcall-ui/src/lib.rs                2    UI types
outcalld/src/rules/model.rs          1    YAML deserialization
outcalld/tests/bridge_integration.rs 1    bridge create + destroy (Linux+root)

outcall-api      0 unit tests, 0 integration tests
outcall (CLI)    0 unit tests, 0 integration tests
```

The CLI binary and the shared types crate have **zero** tests today.

## User Scenarios

S012-US-001 [P2] As a contributor, I want a clear coverage target per
module so that I know when a PR has "enough" tests.

S012-US-002 [P2] As a maintainer, I want CI to fail when coverage drops
below the configured threshold for a given module, so that test debt
does not accumulate silently.

S012-US-003 [P2] As a security reviewer, I want every subsystem with
external trust boundaries (proxy, DNS, agent API, rule engine) to have
at least one integration test exercising the wire format, so that I can
trust the layer holds at runtime.

S012-US-004 [P3] As a contributor, I want to extract code coverage to
a standard format (lcov) so that we can publish reports or wire them
into a coverage service.

## Requirements Summary

| ID | Type | Priority | Title | Status |
|----|------|----------|-------|--------|
| S012-FR-001 | Functional | P2 | `cargo llvm-cov` produces a workspace report | Draft |
| S012-FR-002 | Functional | P2 | Workspace coverage targets enforced in CI | Draft |
| S012-FR-003 | Functional | P2 | Per-crate / per-module thresholds | Draft |
| S012-FR-004 | Functional | P2 | Coverage badge in repo README | Draft |
| S012-FR-005 | Functional | P2 | Add `outcall-api` unit tests | Draft |
| S012-FR-006 | Functional | P2 | Add CLI unit tests for clap parsing | Draft |
| S012-FR-007 | Functional | P2 | Add CLI integration tests over Unix socket | Draft |
| S012-FR-008 | Functional | P2 | DNS filter: NXDOMAIN, SERVFAIL, cache TTL, record-type tests | Draft |
| S012-FR-009 | Functional | P2 | Proxy integration test: HTTP and HTTPS happy paths | Draft |
| S012-FR-010 | Functional | P2 | Proxy integration test: BLOCK at every layer | Draft |
| S012-FR-011 | Functional | P2 | Agent API integration test: rule submission round-trip | Draft |
| S012-FR-012 | Functional | P2 | Dynamic rules integration test: insert + flush | Draft |
| S012-FR-013 | Functional | P2 | TLS interception integration test (S011-AS-001..010) | Draft |
| S012-FR-014 | Functional | P2 | Logging shape test (no secrets, structured fields) | Draft |
| S012-FR-015 | Functional | P3 | Property-based tests for CEL conditions | Draft |
| S012-FR-016 | Functional | P3 | Fuzz harness for proxy parsers (HTTP request line, SNI) | Draft |
| S012-FR-017 | Functional | P2 | Coverage report uploaded as a CI artifact | Draft |

## Coverage targets

| Surface | Target line coverage | Rationale |
|---|---|---|
| `outcall-api` | ≥ 90 % | Pure types and constants. |
| `outcalld/rules/engine.rs` | ≥ 85 % | Rule engine is the policy plane. |
| `outcalld/rules/model.rs` | ≥ 90 % | Pure deserialization. |
| `outcalld/proxy/` parsers | ≥ 85 % | `parse_request_line_headers`, `parse_host_port`, `extract_sni`, `find_double_crlf`. |
| `outcalld/proxy/` IO loops (`handle_connect`, `handle_http`) | covered via integration | Hard to unit-test. |
| `outcalld/network/` | ≥ 70 % unit + 1 integration | Subnet allocator pure-tested; create/destroy via integration. |
| `outcalld/dns/` | ≥ 70 % unit + 1 integration | Filter logic unit-tested; UDP plumbing via integration. |
| `outcalld/dynamic/` | ≥ 80 % unit + 1 integration | Merge logic is pure. |
| `outcalld/agent_api/` | ≥ 70 % unit + 1 integration | Permission check + rule submission. |
| `outcalld/docker/` | ≥ 60 % unit + 1 integration | Mostly bollard wrappers; integration test against a real Docker. |
| `outcall` CLI | ≥ 60 % | clap parsing + output formatting. |
| `outcall-agent` shim | ≥ 70 % | Tool-call parsing + verdict handling. |

These are floors, not ceilings. Anything below the floor for the
relevant subsystem fails CI.

## Required integration test files

S012-FR-007.a `outcalld/tests/cli_integration.rs` — spawns `outcalld` on
an ephemeral socket, then runs the `outcall` binary against it. Asserts
on exit codes and stdout for every subcommand group.

S012-FR-008.a `outcalld/tests/dns_filter_integration.rs` — binds the DNS
filter to an ephemeral UDP port, sends queries via `hickory-resolver`,
asserts NXDOMAIN for blocked, NoError for allowed, and that the cache
respects TTL.

S012-FR-009.a `outcalld/tests/proxy_http_integration.rs` — local HTTP
echo server on a random port; agent makes plain HTTP calls; asserts
ALLOW forwards and BLOCK returns 403.

S012-FR-009.b `outcalld/tests/proxy_https_integration.rs` — same but
HTTPS via CONNECT, asserts SNI-based ALLOW/BLOCK without decryption.

S012-FR-013.a `outcalld/tests/intercept_e2e.rs` — exercises S011's
acceptance scenarios end-to-end with a generated CA and a local TLS
echo server.

S012-FR-013.b `outcalld/tests/intercept_logging.rs` — asserts no
sensitive data leaks into structured logs (Authorization headers,
Bearer tokens, cookie values, body content).

S012-FR-013.c `outcalld/tests/mixed_modes_e2e.rs` — single daemon
serving `proxy`, `direct_ip`, and `intercept` rules from one rule set;
each behaves per its respective spec.

S012-FR-011.a `outcalld/tests/agent_api_integration.rs` — agent shim
asks for a verdict over the agent socket; daemon evaluates against the
loaded rule set; verdict round-trips correctly.

S012-FR-012.a `outcalld/tests/dynamic_rules_integration.rs` — submit a
dynamic rule via the agent API, verify it merges into the active set,
flush, verify it disappears.

## CI gating

S012-FR-002 [P2] Add a `coverage` job to `.github/workflows/ci.yml`:

```yaml
coverage:
  name: cargo llvm-cov
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    - uses: dtolnay/rust-toolchain@stable
      with: { components: llvm-tools-preview }
    - uses: taiki-e/install-action@cargo-llvm-cov
    - run: cargo llvm-cov --workspace --all-targets --lcov --output-path lcov.info
    - run: cargo llvm-cov report --fail-under-lines 70
    - uses: actions/upload-artifact@v4
      with: { name: coverage, path: lcov.info }
```

Once the per-module thresholds in the table above are met, switch
`--fail-under-lines 70` to per-package gates via the `--package` flag.

## Out of Scope

- A test for every line of code. Coverage is a tool, not a goal.
- Mocking syscalls, Docker, or netlink. We prefer real integration
  tests with the real binaries against a real kernel where possible.
- Mutation testing. Worth considering later; not v1.
- Performance benchmarks. Belongs in a separate spec.

## Cross-Spec Dependencies

- **Required by:** all subsystem specs (S001–S011) — every spec's
  acceptance scenarios should map to one or more tests under this
  inventory.
- **Depends on:** [S000](../000-workspace/index.md) (workspace structure
  determines the test crate layout).
