# S009 Edge Cases

| ID | Scenario | Expected Behavior |
|----|----------|-------------------|
| S009-EC-001 | `nft insert` fails (permission, syntax) | Log the error, return failure to the caller. Do not allow the traffic — fail closed. |
| S009-EC-002 | Container stopped but rule removal fails | Log a warning. On next daemon restart, the base ruleset is reapplied clean (no stale allows). |
| S009-EC-003 | Duplicate rule insert (same container + destination) | Idempotent — if an equivalent rule already exists, return success without inserting a duplicate. |
| S009-EC-004 | Daemon restart with running containers | On restart, only the base drop-all rules are applied (S009-FR-010). Surviving containers (S008-FR-020) are rediscovered but all their traffic is blocked until they re-request permission through the agent API (S004). This is intentional: no stale allows can persist across restarts. |
