# S009: Dynamic Rules

| Field | Value |
|-------|-------|
| Spec | S009 |
| Feature | Dynamic Rules |
| Date | 2026-04-22 |
| Status | Implemented |
| Author | @marktopper |

## Overview

Dynamic rules allow outcalld to insert and remove per-container or per-network
nftables rules at runtime, without restarting the daemon or reloading the full
ruleset. This is the enforcement mechanism that translates rule engine verdicts
(S003) into actual packet filtering decisions at the bridge level (S001).

The base nftables ruleset (S001) blocks everything by default. Dynamic rules
punch holes — allowing specific traffic flows for specific containers based on
the loaded policy. When a container is stopped or a rule is revoked, the
corresponding nftables rules are removed and traffic is blocked again.

## User Scenarios

S009-US-001 [P1] As outcalld, I want to insert nftables allow rules when the rule engine grants a verdict, so that approved traffic can flow through the bridge.

S009-US-002 [P1] As outcalld, I want to remove nftables rules when a container is stopped or a rule is revoked, so that traffic is re-blocked immediately.

S009-US-003 [P2] As a host operator, I want to list active dynamic rules so that I can see what traffic is currently allowed.

## Requirements Summary

| ID | Type | Priority | Title | Status |
|----|------|----------|-------|--------|
| S009-FR-001 | Functional | P1 | Insert allow rules via nftables | Implemented |
| S009-FR-002 | Functional | P1 | Remove rules on revocation or expiry | Implemented |
| S009-FR-003 | Functional | P1 | Rule keyed to container + destination | Implemented |
| S009-FR-004 | Functional | P1 | Remove all rules on container stop | Implemented |
| S009-FR-005 | Functional | P1 | Base rules untouched | Implemented |
| S009-FR-006 | Functional | P2 | List active dynamic rules | Implemented |
| S009-FR-007 | Functional | P1 | Rule handle tracking | Implemented |
| S009-FR-008 | Functional | P1 | Atomic insert/remove | Implemented |
| S009-FR-009 | Functional | P2 | Flush all dynamic rules | Implemented |
| S009-FR-010 | Functional | P1 | No dynamic rules survive daemon restart | Implemented |
| S009-FR-011 | Functional | P1 | Default-BLOCK inheritance | Implemented |
| S009-FR-012 | Functional | P1 | Managed source-IP identity | Implemented |
| S009-FR-013 | Functional | P1 | Typed inputs and bounded operations | Implemented |
| S009-FR-014 | Functional | P1 | Failed deletion restores base policy | Implemented |
| S009-FR-015 | Functional | P1 | Bounded temporary-rule expiration | Implemented |
| S009-FR-016 | Functional | P1 | Source-aware duplicate renewal | Implemented |
| S009-AS-001 | Acceptance | P1 | Allow rule inserted, traffic flows | Draft |
| S009-AS-002 | Acceptance | P1 | Rule removed, traffic re-blocked | Draft |
| S009-AS-003 | Acceptance | P1 | Container stopped, all its rules removed | Draft |
| S009-AS-004 | Acceptance | P2 | List shows active rules | Draft |
| S009-AS-005 | Acceptance | P1 | Base drop rules still apply to unmatched traffic | Draft |
| S009-AS-006 | Acceptance | P1 | Failed deletion restores deny policy | Implemented |
| S009-AS-007 | Acceptance | P1 | Temporary rule expires | Implemented |
| S009-IF-001 | Interface | P2 | GET /api/v1/rules/active | Implemented |
| S009-IF-002 | Interface | P2 | POST /api/v1/rules/flush | Implemented |
| S009-IF-003 | Interface | P1 | POST /api/v1/rule/allow | Implemented |
| S009-EC-001 | Edge Case | P1 | nft insert fails | Implemented |
| S009-EC-002 | Edge Case | P1 | Stale rule for stopped container | Implemented |
| S009-EC-003 | Edge Case | P2 | Duplicate rule insert | Implemented |
| S009-EC-004 | Edge Case | P1 | Daemon crash with rules active | Implemented |
| S009-EC-005 | Edge Case | P1 | Malformed dynamic rule input | Implemented |
| S009-EC-006 | Edge Case | P1 | Bounded nft and DNS operations | Implemented |
| S009-EC-007 | Edge Case | P1 | Invalid temporary-rule expiry | Implemented |
| S009-EC-008 | Edge Case | P1 | Partial expiry cleanup failure | Implemented |
| S009-SC-001 | Success | P1 | E2E: dynamic allow lets traffic through | Draft |
| S009-SC-002 | Success | P1 | E2E: rule removal re-blocks traffic | Draft |
| S009-SC-003 | Success | P1 | No leaked rules after container stop | Draft |

## Cross-Spec Dependencies

- **Depends on:** [S001](../001-bridge-management/index.md) (nftables base ruleset)
- **Depends on:** [S003](../003-rule-engine/index.md) (verdicts trigger rule insertion)
- **Required by:** [S008](../008-docker-manager/index.md)
