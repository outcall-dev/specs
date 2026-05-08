# S009 Success Criteria

| ID | Criterion |
|----|-----------|
| S009-SC-001 | E2E test: inserting a dynamic allow rule lets the specified traffic through while other traffic remains blocked. |
| S009-SC-002 | E2E test: removing a dynamic rule re-blocks the traffic immediately. |
| S009-SC-003 | After a container is stopped, `nft list chain inet outcall forward` contains no rules referencing that container's IP. |
