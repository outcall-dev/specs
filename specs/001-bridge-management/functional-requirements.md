# S001 Functional Requirements

### Bridge lifecycle

S001-FR-001 [P1] `outcalld` **MUST** create the bridge interface via netlink using the `rtnetlink` crate. It **MUST NOT** shell out to `ip` or `brctl`.

S001-FR-002 [P1] Bridge creation **MUST** be idempotent. If the bridge already exists, `outcalld` **MUST** attach to it and reuse its interface index.

S001-FR-003 [P1] After creation or attach, `outcalld` **MUST** bring the bridge interface up (link state UP).

### nftables base ruleset

S001-FR-004 [P1] `outcalld` **MUST** apply a base nftables ruleset to the `inet outcall` table with a `forward` chain.

S001-FR-005 [P1] The base ruleset **MUST** enforce a default-BLOCK policy: all forwarded traffic entering or leaving the bridge interface **MUST** be dropped unless explicitly allowed.

S001-FR-006 [P1] The base ruleset **MUST** accept packets in `established` or `related` connection tracking states, so responses to allowed outbound connections can return.

S001-FR-007 [P1] The nftables forward-chain policy **MUST** be `drop`. An explicit rule **MUST** accept packets whose input and output interfaces are both unrelated to the managed bridge so Outcall does not affect other forwarded traffic.

S001-FR-008 [P1] Before applying rules, `outcalld` **MUST** delete any existing `inet outcall` table (clean-slate). Deletion failure (table does not exist) **MUST** be silently ignored.

### Teardown

S001-FR-009 [P1] Teardown **MUST** execute in this order:
S001-FR-009.a Delete the `inet outcall` nftables table (warn on failure, do not abort).
S001-FR-009.b Bring the bridge interface down.
S001-FR-009.c Delete the bridge interface via netlink.

S001-FR-010 [P1] When `outcalld` receives SIGINT (Ctrl-C) or SIGTERM, it **MUST NOT** execute the bridge teardown sequence. It **MUST** atomically replace the active `inet outcall` table with the strict base policy, removing dynamic direct-egress grants while preserving the bridge interface so managed containers that outlive the daemon remain fail closed. Teardown occurs only through the explicit `POST /api/v1/bridge/down` operation after managed workloads have stopped.

### Status

S001-FR-011 [P1] The status query **MUST** perform a fresh check every call:
S001-FR-011.a Query netlink for the bridge interface existence.
S001-FR-011.b Run `nft list table inet outcall` to check if the nftables table is active.
S001-FR-011.c Return bridge name, up/down state, interface index, and nftables active flag.

### Configuration

S001-FR-012 [P1] The bridge name **MUST** be configurable via `outcalld --bridge <name>`.

S001-FR-013 [P1] The default bridge name **MUST** be `outcall0`, defined as `DEFAULT_BRIDGE_NAME` in `outcall-api`.

### Daemon integration

S001-FR-014 [P1] The bridge endpoints **MUST** be served on the host unix socket via axum:
S001-FR-014.a `GET /api/v1/bridge` — status
S001-FR-014.b `POST /api/v1/bridge/up` — initialize
S001-FR-014.c `POST /api/v1/bridge/down` — teardown

S001-FR-015 [P1] The `outcall` CLI **MUST** provide `bridge status`, `bridge up`, and `bridge down` subcommands that talk to the host API.

S001-FR-016 [P1] The bridge module and API module **MUST** be gated with `#[cfg(target_os = "linux")]`. On non-Linux platforms, `outcalld` **MUST** log a warning and skip bridge initialization.

S001-FR-017 [P1] Bridge management **MUST** run as a Tokio task within the `outcalld` process. The `BridgeManager` **MUST** be shared via `Arc<Mutex<BridgeManager>>` between the API handlers and the main task.

### Observability

S001-FR-018 [P1] All bridge operations (create, attach, up, rules applied, teardown) **MUST** emit structured log events via the `tracing` crate.

S001-FR-019 [P1] Bridge errors **MUST** use typed error variants (`BridgeError`) via `thiserror`:
S001-FR-019.a `Connection` — netlink connection failure
S001-FR-019.b `Operation` — bridge link operations (create, up, down, delete)
S001-FR-019.c `Nftables` — nft command failures

### Host socket lifecycle

S001-FR-020 [P1] `outcalld` **MUST** accept a `--socket <path>` flag for the host API socket path (default: `/run/outcall/host.sock`, defined as `DEFAULT_HOST_SOCKET` in `outcall-api`).

S001-FR-021 [P1] On startup, `outcalld` **MUST** create the parent directory of the socket path if it does not exist (`create_dir_all`).

S001-FR-022 [P1] On startup, `outcalld` **MUST** remove any stale socket file at the configured path before binding. Removal failure (file does not exist) **MUST** be silently ignored.

S001-FR-023 [P1] `outcalld` **MUST** bind a `tokio::net::UnixListener` at the socket path and serve the axum router over it.

S001-FR-024 [P1] On shutdown, `outcalld` **MUST** stop its listeners and remove the host and agent socket files while leaving bridge enforcement active.

### CLI transport

S001-FR-025 [P1] The `outcall` CLI **MUST** communicate with `outcalld` by sending raw HTTP/1.0 requests over the unix socket and reading the full response after the server closes the connection.

S001-FR-026 [P1] The CLI **MUST** use synchronous `std::os::unix::net::UnixStream` (not Tokio). The CLI does not require an async runtime.

S001-FR-027 [P1] The CLI **MUST** accept a global `--socket <path>` flag (default: `DEFAULT_HOST_SOCKET`) to locate the daemon socket.

S001-FR-028 [P1] If the socket is not reachable, the CLI **MUST** print `cannot connect to outcalld at <path> — is it running?` to stderr and exit with code 1.
