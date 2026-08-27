# S010: Dashboard

| Field | Value |
|-------|-------|
| Spec | S010 |
| Feature | Dashboard (outcall-ui) |
| Date | 2026-04-22 |
| Status | Implemented |
| Author | @marktopper |

## Overview

The dashboard is a web UI served by outcalld's host API that provides a
real-time view of the system's state: bridge status, DNS and proxy health,
networks, connected containers, active rules, and the rule request queue. It is built
as a single-page application embedded in the `outcall-ui` crate via
`rust-embed` and served as static assets from the host API.

The dashboard is host-operator-only — it is served on the host socket and
never exposed to agent containers.

## User Scenarios

S010-US-001 [P2] As a host operator, I want a web dashboard to see the system state at a glance without memorizing CLI commands.

S010-US-002 [P2] As a host operator, I want to approve or reject agent rule requests from the dashboard.

S010-US-003 [P3] As a host operator, I want to see real-time traffic logs and blocked requests.

## Requirements Summary

| ID | Type | Priority | Title | Status |
|----|------|----------|-------|--------|
| S010-FR-001 | Functional | P2 | Static assets via rust-embed | Implemented |
| S010-FR-002 | Functional | P2 | Served on host socket | Implemented |
| S010-FR-003 | Functional | P2 | System overview page | Implemented |
| S010-FR-004 | Functional | P2 | Network listing page | Implemented |
| S010-FR-005 | Functional | P2 | Container listing page | Implemented |
| S010-FR-006 | Functional | P2 | Active rules view | Implemented |
| S010-FR-007 | Functional | P2 | Rule request queue + approve/reject | Implemented |
| S010-FR-008 | Functional | P3 | Traffic log view | Draft |
| S010-FR-009 | Functional | P2 | No agent-side exposure | Implemented |
| S010-FR-010 | Functional | P3 | Auto-refresh / WebSocket updates | Implemented |
| S010-FR-011 | Functional | P1 | Loopback-only local browser bridge | Implemented |
| S010-FR-012 | Functional | P1 | Fragment token and authenticated API fetches | Implemented |
| S010-FR-013 | Functional | P1 | Strict HTTP and origin validation | Implemented |
| S010-FR-014 | Functional | P1 | Bounded bridge resources | Implemented |
| S010-FR-015 | Functional | P1 | Late fragment-token activation | Implemented |
| S010-FR-016 | Functional | P2 | Responsive bounded layout | Implemented |
| S010-AS-001 | Acceptance | P2 | Dashboard loads in browser | Implemented |
| S010-AS-002 | Acceptance | P2 | Bridge status displayed | Implemented |
| S010-AS-003 | Acceptance | P2 | Approve rule request | Draft |
| S010-AS-004 | Acceptance | P1 | Authenticated local bridge | Implemented |
| S010-AS-005 | Acceptance | P1 | Rebinding and smuggling rejected | Implemented |
| S010-AS-006 | Acceptance | P1 | Token arrives after tokenless load | Implemented |
| S010-EC-001 | Edge Case | P2 | Dashboard on non-Linux (macOS dev) | Implemented |
| S010-EC-002 | Edge Case | P2 | No containers running | Implemented |
| S010-EC-003 | Edge Case | P1 | DNS rebinding or cross-origin request | Implemented |
| S010-EC-004 | Edge Case | P1 | Invalid bridge token | Implemented |
| S010-EC-005 | Edge Case | P1 | Ambiguous or oversized request | Implemented |
| S010-EC-006 | Edge Case | P2 | Concurrent connection cap | Implemented |
| S010-EC-007 | Edge Case | P1 | Fragment added after initial load | Implemented |
| S010-SC-001 | Success | P2 | Page loads and shows live bridge state | Implemented |
| S010-SC-002 | Success | P2 | Rule request can be approved via UI | Draft |
| S010-SC-003 | Success | P2 | Desktop and mobile layouts remain bounded | Implemented |

## Cross-Spec Dependencies

- **Depends on:** S001 (bridge status), S002 (network listing), S003 (rule listing, rule request approval via S003-IF-008/S003-IF-009), S004 (agent status), S006 (proxy status), S007 (DNS status), S008 (container listing), S009 (dynamic rule listing)
- **Required by:** None (UI-only, no other system depends on it)

## Out of Scope

- Multi-user or remote dashboard authentication beyond the per-process local bridge token
- Historical data / analytics (real-time view only)
- Configuration editing via the dashboard (read-only + approve/reject)
