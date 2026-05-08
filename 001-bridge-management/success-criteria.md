# S001 Success Criteria

| ID | Criterion |
|----|-----------|
| S001-SC-001 | After `outcall bridge up`, `ip link show outcall0` confirms the bridge exists and is UP. |
| S001-SC-002 | After `outcall bridge up`, `nft list table inet outcall` shows the forward chain with drop rules matching the bridge name. |
| S001-SC-003 | E2E test: outbound TCP, UDP, and ICMP from an agent namespace are blocked by the base rules. |
| S001-SC-004 | E2E test: inserting an allow rule lets traffic through, removing it re-blocks — proving nftables is the control mechanism. |
| S001-SC-005 | After `outcall bridge down`, both `ip link show outcall0` and `nft list table inet outcall` fail — no leaked state. |
