# Outcall Specifications

## Spec Index

| Spec | Feature | Status | Depends on |
|------|---------|--------|------------|
| [S000](000-workspace/index.md) | Workspace & Shared Types | Implemented | — |
| [S001](001-bridge-management/index.md) | Bridge Management | Implemented | S000 |
| [S002](002-network-management/index.md) | Network Management | Draft | S001 |
| [S003](003-rule-engine/index.md) | Rule Engine | Draft | S001, S002 |
| [S004](004-agent-api/index.md) | Agent API | Draft | S003 |
| [S005](005-agent-shim/index.md) | Agent Shim | Draft | S003, S004 |
| [S006](006-http-proxy/index.md) | HTTP Proxy | Draft | S002, S003 |
| [S007](007-dns-filter/index.md) | DNS Filter | Draft | S001, S003 |
| [S008](008-docker-manager/index.md) | Docker Manager | Draft | S001-S007 |
| [S009](009-dynamic-rules/index.md) | Dynamic Rules | Draft | S001, S003 |
| [S010](010-dashboard/index.md) | Dashboard | Draft | S001-S009 |

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
