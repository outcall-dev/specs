# S002 Success Criteria

| ID | Criterion |
|----|-----------|
| S002-SC-001 | `outcall network create` creates the default network confirmed by `docker network inspect outcall-default`. |
| S002-SC-002 | `outcall network create --name staging` auto-allocates a /24 subnet and creates the network on the same bridge. |
| S002-SC-003 | `outcall network status` accurately reflects container state. |
| S002-SC-004 | `outcall network list` shows all outcall-managed networks. |
| S002-SC-005 | `outcall network destroy --name staging` removes the named network. |
| S002-SC-006 | `outcall network destroy` removes the default network, and `outcall network create` recreates it. |
| S002-SC-007 | `outcall network destroy --name staging` refuses when containers are connected. |
| S002-SC-008 | All commands are idempotent as specified. |
| S002-SC-009 | Auto-allocation skips subnets already used by any Docker network. |
| S002-SC-010 | No shell-outs to the `docker` CLI from `outcalld`. |
| S002-SC-011 | Existing `outcall bridge *` commands continue to work unchanged. |
