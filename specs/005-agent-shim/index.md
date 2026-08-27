# S005: Agent Shim

| Field | Value |
|-------|-------|
| Spec | S005 |
| Feature | Agent Shim |
| Date | 2026-04-21 |
| Status | Implemented |
| Author | @marktopper |

## Overview

`outcall-agent` is an opt-in command mediation shim for managed containers. When
helper mounts are enabled, `outcalld` bind-mounts the binary read-only at
`/usr/local/bin/outcall` and exposes only the agent API socket at
`/run/outcall/agent.sock`.

The shim mediates commands explicitly invoked through it:

```text
outcall exec git status
outcall bash make test
outcall git status
```

It is not transparent syscall interception and it does not wrap an arbitrary
agent process automatically. `fetch` and `file` forms perform policy checks but
do not execute network or file operations. Actual recipe egress is enforced by
the managed bridge, DNS service, HTTP proxy, and nftables policy described in
[S015](../015-security-boundary/index.md). Files already mounted into a container
are container-visible files; undeclared host resources remain absent.

The built-in Claude and Codex recipes currently disable helper mounts because
their primary boundary is the hardened container and enforced network path.
They can still use the separately tokenized, rule-gated host resource broker.

For an explicit invocation, the shim checks in, receives a session token,
requests a verdict, executes an allowed command, and maintains a heartbeat while
the child runs. The daemon derives container identity from Unix peer credentials;
the shim does not submit a caller-controlled hostname or PID. Daemon loss kills
the active child and exits with code 5.

## Requirements Summary

| ID | Priority | Title | Status |
|----|----------|-------|--------|
| S005-FR-001 | P1 | Agent socket constant | Implemented |
| S005-FR-002 | P1 | Reachability check before mediated actions | Implemented |
| S005-FR-003 | P1 | Check-in and daemon-derived identity | Implemented |
| S005-FR-004 | P1 | Fail-closed startup | Implemented |
| S005-FR-005 | P1 | Agent-socket-only communication | Implemented |
| S005-FR-006 | P1 | Static binary and optional read-only mount | Implemented |
| S005-FR-007 | P1 | Explicit command mediation | Implemented |
| S005-FR-008 | P1 | Execute allowed command | Implemented |
| S005-FR-009 | P1 | Refuse blocked command | Implemented |
| S005-FR-010 | P1 | Network and file permission probes | Implemented |
| S005-FR-011 | P1 | Malformed response fails closed | Implemented |
| S005-FR-012 | P1 | Mid-action daemon loss | Implemented |
| S005-FR-013 | P1 | Request timeout | Implemented |
| S005-FR-014 | P2 | Bounded configurable timeout | Implemented |
| S005-FR-015 | P1 | Exit code semantics | Implemented |
| S005-FR-016 | P1 | Diagnostics on stderr | Implemented |
| S005-FR-017 | P1 | No socket log pollution | Implemented |
| S005-FR-018 | P2 | Structured tracing | Implemented |
| S005-FR-019 | P1 | Heartbeat loop | Implemented |
| S005-FR-020 | P1 | Graceful SIGTERM | Implemented |
| S005-FR-021 | P2 | Trusted identity returned by check-in | Implemented |
| S005-FR-022 | P1 | Denial reason and verdict diagnostics | Implemented |
| S005-AS-001 | P1 | Check-in happy path | Implemented |
| S005-AS-002 | P1 | Socket missing | Implemented |
| S005-AS-003 | P1 | Command allowed | Implemented |
| S005-AS-004 | P1 | Command blocked | Implemented |
| S005-AS-005 | P1 | Network probe | Implemented |
| S005-AS-006 | P1 | File probe | Implemented |
| S005-AS-007 | P1 | Daemon loss during child | Implemented |
| S005-AS-008 | P1 | Request timeout | Implemented |
| S005-AS-009 | P2 | Graceful SIGTERM | Implemented |
| S005-AS-010 | P1 | Optional mount immutability | Implemented |
| S005-EC-001 | P1 | Agent socket absent at startup | Implemented |
| S005-EC-002 | P1 | Agent socket disappears mid-action | Implemented |
| S005-EC-003 | P1 | Daemon stalls during check | Implemented |
| S005-EC-004 | P1 | Invalid timeout configuration | Implemented |
| S005-EC-005 | P1 | Malformed or oversized response | Implemented |
| S005-EC-006 | P2 | Concurrent shim processes | Implemented |
| S005-EC-007 | P1 | Unmanaged check-in peer | Implemented |
| S005-EC-008 | P1 | Socket path has no listener | Implemented |
| S005-EC-009 | P1 | Helper mount overwrite | Implemented |
| S005-EC-010 | P2 | Allowed probe remains non-executing | Implemented |
| S005-EC-011 | P1 | Child exits nonzero | Implemented |
| S005-EC-012 | P1 | SIGTERM while verdict pending | Implemented |
| S005-SC-001 | P1 | Session-bound mediated invocation | Implemented |
| S005-SC-002 | P1 | Exact command allow and deny | Implemented |
| S005-SC-003 | P2 | Non-executing network and file probes | Implemented |
| S005-SC-004 | P1 | Daemon loss kills and reaps child | Implemented |
| S005-SC-005 | P1 | Invalid API response fails closed | Implemented |
| S005-SC-006 | P1 | Stable exit code semantics | Implemented |
| S005-SC-007 | P2 | Bounded stderr diagnostics | Implemented |
| S005-SC-008 | P1 | Read-only optional helper mounts | Implemented |
| S005-SC-009 | P1 | Outer boundary secures built-in recipes | Implemented |

## Out of Scope

- Transparent syscall, shell, file, or network interception
- Network packet enforcement, which belongs to S006, S007, and S015
- Host API access, rule authoring, or container lifecycle management
- Supervising commands that were not explicitly launched through the shim

## Cross-Spec Dependencies

- **Depends on:** [S004](../004-agent-api/index.md) for check-in and verdicts
- **Depends on:** [S003](../003-rule-engine/index.md) for policy evaluation
- **Complements:** [S015](../015-security-boundary/index.md), the mandatory outer boundary
