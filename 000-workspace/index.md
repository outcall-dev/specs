# S000: Workspace Structure

| Field | Value |
|-------|-------|
| Spec | S000 |
| Feature | Cargo Workspace & Shared Types |
| Date | 2026-04-23 |
| Status | Implemented |
| Author | @marktopper |

## Overview

Outcall is structured as a Cargo workspace with five crates. All components
compile into separate binaries from a single workspace. The `outcall-api` crate
is a types-only library shared by all other crates — it contains no business
logic, only request/response structs, constants, and serialization.

## User Scenarios

S000-US-001 [P1] As a developer, I want a single `cargo build --workspace` to compile all binaries so that the build is atomic and consistent.

## Requirements Summary

| ID | Type | Priority | Title | Status |
|----|------|----------|-------|--------|
| S000-FR-001 | Functional | P1 | Workspace with 5 crates | Implemented |
| S000-FR-002 | Functional | P1 | outcall-api is types-only | Implemented |
| S000-FR-003 | Functional | P1 | Dependency graph | Implemented |
| S000-FR-004 | Functional | P1 | Shared constants | Implemented |
| S000-FR-005 | Functional | P1 | ApiResponse envelope | Implemented |
| S000-FR-006 | Functional | P1 | Rule types (forward declarations) | Implemented |
| S000-FR-007 | Functional | P1 | Bridge types | Implemented |
| S000-EC-001 | Edge Case | P1 | macOS compilation | Implemented |
| S000-SC-001 | Success | P1 | cargo build --workspace passes | Implemented |
| S000-SC-002 | Success | P1 | Linux cross-check passes | Implemented |

## Cross-Spec Dependencies

- **Required by:** All specs (S001-S011)
