# S004: Agent API

| Field | Value |
|-------|-------|
| Spec | S004 |
| Feature | Agent API |
| Date | 2026-04-21 |
| Status | Implemented |
| Author | @marktopper |

## Overview

The Agent API is the restricted container-facing communication surface for the
optional `outcall-agent` command shim. It is served on a Unix domain socket
(`agent.sock`) mounted only when helper mounts are enabled. Through this socket,
shim processes check in, request command or probe verdicts, submit rule requests
for host operator approval, and query their status.

The Agent API enforces a strict trust boundary: containers see only verdicts and
request acknowledgements. They never receive rule definitions, policy internals,
host configuration, or any information about other containers. All
shim-requested evaluation happens host-side before the shim executes a command.
Mandatory recipe egress enforcement is the bridge/proxy/DNS boundary in S015
and does not depend on shim adoption.

If the agent socket is unreachable during an explicit shim invocation,
`outcall-agent` exits with code 5. There is no fallback or degraded mode.

## User Scenarios

S004-US-001 [P1] As an AI agent, I want to check in with outcalld so that I receive my container identity and policy context before doing any work.

S004-US-002 [P1] As an AI agent, I want to request permission before executing a tool so that outcalld can evaluate rules and return a verdict.

S004-US-003 [P1] As an AI agent, I want to request permission before making a network call so that outcalld can evaluate rules and return a verdict.

S004-US-004 [P2] As an AI agent, I want to submit a rule request so that a host operator can approve new capabilities for my container.

S004-US-005 [P2] As an AI agent, I want to query the status of a pending rule request so that I know whether to proceed or wait.

S004-US-006 [P1] As a host operator, I want the agent API to enforce a strict trust boundary so that agents cannot access host-side configuration or rule definitions.

## Requirements Summary

| ID | Type | Priority | Title | Status |
|----|------|----------|-------|--------|
| S004-FR-001 | Functional | P1 | Socket created by outcalld | Implemented |
| S004-FR-002 | Functional | P1 | Socket path convention | Implemented |
| S004-FR-003 | Functional | P1 | Socket lifecycle tied to daemon | Implemented |
| S004-FR-004 | Functional | P1 | Agent check-in endpoint | Implemented |
| S004-FR-005 | Functional | P1 | Container identity verification | Implemented |
| S004-FR-006 | Functional | P1 | Permission request endpoint | Implemented |
| S004-FR-007 | Functional | P1 | Verdict response format | Implemented |
| S004-FR-008 | Functional | P1 | Host-side rule evaluation | Implemented |
| S004-FR-009 | Functional | P1 | Fail-closed on unreachable | Implemented |
| S004-FR-010 | Functional | P1 | No policy leakage | Implemented |
| S004-FR-011 | Functional | P2 | Rule request submission | Implemented |
| S004-FR-012 | Functional | P2 | Rule request status query | Implemented |
| S004-FR-013 | Functional | P1 | Context variables with requests | Implemented |
| S004-FR-014 | Functional | P2 | Rate limiting | Implemented |
| S004-FR-015 | Functional | P1 | Request timeout behavior | Implemented |
| S004-FR-016 | Functional | P1 | Structured logging | Implemented |
| S004-FR-017 | Functional | P1 | Typed errors | Implemented |
| S004-FR-018 | Functional | P1 | Tokio task integration | Implemented |
| S004-FR-019 | Functional | P1 | Separate from host API | Implemented |
| S004-AS-001 | Acceptance | P1 | Check-in happy path | Implemented |
| S004-AS-002 | Acceptance | P1 | Permission granted | Implemented |
| S004-AS-003 | Acceptance | P1 | Permission denied | Implemented |
| S004-AS-004 | Acceptance | P1 | Fail closed on socket missing | Implemented |
| S004-AS-005 | Acceptance | P1 | Fail closed on daemon crash | Implemented |
| S004-AS-006 | Acceptance | P2 | Rule request submitted | Implemented |
| S004-AS-007 | Acceptance | P2 | Rule request status polled | Implemented |
| S004-AS-008 | Acceptance | P1 | No cross-container leakage | Implemented |
| S004-AS-009 | Acceptance | P1 | Context variables forwarded | Implemented |
| S004-AS-010 | Acceptance | P2 | Rate limit enforced | Implemented |
| S004-AS-011 | Acceptance | P1 | Request timeout respected | Implemented |
| S004-IF-001 | Interface | P1 | POST /v1/checkin | Implemented |
| S004-IF-002 | Interface | P1 | POST /v1/permissions/check | Implemented |
| S004-IF-003 | Interface | P2 | POST /v1/requests/rules | Implemented |
| S004-IF-004 | Interface | P2 | GET /v1/requests/rules/{id} | Implemented |
| S004-IF-005 | Interface | P1 | Error response format | Implemented |
| S004-EC-001 | Edge Case | P1 | Socket missing at startup | Implemented |
| S004-EC-002 | Edge Case | P1 | Daemon crashes mid-request | Implemented |
| S004-EC-003 | Edge Case | P1 | Malformed request body | Implemented |
| S004-EC-004 | Edge Case | P2 | Duplicate check-in | Implemented |
| S004-EC-005 | Edge Case | P1 | Unknown container ID | Implemented |
| S004-EC-006 | Edge Case | P2 | Rate limit exceeded | Implemented |
| S004-EC-007 | Edge Case | P1 | Request timeout exceeded | Implemented |
| S004-EC-008 | Edge Case | P1 | Host socket access attempted | Implemented |
| S004-EC-009 | Edge Case | P2 | Rule request for existing rule | Implemented |
| S004-EC-010 | Edge Case | P1 | Oversized request body | Implemented |
| S004-SC-001 | Success | P1 | Agent completes check-in | Implemented |
| S004-SC-002 | Success | P1 | Permission flow round-trip | Implemented |
| S004-SC-003 | Success | P1 | Fail-closed verified | Implemented |
| S004-SC-004 | Success | P1 | Trust boundary holds | Implemented |
| S004-SC-005 | Success | P2 | Rule request lifecycle | Implemented |

## Cross-Spec Dependencies

- **Depends on:** [S001](../001-bridge-management/index.md) for the managed outer network boundary
- **Depends on:** [S003](../003-rule-engine/index.md) (rule evaluation happens host-side via the rule engine)
- **Required by:** [S005](../005-agent-shim/index.md), [S008](../008-docker-manager/index.md)
