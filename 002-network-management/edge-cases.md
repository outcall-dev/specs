# S002 Edge Cases

| ID | Scenario | Expected Behavior |
|----|----------|-------------------|
| S002-EC-001 | Network already exists (create) | Return success with `created: false`. Do not error. |
| S002-EC-002 | Bridge not up (create) | Return error. Do not attempt Docker API calls. |
| S002-EC-003 | Docker daemon unreachable | Return error with descriptive message. |
| S002-EC-004 | Network does not exist (status) | Return success with `exists: false`, null fields, empty containers list. |
| S002-EC-005 | Network does not exist (destroy) | Return success with `destroyed: false`. Idempotent. |
| S002-EC-006 | Containers connected (destroy) | Return error listing container names. Do not force-disconnect. |
| S002-EC-007 | Destroy default network | Allowed. Recreatable via `outcall network create`. |
| S002-EC-008 | Network exists but bridge mismatch | The create endpoint **SHOULD** log a warning but **MUST** still return success. |
| S002-EC-009 | Multiple rapid create calls | Idempotency handles this: second call sees existing network. |
| S002-EC-010 | outcalld shutdown while networks exist | Networks persist in Docker. Intentional — they outlive the daemon so containers are not disrupted. |
| S002-EC-011 | Docker available at startup but disappears later | Individual endpoint calls return Docker connection errors. The daemon continues running. |
| S002-EC-012 | Subnet collision with existing Docker network | outcalld detects the collision before calling Docker and returns a clear error naming the conflicting network. |
| S002-EC-013 | All 255 /24 subnets exhausted | Return error: `"no available subnets in 10.200.0.0/16"`. |
| S002-EC-014 | Invalid network name (special characters, too long) | Return error with validation message. |
