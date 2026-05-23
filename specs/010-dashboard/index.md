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
real-time view of the system's state: bridge status, networks, connected
containers, active rules, rule request queue, and traffic logs. It is built
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
| S010-FR-001 | Functional | P2 | Static assets via rust-embed | Draft |
| S010-FR-002 | Functional | P2 | Served on host socket | Draft |
| S010-FR-003 | Functional | P2 | System overview page | Draft |
| S010-FR-004 | Functional | P2 | Network listing page | Draft |
| S010-FR-005 | Functional | P2 | Container listing page | Draft |
| S010-FR-006 | Functional | P2 | Active rules view | Draft |
| S010-FR-007 | Functional | P2 | Rule request queue + approve/reject | Draft |
| S010-FR-008 | Functional | P3 | Traffic log view | Draft |
| S010-FR-009 | Functional | P2 | No agent-side exposure | Draft |
| S010-FR-010 | Functional | P3 | Auto-refresh / WebSocket updates | Draft |
| S010-AS-001 | Acceptance | P2 | Dashboard loads in browser | Draft |
| S010-AS-002 | Acceptance | P2 | Bridge status displayed | Draft |
| S010-AS-003 | Acceptance | P2 | Approve rule request | Draft |
| S010-EC-001 | Edge Case | P2 | Dashboard on non-Linux (macOS dev) | Draft |
| S010-EC-002 | Edge Case | P2 | No containers running | Draft |
| S010-SC-001 | Success | P2 | Page loads and shows live bridge state | Draft |
| S010-SC-002 | Success | P2 | Rule request can be approved via UI | Draft |

## Cross-Spec Dependencies

- **Depends on:** S001 (bridge status), S002 (network listing), S003 (rule listing, rule request approval via S003-IF-008/S003-IF-009), S004 (agent status), S006 (proxy status), S007 (DNS status), S008 (container listing), S009 (dynamic rule listing)
- **Required by:** None (UI-only, no other system depends on it)

## Out of Scope

- Mobile-responsive design (desktop-only for v1)
- Authentication/authorization (relies on unix socket permissions)
- Historical data / analytics (real-time view only)
- Configuration editing via the dashboard (read-only + approve/reject)
