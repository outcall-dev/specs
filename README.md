# Outcall Specifications

![Outcall Banner](https://raw.githubusercontent.com/outcall-dev/assets/main/banner.png)

[![Specs CI](https://github.com/outcall-dev/specs/actions/workflows/ci.yml/badge.svg)](https://github.com/outcall-dev/specs/actions/workflows/ci.yml)

## Spec Index

The per-requirement status tables are authoritative. `Draft` means that the
requirement is not implemented or has not yet been verified by executable
evidence, even when the broader subsystem is available.

| Spec | Feature | Status | Depends on |
|------|---------|--------|------------|
| [S000](specs/000-workspace/index.md) | Workspace & Shared Types | Implemented | — |
| [S001](specs/001-bridge-management/index.md) | Bridge Management | Implemented | S000 |
| [S002](specs/002-network-management/index.md) | Network Management | Implemented | S001 |
| [S003](specs/003-rule-engine/index.md) | Rule Engine | Implemented | S001, S002 |
| [S004](specs/004-agent-api/index.md) | Agent API | Implemented | S003 |
| [S005](specs/005-agent-shim/index.md) | Agent Shim | Implemented | S003, S004 |
| [S006](specs/006-http-proxy/index.md) | HTTP Proxy | Implemented | S002, S003 |
| [S007](specs/007-dns-filter/index.md) | DNS Filter | Implemented | S001, S003 |
| [S008](specs/008-docker-manager/index.md) | Docker Manager | Implemented | S001-S007 |
| [S009](specs/009-dynamic-rules/index.md) | Dynamic Rules | Implemented | S001, S003 |
| [S010](specs/010-dashboard/index.md) | Dashboard | Implemented | S001-S009 |
| [S011](specs/011-tls-interception/index.md) | TLS Interception (optional) | Draft (not implemented in v0.1) | S006 |
| [S012](specs/012-test-coverage/index.md) | Test Coverage | Implemented | All |
| [S013](specs/013-agent-name-context/index.md) | Agent-Name Rule Context | Implemented | S003, S008 |
| [S014](specs/014-agent-boot/index.md) | Agent Boot Command | Implemented | S001, S008 |
| [S015](specs/015-security-boundary/index.md) | Security Boundary | Implemented | S001, S013 |

## Startup Sequence

`outcalld` initializes its security boundary before serving either API. Invalid
rules, socket conflicts, bridge-policy failures, and required DNS/proxy bind
failures abort startup.

```
1. Rule Engine (S003)     — load and validate YAML rules
   ↓
2. API sockets            — bind host and agent Unix sockets without serving
   ↓
3. Bridge (S001)          — create/validate bridge, apply fail-closed base policy
   ↓
4. Docker Manager (S008)  — connect to Docker; degraded mode is allowed
   ↓
5. Dynamic Rules (S009)   — start lifecycle and expiry watchers
   ↓
6. DNS Filter (S007)      — bind the managed resolver
   ↓
7. HTTP Proxy (S006)      — bind unless explicitly disabled
   ↓
8. Network (S002)         — initialize managed network allocation
   ↓
9. Host and Agent APIs    — begin serving the pre-bound sockets
```

### Shutdown Sequence

```
1. Host and Agent APIs    — stop serving requests
2. HTTP Proxy and DNS     — stop and join listener tasks
3. Dynamic Rules (S009)   — stop watchers and flush temporary grants
4. Bridge (S001)          — reapply the fail-closed base policy
5. Background managers    — stop Docker and netlink watcher tasks
6. API sockets            — remove host and agent socket files
```

Networks and containers intentionally outlive the daemon (S002-EC-010). Normal
shutdown preserves the bridge and nftables table, removes dynamic grants, and
leaves managed container egress blocked until the daemon services restart.

## Validation

Validate requirement IDs, status values, duplicate definitions, and index
coverage before committing spec changes:

```sh
scripts/check-spec-indexes.sh
```

## Design Principles

1. **Default BLOCK** — no rule match means denied. Every subsystem enforces this independently.
2. **Fail closed** — if any subsystem is unavailable, the answer is BLOCK/deny/SERVFAIL/exit-5.
3. **Host-only management** — bridge, network, rule, and container management happens on `host.sock` only.
4. **Agent isolation** — containers see only `agent.sock`. No access to host API, bridge, or nftables.
5. **Single daemon process** — daemon subsystems run as owned Tokio tasks in `outcalld`.
