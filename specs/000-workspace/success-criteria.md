# S000 Success Criteria

| ID | Criterion |
|----|-----------|
| S000-SC-001 | `cargo build --workspace` produces all 4 binaries (`outcalld`, `outcall`, `outcall-agent`, `outcall-ui`) with zero errors. |
| S000-SC-002 | `cargo check --workspace --target x86_64-unknown-linux-gnu` passes, confirming the Linux-only bridge and API modules compile for the target platform. |
