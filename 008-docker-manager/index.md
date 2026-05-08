# S008: Docker Manager

| Field | Value |
|-------|-------|
| Spec | S008 |
| Feature | Docker Manager |
| Date | 2026-04-21 |
| Status | Implemented |
| Author | @marktopper |

## Overview

The Docker Manager handles the full lifecycle of agent containers within
`outcalld`. It uses the `bollard` crate to communicate with the Docker Engine
API — creating, starting, monitoring, stopping, and removing containers with
the correct security constraints enforced at creation time.

Every agent container is created with a deterministic set of constraints:

- Attached to an outcall-managed network (S002)
- `agent.sock` bind-mounted into the container (S004)
- `outcall-agent` shim bind-mounted at `/usr/local/bin/outcall` (S005)
- `HTTP_PROXY` / `HTTPS_PROXY` env vars pointed at the HTTP proxy (S006)
- DNS resolver pointed at the DNS filter (S007)
- The host socket (`host.sock`) is **never** mounted into containers

The host socket protection is the critical security invariant. Bollard enforces
this at creation time by validating all bind mounts against a deny list before
issuing the Docker API call. If any mount resolves to the host socket path, the
create call is rejected before reaching Docker.

### Container naming

All agent containers use the `outcall-agent-` prefix followed by a short
random suffix (8 hex characters). The prefix is used for discovery and cleanup.

### Lifecycle

```
create → start → monitor → stop → remove
```

The Docker Manager runs as a Tokio task inside `outcalld`. There is no
separate process. The host operator manages containers through the `outcall`
CLI and the `outcalld` host API.

## User Scenarios

S008-US-001 [P1] As a host operator, I want to create agent containers with security constraints enforced so that agents cannot access the host surface.

S008-US-002 [P1] As a host operator, I want to list running agent containers so that I can see what is active.

S008-US-003 [P1] As a host operator, I want to stop and remove agent containers so that I can clean up resources.

S008-US-004 [P1] As a host operator, I want the host socket to never be mounted into containers so that agents cannot escalate to the host API.

S008-US-005 [P2] As a host operator, I want to inspect a specific container so that I can debug issues.

S008-US-006 [P1] As a host operator, I want containers to survive daemon restarts so that running workloads are not disrupted.

S008-US-007 [P2] As a host operator, I want to pull images before creating containers so that the create step does not block on network I/O.

## Requirements Summary

| ID | Type | Priority | Title | Status |
|----|------|----------|-------|--------|
| S008-FR-001 | Functional | P1 | Docker Engine API only | Draft |
| S008-FR-002 | Functional | P1 | Container creation parameters | Draft |
| S008-FR-003 | Functional | P1 | Network attachment | Draft |
| S008-FR-004 | Functional | P1 | Agent socket bind mount | Draft |
| S008-FR-005 | Functional | P1 | Shim binary bind mount | Draft |
| S008-FR-006 | Functional | P1 | Proxy env var injection | Draft |
| S008-FR-007 | Functional | P1 | DNS resolver configuration | Draft |
| S008-FR-008 | Functional | P1 | Host socket deny list | Draft |
| S008-FR-009 | Functional | P1 | Bind mount validation | Draft |
| S008-FR-010 | Functional | P1 | Container naming convention | Draft |
| S008-FR-011 | Functional | P1 | Container start | Draft |
| S008-FR-012 | Functional | P1 | Container stop | Draft |
| S008-FR-013 | Functional | P1 | Container remove | Draft |
| S008-FR-014 | Functional | P1 | Container listing | Draft |
| S008-FR-015 | Functional | P2 | Container inspection | Draft |
| S008-FR-016 | Functional | P2 | Resource limits | Draft |
| S008-FR-017 | Functional | P2 | Image pulling | Draft |
| S008-FR-018 | Functional | P1 | In-process Tokio task | Draft |
| S008-FR-019 | Functional | P1 | Host-only API endpoints | Draft |
| S008-FR-020 | Functional | P1 | Containers outlive daemon | Draft |
| S008-FR-021 | Functional | P1 | CLI subcommands | Draft |
| S008-FR-022 | Functional | P1 | CLI transport mechanism | Draft |
| S008-FR-023 | Functional | P1 | CLI error handling | Draft |
| S008-FR-024 | Functional | P1 | Constants in outcall-api | Draft |
| S008-FR-025 | Functional | P2 | Read-only root filesystem | Draft |
| S008-FR-026 | Functional | P2 | No privileged mode | Draft |
| S008-FR-027 | Functional | P2 | Capability dropping | Draft |
| S008-FR-028 | Functional | P1 | Stop timeout | Draft |
| S008-FR-029 | Functional | P2 | Container labels | Draft |
| S008-FR-030 | Functional | P1 | Network-up prerequisite | Draft |
| S008-FR-031 | Functional | P1 | Container event stream | Draft |
| S008-FR-032 | Functional | P1 | Outcall-managed network definition | Draft |
| S008-AS-001 | Acceptance | P1 | Create agent container | Draft |
| S008-AS-002 | Acceptance | P1 | Host socket rejected | Draft |
| S008-AS-003 | Acceptance | P1 | List running containers | Draft |
| S008-AS-004 | Acceptance | P1 | Stop container | Draft |
| S008-AS-005 | Acceptance | P1 | Remove container | Draft |
| S008-AS-006 | Acceptance | P1 | Network not ready | Draft |
| S008-AS-007 | Acceptance | P2 | Inspect container | Draft |
| S008-AS-008 | Acceptance | P2 | Pull image | Draft |
| S008-AS-009 | Acceptance | P1 | Daemon not running | Draft |
| S008-AS-010 | Acceptance | P1 | Docker not available | Draft |
| S008-AS-011 | Acceptance | P1 | Containers survive shutdown | Draft |
| S008-AS-012 | Acceptance | P1 | Container with resource limits | Draft |
| S008-AS-013 | Acceptance | P1 | Verify bind mounts inside container | Draft |
| S008-AS-014 | Acceptance | P1 | Verify env vars inside container | Draft |
| S008-IF-001 | Interface | P1 | POST /api/v1/container/create | Draft |
| S008-IF-002 | Interface | P1 | POST /api/v1/container/stop | Draft |
| S008-IF-003 | Interface | P1 | POST /api/v1/container/remove | Draft |
| S008-IF-004 | Interface | P1 | GET /api/v1/containers | Draft |
| S008-IF-005 | Interface | P2 | GET /api/v1/container | Draft |
| S008-IF-006 | Interface | P2 | POST /api/v1/container/pull | Draft |
| S008-IF-007 | Interface | P1 | CLI commands | Draft |
| S008-IF-008 | Interface | P1 | CLI output format | Draft |
| S008-EC-001 | Edge Case | P1 | Host socket in bind mounts | Draft |
| S008-EC-002 | Edge Case | P1 | Network does not exist | Draft |
| S008-EC-003 | Edge Case | P1 | Docker unreachable | Draft |
| S008-EC-004 | Edge Case | P1 | Container does not exist (stop/remove) | Draft |
| S008-EC-005 | Edge Case | P2 | Image not found locally | Draft |
| S008-EC-006 | Edge Case | P2 | Image pull fails | Draft |
| S008-EC-007 | Edge Case | P1 | Container already stopped | Draft |
| S008-EC-008 | Edge Case | P2 | Container already removed | Draft |
| S008-EC-009 | Edge Case | P2 | Rapid create calls | Draft |
| S008-EC-010 | Edge Case | P2 | Daemon shutdown with running containers | Draft |
| S008-EC-011 | Edge Case | P2 | Docker disappears at runtime | Draft |
| S008-EC-012 | Edge Case | P1 | Symlink traversal in bind mounts | Draft |
| S008-EC-013 | Edge Case | P1 | Duplicate container name | Draft |
| S008-EC-014 | Edge Case | P2 | Resource limit exceeds host capacity | Draft |
| S008-EC-015 | Edge Case | P1 | Agent socket path missing | Draft |
| S008-EC-016 | Edge Case | P1 | Shim binary path missing | Draft |
| S008-SC-001 | Success | P1 | Container creation with all constraints | Draft |
| S008-SC-002 | Success | P1 | Host socket never mounted | Draft |
| S008-SC-003 | Success | P1 | Network attachment verified | Draft |
| S008-SC-004 | Success | P1 | Bind mounts verified inside container | Draft |
| S008-SC-005 | Success | P1 | Env vars verified inside container | Draft |
| S008-SC-006 | Success | P1 | DNS resolver verified | Draft |
| S008-SC-007 | Success | P1 | Stop and remove lifecycle | Draft |
| S008-SC-008 | Success | P1 | Container listing accuracy | Draft |
| S008-SC-009 | Success | P1 | No docker CLI shelling | Draft |
| S008-SC-010 | Success | P2 | Graceful shutdown cleanup | Draft |
| S008-SC-011 | Success | P1 | CLI round-trip | Draft |

## Out of Scope

- **Network creation/destruction** — handled by S002
- **Bridge management** — handled by S001
- **Rule evaluation** — handled by S003
- **Agent API protocol** — handled by S004
- **Shim binary behavior** — handled by S005
- **HTTP proxy behavior** — handled by S006
- **DNS filter behavior** — handled by S007
- **Container orchestration** (scheduling, scaling, rolling updates)
- **Image building** — operators provide pre-built images
- **Volume management** beyond the required bind mounts
- **TLS or authentication** on the host socket
- **Inter-container networking** beyond outcall network attachment
- **GPU passthrough or device mounting**

## Cross-Spec Dependencies

- **Depends on:** [S001](../001-bridge-management/index.md) (bridge must be up)
- **Depends on:** [S002](../002-network-management/index.md) (network must exist for container attachment)
- **Depends on:** [S004](../004-agent-api/index.md) (agent.sock path for bind mount)
- **Depends on:** [S005](../005-agent-shim/index.md) (shim binary path for bind mount)
- **Depends on:** [S006](../006-http-proxy/index.md) (proxy address for env var injection)
- **Depends on:** [S007](../007-dns-filter/index.md) (DNS resolver address for container config)
- **Required by:** Host operators managing agent workloads

## Shared Types (outcall-api)

### Constants

```rust
pub const CONTAINER_PREFIX: &str = "outcall-agent-";
pub const SHIM_CONTAINER_PATH: &str = "/usr/local/bin/outcall";
pub const AGENT_SOCK_CONTAINER_PATH: &str = "/run/outcall/agent.sock";
pub const DEFAULT_STOP_TIMEOUT_SECS: u32 = 10;
pub const DEFAULT_MEMORY_LIMIT: u64 = 512 * 1024 * 1024; // 512 MiB
pub const DEFAULT_CPU_SHARES: u64 = 1024;
```

### Types

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ContainerCreateRequest {
    pub image: String,
    pub network: Option<String>,
    pub name: Option<String>,
    pub memory_limit: Option<u64>,
    pub cpu_shares: Option<u64>,
    pub env: Option<Vec<String>>,
    pub cmd: Option<Vec<String>>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ContainerCreateResult {
    pub container_id: String,
    pub name: String,
    pub created: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ContainerInfo {
    pub container_id: String,
    pub name: String,
    pub image: String,
    pub state: String,
    pub network: String,
    pub created_at: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ContainerStopRequest {
    pub name: String,
    pub timeout: Option<u32>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ContainerStopResult {
    pub name: String,
    pub stopped: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ContainerRemoveRequest {
    pub name: String,
    pub force: Option<bool>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ContainerRemoveResult {
    pub name: String,
    pub removed: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ContainerInspectResult {
    pub container_id: String,
    pub name: String,
    pub image: String,
    pub state: String,
    pub network: String,
    pub ip_address: Option<String>,
    pub mounts: Vec<String>,
    pub env: Vec<String>,
    pub created_at: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ImagePullRequest {
    pub image: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ImagePullResult {
    pub image: String,
    pub pulled: bool,
}
```
