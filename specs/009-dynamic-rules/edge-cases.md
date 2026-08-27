# S009 Edge Cases

| ID | Scenario | Expected Behavior |
|----|----------|-------------------|
| S009-EC-001 | `nft insert` fails (permission, syntax) | Log the error, return failure to the caller. Do not allow the traffic — fail closed. |
| S009-EC-002 | Container stopped but rule removal fails | Log a warning and immediately restore the base deny policy, removing all dynamic allows. If the reset also fails, return/log an explicit error and retain tracked state for operator visibility. |
| S009-EC-003 | Duplicate rule insert (same container + destination) | Idempotent — if an equivalent rule already exists, return success without inserting a duplicate. |
| S009-EC-004 | Daemon restart with running containers | On restart, only the base drop-all rules are applied (S009-FR-010). Surviving containers (S008-FR-020) are rediscovered but all their traffic is blocked until they re-request permission through the agent API (S004). This is intentional: no stale allows can persist across restarts. |
| S009-EC-005 | Malformed source IP, destination CIDR, or port without protocol | Reject before invoking `nft`; no rule or in-memory record is created. |
| S009-EC-006 | `nft` or hostname resolution hangs | Terminate or abandon the bounded operation, return failure, and preserve the prior policy state. |
| S009-EC-007 | Expiry is zero or exceeds 86,400 seconds | Reject before resolving the destination or invoking `nft`; no rule or in-memory record is created. |
| S009-EC-008 | Expiry cleanup deletes one handle, then another deletion fails | Restore the base policy, clear all tracked grants after reset succeeds, and report the full number removed, including handles deleted before the reset. |
