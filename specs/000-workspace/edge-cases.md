# S000 Edge Cases

| ID | Scenario | Expected Behavior |
|----|----------|-------------------|
| S000-EC-001 | `cargo build --workspace` on macOS | All crates compile. Linux-only modules (`bridge`, `api`) are gated with `#[cfg(target_os = "linux")]` and skipped. Binaries are produced but `outcalld` only logs a warning on non-Linux. |
