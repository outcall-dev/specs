# S005: Agent Shim

| Field | Value |
|-------|-------|
| Spec | S005 |
| Feature | Agent Shim |
| Date | 2026-04-21 |
| Status | Implemented |
| Author | @marktopper |

## Overview

The agent shim (`outcall-agent`) is a small, statically linked binary that is
bind-mounted read-only into every agent container at `/usr/local/bin/outcall`.
It is the only interface between the agent process running inside the container
and `outcalld`'s agent API socket (`/run/outcall/agent.sock`).

The shim's job is to intercept every action the agent wants to take — tool
invocations, outbound network requests, file operations — submit them to
`outcalld` for policy evaluation, and enforce the verdict. If `outcalld` says
allow, the shim executes the action. If `outcalld` says block, the shim
refuses. If `outcalld` is unreachable at any point, the shim exits immediately
with code 5 (fail closed).

The shim talks **only** to `agent.sock`. It has no access to `host.sock` or
any other `outcalld` surface. The container cannot modify the shim binary
because it is bind-mounted read-only.

```
CONTAINER (agent)
  └── outcall-agent (shim)     — bind-mounted read-only at /usr/local/bin/outcall
      └── talks to agent.sock only — no other outcalld access
```

## User Scenarios

S005-US-001 [P1] As an agent process, I want the shim to verify that outcalld is reachable on startup so that I fail immediately if the security layer is missing.

S005-US-002 [P1] As an agent process, I want to submit tool invocations through the shim so that outcalld can approve or deny them against policy.

S005-US-003 [P1] As an agent process, I want outbound network requests to be checked against policy so that I cannot exfiltrate data to unauthorized destinations.

S005-US-004 [P1] As a host operator, I want the shim to fail closed (exit 5) whenever outcalld is unreachable so that an unmonitored agent cannot run unsupervised.

S005-US-005 [P2] As a host operator, I want the shim to log diagnostic information to stderr so that I can troubleshoot container issues without polluting the agent API channel.

## Requirements Summary

| ID | Type | Priority | Title | Status |
|----|------|----------|-------|--------|
| S005-FR-001 | Functional | P1 | Socket path constant | Draft |
| S005-FR-002 | Functional | P1 | Startup socket check | Draft |
| S005-FR-003 | Functional | P1 | Startup registration | Draft |
| S005-FR-004 | Functional | P1 | Fail-closed exit code | Draft |
| S005-FR-005 | Functional | P1 | Socket-only communication | Draft |
| S005-FR-006 | Functional | P1 | Static binary, read-only mount | Draft |
| S005-FR-007 | Functional | P1 | Tool invocation interception | Draft |
| S005-FR-008 | Functional | P1 | Verdict enforcement (allow) | Draft |
| S005-FR-009 | Functional | P1 | Verdict enforcement (block) | Draft |
| S005-FR-010 | Functional | P1 | Network request gating | Draft |
| S005-FR-011 | Functional | P1 | Default-block on no verdict | Draft |
| S005-FR-012 | Functional | P1 | Mid-session unreachable handling | Draft |
| S005-FR-013 | Functional | P1 | Request timeout | Draft |
| S005-FR-014 | Functional | P2 | Configurable timeout | Draft |
| S005-FR-015 | Functional | P1 | Exit code semantics | Draft |
| S005-FR-016 | Functional | P1 | Logging to stderr | Draft |
| S005-FR-017 | Functional | P1 | No stdout protocol pollution | Draft |
| S005-FR-018 | Functional | P2 | Structured log format | Draft |
| S005-FR-019 | Functional | P1 | Heartbeat loop | Draft |
| S005-FR-020 | Functional | P1 | Graceful shutdown on SIGTERM | Draft |
| S005-FR-021 | Functional | P2 | Agent identity propagation | Draft |
| S005-FR-022 | Functional | P1 | Verdict response passthrough | Draft |
| S005-AS-001 | Acceptance | P1 | Startup happy path | Draft |
| S005-AS-002 | Acceptance | P1 | Startup socket missing | Draft |
| S005-AS-003 | Acceptance | P1 | Tool allow verdict | Draft |
| S005-AS-004 | Acceptance | P1 | Tool block verdict | Draft |
| S005-AS-005 | Acceptance | P1 | Network request allowed | Draft |
| S005-AS-006 | Acceptance | P1 | Network request blocked | Draft |
| S005-AS-007 | Acceptance | P1 | Mid-session outcalld crash | Draft |
| S005-AS-008 | Acceptance | P1 | Request timeout | Draft |
| S005-AS-009 | Acceptance | P2 | Graceful shutdown | Draft |
| S005-AS-010 | Acceptance | P1 | Binary immutability | Draft |
| S005-EC-001 | Edge Case | P1 | Socket missing at startup | Draft |
| S005-EC-002 | Edge Case | P1 | Socket disappears mid-session | Draft |
| S005-EC-003 | Edge Case | P1 | outcalld crashes mid-request | Draft |
| S005-EC-004 | Edge Case | P1 | Verdict timeout | Draft |
| S005-EC-005 | Edge Case | P2 | Malformed verdict response | Draft |
| S005-EC-006 | Edge Case | P2 | Concurrent requests | Draft |
| S005-EC-007 | Edge Case | P1 | Registration rejected | Draft |
| S005-EC-008 | Edge Case | P2 | Socket exists but not listening | Draft |
| S005-EC-009 | Edge Case | P2 | Container tries to overwrite shim | Draft |
| S005-EC-010 | Edge Case | P1 | Rapid reconnect after socket flap | Draft |
| S005-SC-001 | Success | P1 | Startup and registration verified | Draft |
| S005-SC-002 | Success | P1 | Tool allow/block cycle | Draft |
| S005-SC-003 | Success | P1 | Network gating verified | Draft |
| S005-SC-004 | Success | P1 | Fail-closed on unreachable | Draft |
| S005-SC-005 | Success | P1 | No leaked actions after block | Draft |
| S005-SC-006 | Success | P1 | Exit codes correct | Draft |
| S005-SC-007 | Success | P1 | Stderr-only logging | Draft |
| S005-SC-008 | Success | P1 | Binary cannot be modified | Draft |

## Out of Scope

- **Host API surface** — the shim is a consumer of the agent API (S004), not a provider
- **Rule authoring** — rules are defined via the host API; the shim only receives verdicts
- **Container lifecycle** — starting/stopping containers is not the shim's concern
- **TLS on agent.sock** — the socket is local and bind-mounted; no TLS needed
- **Agent process management** — the shim wraps actions, it does not supervise the agent process
- **Direct nftables manipulation** — network enforcement at the packet level is handled by the bridge (S001)
- **Multi-socket communication** — the shim talks only to agent.sock, never host.sock

## Cross-Spec Dependencies

- **Depends on:** [S004](../004-agent-api/index.md) (Agent API — the shim is its primary client)
- **Depends on:** [S003](../003-rule-engine/index.md) (Rule Engine — verdicts come from rule evaluation)
- **Required by:** Container management (future spec)
