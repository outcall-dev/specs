# S000 Functional Requirements

### Workspace structure

S000-FR-001 [P1] The Cargo workspace **MUST** contain five crates:
S000-FR-001.a `outcalld` — daemon binary (lib + bin crate), manages bridge, nftables, host API, all subsystems
S000-FR-001.b `outcall` — host CLI binary, talks to `outcalld` via unix socket
S000-FR-001.c `outcall-agent` — agent shim binary, bind-mounted into containers
S000-FR-001.d `outcall-api` — types-only library crate, shared by all other crates
S000-FR-001.e `outcall-ui` — dashboard binary (stub)

S000-FR-002 [P1] `outcall-api` **MUST** contain only types, constants, and serialization derives. It **MUST NOT** contain business logic, I/O, or network code.

S000-FR-003 [P1] The dependency graph **MUST** be:
S000-FR-003.a `outcalld` depends on `outcall-api`
S000-FR-003.b `outcall` depends on `outcall-api`
S000-FR-003.c `outcall-agent` depends on `outcall-api`
S000-FR-003.d `outcall-ui` depends on `outcall-api`
S000-FR-003.e No circular dependencies. No crate depends on `outcalld`, `outcall`, `outcall-agent`, or `outcall-ui`.

### Shared constants (outcall-api)

S000-FR-004 [P1] `outcall-api` **MUST** define these constants:
S000-FR-004.a `UNREACHABLE_EXIT_CODE: i32 = 5` — exit code when agent shim cannot reach outcalld
S000-FR-004.b `DEFAULT_HOST_SOCKET: &str = "/run/outcall/host.sock"` — host API socket path
S000-FR-004.c `DEFAULT_AGENT_SOCKET: &str = "/run/outcall/agent.sock"` — agent API socket path
S000-FR-004.d `DEFAULT_BRIDGE_NAME: &str = "outcall0"` — bridge interface name

### Shared types (outcall-api)

S000-FR-005 [P1] `outcall-api` **MUST** define `ApiResponse<T>` as the standard JSON envelope for all host API responses:
S000-FR-005.a `success: bool` — always present
S000-FR-005.b `data: Option<T>` — present on success, skipped when None (serde `skip_serializing_if`)
S000-FR-005.c `error: Option<String>` — present on failure, skipped when None

S000-FR-006 [P1] `outcall-api` **MUST** define forward-declaration types for the rule system:
S000-FR-006.a `RuleAction` enum — `Allow`, `Block`, `Enrich` (serde: lowercase)
S000-FR-006.b `Verdict` struct — `allowed: bool`, `matched_rule: Option<String>`, `reason: Option<String>`
S000-FR-006.c `RuleRequest` struct — `description: String`, `condition: String`, `action: RuleAction`
S000-FR-006.d `RuleRequestStatus` enum — `Pending`, `Approved`, `Rejected` (serde: lowercase)
S000-FR-006.e `RuleRequestResponse` struct — `id: String`, `status: RuleRequestStatus`, `reason: Option<String>`

S000-FR-007 [P1] `outcall-api` **MUST** define `BridgeStatus` struct:
S000-FR-007.a `name: String` — bridge interface name
S000-FR-007.b `up: bool` — whether the interface exists and is UP
S000-FR-007.c `index: Option<u32>` — kernel interface index (None if not attached)
S000-FR-007.d `nftables_active: bool` — whether the `inet outcall` table exists
