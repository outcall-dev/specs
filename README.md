# Outcall Specifications

![Outcall Banner](https://raw.githubusercontent.com/outcall-dev/assets/main/banner.png)

## Badges

[![Version](https://img.shields.io/badge/version-0.1.8-blue.svg)](https://github.com/outcall-dev/specs/releases)

## Spec Index

> **Note on row-level status.** The header `Status` column below is canonical
> per-spec. Inside each spec's `index.md`, the per-requirement table (rows like
> `S006-FR-001 | … | Draft`) has *not* been refreshed since initial drafting —
> most rows still read `Draft` even where the feature is in production. S000,
> S001, and S013 are up to date; the rest will be reconciled in a sweep that
> walks the code and updates row statuses individually. For now, trust the
> spec-header `Status` and the `## Implementation note` blocks at the bottom
> of each spec.

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

`outcalld` initializes subsystems in dependency order. Each subsystem waits
for its prerequisites before starting. Failure at any P1 step aborts startup.

```
1. Bridge (S001)          — create/attach bridge, apply nftables base rules
   ↓
2. Rule Engine (S003)     — load YAML rule files, validate CEL expressions
   ↓
3. Network (S002)         — create default Docker network, assign bridge gateway IP
   ↓ (parallel)
4a. DNS Filter (S007)     — bind DNS server to bridge gateway IP (from S002)
4b. HTTP Proxy (S006)     — bind proxy to bridge gateway IP (from S002)
   ↓
5. Docker Manager (S008)  — initialize Docker client, ready to create containers
   ↓
6. Host API               — bind unix socket, start serving
   ↓
7. Agent API (S004)       — bind agent socket, ready for agent check-ins
```

### Shutdown sequence (reverse order)

```
7. Agent API              — stop accepting new requests, drain in-flight
6. Host API               — stop accepting new requests
5. Docker Manager         — (containers are NOT stopped — they outlive the daemon)
4. DNS/Proxy              — stop listeners
3. Network                — (networks are NOT removed — they outlive the daemon)
2. Rule Engine            — (no cleanup needed)
1. Bridge (S001)          — flush nftables table, delete bridge interface
```

Note: networks and containers intentionally outlive the daemon (S002-EC-010).
The bridge and nftables rules are torn down so that traffic is no longer
filtered — containers lose connectivity until the daemon restarts.

## Design Principles

1. **Default BLOCK** — no rule match means denied. Every subsystem enforces this independently.
2. **Fail closed** — if any subsystem is unavailable, the answer is BLOCK/deny/SERVFAIL/exit-5.
3. **Host-only management** — bridge, network, rule, and container management happens on `host.sock` only.
4. **Agent isolation** — containers see only `agent.sock`. No access to host API, bridge, or nftables.
5. **Single binary** — everything runs as Tokio tasks in `outcalld`. No separate processes.
