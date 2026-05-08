# S004: Agent API

| Field | Value |
|-------|-------|
| Spec | S004 |
| Feature | Agent API |
| Date | 2026-04-21 |
| Status | Implemented |
| Author | @marktopper |

## Overview

The Agent API is the sole communication surface between AI agent containers and
`outcalld`. It is served on a Unix domain socket (`agent.sock`) that is
bind-mounted into each container. Through this socket, agents check in, request
permission before executing tools or making network calls, submit rule requests
for host operator approval, and query the status of those requests.

The Agent API enforces a strict trust boundary: containers see only verdicts and
request acknowledgements. They never receive rule definitions, policy internals,
host configuration, or any information about other containers. All rule
evaluation happens host-side before any tool execution proceeds.

If the agent socket is unreachable, the `outcall-agent` shim exits with code 5
(fail closed). There is no fallback, no retry loop, and no degraded mode.

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
| S004-FR-001 | Functional | P1 | Socket created by outcalld | Draft |
| S004-FR-002 | Functional | P1 | Socket path convention | Draft |
| S004-FR-003 | Functional | P1 | Socket lifecycle tied to daemon | Draft |
| S004-FR-004 | Functional | P1 | Agent check-in endpoint | Draft |
| S004-FR-005 | Functional | P1 | Container identity verification | Draft |
| S004-FR-006 | Functional | P1 | Permission request endpoint | Draft |
| S004-FR-007 | Functional | P1 | Verdict response format | Draft |
| S004-FR-008 | Functional | P1 | Host-side rule evaluation | Draft |
| S004-FR-009 | Functional | P1 | Fail-closed on unreachable | Draft |
| S004-FR-010 | Functional | P1 | No policy leakage | Draft |
| S004-FR-011 | Functional | P2 | Rule request submission | Draft |
| S004-FR-012 | Functional | P2 | Rule request status query | Draft |
| S004-FR-013 | Functional | P1 | Context variables with requests | Draft |
| S004-FR-014 | Functional | P2 | Rate limiting | Draft |
| S004-FR-015 | Functional | P1 | Request timeout behavior | Draft |
| S004-FR-016 | Functional | P1 | Structured logging | Draft |
| S004-FR-017 | Functional | P1 | Typed errors | Draft |
| S004-FR-018 | Functional | P1 | Tokio task integration | Draft |
| S004-FR-019 | Functional | P1 | Separate from host API | Draft |
| S004-AS-001 | Acceptance | P1 | Check-in happy path | Draft |
| S004-AS-002 | Acceptance | P1 | Permission granted | Draft |
| S004-AS-003 | Acceptance | P1 | Permission denied | Draft |
| S004-AS-004 | Acceptance | P1 | Fail closed on socket missing | Draft |
| S004-AS-005 | Acceptance | P1 | Fail closed on daemon crash | Draft |
| S004-AS-006 | Acceptance | P2 | Rule request submitted | Draft |
| S004-AS-007 | Acceptance | P2 | Rule request status polled | Draft |
| S004-AS-008 | Acceptance | P1 | No cross-container leakage | Draft |
| S004-AS-009 | Acceptance | P1 | Context variables forwarded | Draft |
| S004-AS-010 | Acceptance | P2 | Rate limit enforced | Draft |
| S004-AS-011 | Acceptance | P1 | Request timeout respected | Draft |
| S004-IF-001 | Interface | P1 | POST /v1/checkin | Draft |
| S004-IF-002 | Interface | P1 | POST /v1/permissions/check | Draft |
| S004-IF-003 | Interface | P2 | POST /v1/requests/rules | Draft |
| S004-IF-004 | Interface | P2 | GET /v1/requests/rules/{id} | Draft |
| S004-IF-005 | Interface | P1 | Error response format | Draft |
| S004-EC-001 | Edge Case | P1 | Socket missing at startup | Draft |
| S004-EC-002 | Edge Case | P1 | Daemon crashes mid-request | Draft |
| S004-EC-003 | Edge Case | P1 | Malformed request body | Draft |
| S004-EC-004 | Edge Case | P2 | Duplicate check-in | Draft |
| S004-EC-005 | Edge Case | P1 | Unknown container ID | Draft |
| S004-EC-006 | Edge Case | P2 | Rate limit exceeded | Draft |
| S004-EC-007 | Edge Case | P1 | Request timeout exceeded | Draft |
| S004-EC-008 | Edge Case | P1 | Host socket access attempted | Draft |
| S004-EC-009 | Edge Case | P2 | Rule request for existing rule | Draft |
| S004-EC-010 | Edge Case | P1 | Oversized request body | Draft |
| S004-SC-001 | Success | P1 | Agent completes check-in | Draft |
| S004-SC-002 | Success | P1 | Permission flow round-trip | Draft |
| S004-SC-003 | Success | P1 | Fail-closed verified | Draft |
| S004-SC-004 | Success | P1 | Trust boundary holds | Draft |
| S004-SC-005 | Success | P2 | Rule request lifecycle | Draft |

## Cross-Spec Dependencies

- **Depends on:** [S001](../001-bridge-management/index.md) (bridge must be up; agent socket listens on bridge IP)
- **Depends on:** [S003](../003-rule-engine/index.md) (rule evaluation happens host-side via the rule engine)
- **Required by:** [S005](../005-agent-shim/index.md), [S008](../008-docker-manager/index.md)
