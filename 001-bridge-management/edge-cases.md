# S001 Edge Cases

| ID | Scenario | Expected Behavior |
|----|----------|-------------------|
| S001-EC-001 | Bridge already exists when outcalld starts | Attach to existing bridge, reuse index. Do not error. |
| S001-EC-002 | `nft` command not found on the system | `BridgeError::Nftables("nft command not found — is nftables installed?")`. Bridge link may be up but rules are not applied. |
| S001-EC-003 | Insufficient permissions (no CAP_NET_ADMIN) | Netlink returns `io::Error` with permission detail. nft returns `BridgeError::Nftables("permission denied running nft — are you root or have CAP_NET_ADMIN?")`. |
| S001-EC-004 | Stale nftables table from previous run | Deleted before applying new rules (clean-slate in S001-FR-008). |
| S001-EC-005 | Teardown called when bridge was never created | Nftables deletion warns and continues. Bridge deletion skipped (no index). No error. |
| S001-EC-006 | CLI called when daemon is not running | CLI prints `cannot connect to outcalld at <socket> — is it running?` and exits with code 1. |
| S001-EC-007 | Compilation on macOS | Bridge and API modules are `#[cfg(target_os = "linux")]`. macOS build compiles but skips bridge subsystem. |
