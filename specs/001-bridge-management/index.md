# S001: Bridge Management

| Field | Value |
|-------|-------|
| Spec | S001 |
| Feature | Bridge Management |
| Date | 2026-04-22 |
| Status | Implemented |
| Author | @marktopper |

## Overview

The bridge is the foundation of Outcall's network isolation. It is a Linux
network bridge interface (`outcall0` by default) that acts as a virtual switch —
every agent container's network interface is plugged into it, and all traffic
must pass through it before reaching the outside world.

nftables rules are attached to this bridge. They enforce the default-BLOCK
policy: all forwarded traffic is dropped unless a rule explicitly allows it.
Established/related connections are accepted so that responses to allowed
outbound requests can return.

The bridge subsystem runs as a Tokio task inside `outcalld`. It is managed via
the `outcall bridge` CLI commands and the host API. The bridge must be up before
any networks (S002) can be created.

## User Scenarios

S001-US-001 [P1] As a host operator, I want to bring up the bridge and nftables rules so that all agent containers are isolated by default.

S001-US-002 [P1] As a host operator, I want to check whether the bridge is up and rules are active so that I can verify the system is enforcing policy.

S001-US-003 [P1] As a host operator, I want to tear down the bridge so that I can cleanly shut down the isolation layer.

## Requirements Summary

| ID | Type | Priority | Title | Status |
|----|------|----------|-------|--------|
| S001-FR-001 | Functional | P1 | Bridge creation via netlink | Implemented |
| S001-FR-002 | Functional | P1 | Idempotent creation | Implemented |
| S001-FR-003 | Functional | P1 | Bring bridge up | Implemented |
| S001-FR-004 | Functional | P1 | Base nftables ruleset | Implemented |
| S001-FR-005 | Functional | P1 | Default-BLOCK policy | Implemented |
| S001-FR-006 | Functional | P1 | Established/related connections | Implemented |
| S001-FR-007 | Functional | P1 | Forward policy drop with unrelated-traffic exemption | Implemented |
| S001-FR-008 | Functional | P1 | Clean-slate rule application | Implemented |
| S001-FR-009 | Functional | P1 | Teardown sequence | Implemented |
| S001-FR-010 | Functional | P1 | Daemon shutdown preserves enforcement | Implemented |
| S001-FR-011 | Functional | P1 | Status endpoint (fresh check) | Implemented |
| S001-FR-012 | Functional | P1 | Configurable bridge name | Implemented |
| S001-FR-013 | Functional | P1 | Default bridge name constant | Implemented |
| S001-FR-014 | Functional | P1 | Host API endpoints | Implemented |
| S001-FR-015 | Functional | P1 | CLI subcommands | Implemented |
| S001-FR-016 | Functional | P1 | Linux-only compilation | Implemented |
| S001-FR-017 | Functional | P1 | Tokio task integration | Implemented |
| S001-FR-018 | Functional | P1 | Structured logging | Implemented |
| S001-FR-019 | Functional | P1 | Typed errors | Implemented |
| S001-FR-020 | Functional | P1 | Socket path flag | Implemented |
| S001-FR-021 | Functional | P1 | Socket directory creation | Implemented |
| S001-FR-022 | Functional | P1 | Stale socket removal | Implemented |
| S001-FR-023 | Functional | P1 | UnixListener bind | Implemented |
| S001-FR-024 | Functional | P1 | Socket cleanup on shutdown | Implemented |
| S001-FR-025 | Functional | P1 | CLI raw HTTP/1.0 transport | Implemented |
| S001-FR-026 | Functional | P1 | CLI sync I/O (no Tokio) | Implemented |
| S001-FR-027 | Functional | P1 | CLI --socket flag | Implemented |
| S001-FR-028 | Functional | P1 | CLI unreachable error | Implemented |
| S001-AS-001 | Acceptance | P1 | Bridge up happy path | Implemented |
| S001-AS-002 | Acceptance | P1 | Idempotent re-up | Implemented |
| S001-AS-003 | Acceptance | P1 | Status when up | Implemented |
| S001-AS-004 | Acceptance | P1 | Status when down | Implemented |
| S001-AS-005 | Acceptance | P1 | Teardown happy path | Implemented |
| S001-AS-006 | Acceptance | P1 | Daemon shutdown preserves enforcement | Implemented |
| S001-AS-007 | Acceptance | P1 | Bridge already exists (attach) | Implemented |
| S001-AS-008 | Acceptance | P1 | CLI bridge status | Implemented |
| S001-AS-009 | Acceptance | P1 | CLI bridge up | Implemented |
| S001-AS-010 | Acceptance | P1 | CLI bridge down | Implemented |
| S001-IF-001 | Interface | P1 | GET /api/v1/bridge | Implemented |
| S001-IF-002 | Interface | P1 | POST /api/v1/bridge/up | Implemented |
| S001-IF-003 | Interface | P1 | POST /api/v1/bridge/down | Implemented |
| S001-IF-004 | Interface | P1 | CLI commands | Implemented |
| S001-IF-005 | Interface | P1 | CLI output format | Implemented |
| S001-IF-006 | Interface | P1 | Host socket protocol | Implemented |
| S001-IF-007 | Interface | P1 | CLI transport protocol | Implemented |
| S001-IF-008 | Interface | P1 | outcalld CLI flags | Implemented |
| S001-EC-001 | Edge Case | P1 | Bridge already exists | Implemented |
| S001-EC-002 | Edge Case | P1 | nft command not found | Implemented |
| S001-EC-003 | Edge Case | P1 | Insufficient permissions | Implemented |
| S001-EC-004 | Edge Case | P1 | Stale nftables table | Implemented |
| S001-EC-005 | Edge Case | P2 | Teardown with no bridge | Implemented |
| S001-EC-006 | Edge Case | P1 | Daemon not running (CLI) | Implemented |
| S001-EC-007 | Edge Case | P2 | macOS compilation | Implemented |
| S001-SC-001 | Success | P1 | Bridge verified by ip link show | Implemented |
| S001-SC-002 | Success | P1 | nftables verified by nft list table | Implemented |
| S001-SC-003 | Success | P1 | Traffic blocked (E2E) | Implemented |
| S001-SC-004 | Success | P1 | Allow/revoke cycle (E2E) | Implemented |
| S001-SC-005 | Success | P1 | Clean teardown (no leaks) | Implemented |

## Cross-Spec Dependencies

- **Required by:** [S002](../002-network-management/index.md), [S003](../003-rule-engine/index.md), [S007](../007-dns-filter/index.md), [S008](../008-docker-manager/index.md), [S009](../009-dynamic-rules/index.md)
