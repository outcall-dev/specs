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

- Attached only to an inspected network backed by the daemon's exact Outcall bridge (S002)
- Optional `agent.sock` and `outcall-agent` helper mounts for shim-based workloads (S004/S005)
- `HTTP_PROXY` / `HTTPS_PROXY` env vars pointed at the HTTP proxy (S006)
- DNS resolver pointed at the DNS filter (S007)
- Numeric non-root process identity, read-only root, dropped capabilities,
  `no-new-privileges`, and fixed PID limit
- Explicit Docker network mode, Docker init, and daemon-owned DNS options
- The host API, Docker, and containerd control sockets are **never** exposed

Control-socket protection is a critical security invariant. Before Bollard
issues the Docker API call, Outcall checks lexical and canonical bind-source
paths, catches symlinks, and rejects parent mounts that would expose a protected
socket. Bind destinations cannot cover the helper shim, agent socket, or resolver
configuration. The daemon also inspects the selected network's driver and bridge
name; an `outcall-` prefix alone is not trusted.

### Container naming

Callers may supply an exact operator-visible name. Omitted names default to an
`outcall-` prefix plus 8 random hex characters. Discovery and cleanup use the
`managed-by=outcalld` label, not a naming convention. Recipe runtimes provide
the higher-level `<project>-N` naming policy.

### Lifecycle

```
create → start → monitor → stop → remove
```

The Docker Manager runs as a Tokio task inside `outcalld`. There is no
separate process. The host operator manages containers through the `outcall`
CLI and the `outcalld` host API. Startup uses a bounded Docker ping so a client
endpoint that exists but does not respond is reported as degraded rather than
initialized. Lifecycle operations require the managed label and use the
inspected immutable Docker ID.

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
| S008-FR-001 | Functional | P1 | Docker Engine API only | Implemented |
| S008-FR-002 | Functional | P1 | Container creation parameters | Implemented |
| S008-FR-003 | Functional | P1 | Network attachment | Implemented |
| S008-FR-004 | Functional | P1 | Agent socket bind mount | Implemented |
| S008-FR-005 | Functional | P1 | Shim binary bind mount | Implemented |
| S008-FR-006 | Functional | P1 | Proxy env var injection | Implemented |
| S008-FR-007 | Functional | P1 | DNS resolver configuration | Implemented |
| S008-FR-008 | Functional | P1 | Host socket deny list | Implemented |
| S008-FR-009 | Functional | P1 | Bind mount validation | Implemented |
| S008-FR-010 | Functional | P1 | Container naming convention | Implemented |
| S008-FR-011 | Functional | P1 | Container start | Implemented |
| S008-FR-012 | Functional | P1 | Container stop | Implemented |
| S008-FR-013 | Functional | P1 | Container remove | Implemented |
| S008-FR-014 | Functional | P1 | Container listing | Implemented |
| S008-FR-015 | Functional | P2 | Container inspection | Implemented |
| S008-FR-016 | Functional | P2 | Resource limits | Implemented |
| S008-FR-017 | Functional | P2 | Image pulling | Implemented |
| S008-FR-018 | Functional | P1 | In-process Tokio task | Implemented |
| S008-FR-019 | Functional | P1 | Host-only API endpoints | Implemented |
| S008-FR-020 | Functional | P1 | Containers outlive daemon | Implemented |
| S008-FR-021 | Functional | P1 | CLI subcommands | Implemented |
| S008-FR-022 | Functional | P1 | CLI transport mechanism | Implemented |
| S008-FR-023 | Functional | P1 | CLI error handling | Implemented |
| S008-FR-024 | Functional | P1 | Constants in outcall-api | Implemented |
| S008-FR-025 | Functional | P2 | Read-only root filesystem | Implemented |
| S008-FR-026 | Functional | P2 | No privileged mode | Implemented |
| S008-FR-027 | Functional | P2 | Capability dropping | Implemented |
| S008-FR-028 | Functional | P1 | Stop timeout | Implemented |
| S008-FR-029 | Functional | P2 | Container labels | Implemented |
| S008-FR-030 | Functional | P1 | Network-up prerequisite | Implemented |
| S008-FR-031 | Functional | P1 | Container event stream | Implemented |
| S008-FR-032 | Functional | P1 | Outcall-managed network definition | Implemented |
| S008-FR-033 | Functional | P1 | Protected bind destinations | Implemented |
| S008-FR-034 | Functional | P1 | Managed-only immutable-ID lifecycle | Implemented |
| S008-FR-035 | Functional | P1 | Partial-create rollback | Implemented |
| S008-FR-036 | Functional | P1 | Bounded Docker availability probe | Implemented |
| S008-FR-037 | Functional | P2 | Correct image-reference parsing | Implemented |
| S008-FR-038 | Functional | P1 | Explicit network mode and init | Implemented |
| S008-FR-039 | Functional | P1 | Helper source preflight | Implemented |
| S008-AS-001 | Acceptance | P1 | Create agent container | Implemented |
| S008-AS-002 | Acceptance | P1 | Host socket rejected | Implemented |
| S008-AS-003 | Acceptance | P1 | List running containers | Implemented |
| S008-AS-004 | Acceptance | P1 | Stop container | Implemented |
| S008-AS-005 | Acceptance | P1 | Remove container | Implemented |
| S008-AS-006 | Acceptance | P1 | Network not ready | Implemented |
| S008-AS-007 | Acceptance | P2 | Inspect container | Implemented |
| S008-AS-008 | Acceptance | P2 | Pull image | Implemented |
| S008-AS-009 | Acceptance | P1 | Daemon not running | Implemented |
| S008-AS-010 | Acceptance | P1 | Docker not available | Implemented |
| S008-AS-011 | Acceptance | P1 | Containers survive shutdown | Implemented |
| S008-AS-012 | Acceptance | P1 | Container with resource limits | Implemented |
| S008-AS-013 | Acceptance | P1 | Verify bind mounts inside container | Implemented |
| S008-AS-014 | Acceptance | P1 | Verify env vars inside container | Implemented |
| S008-AS-015 | Acceptance | P1 | Protected destination rejected | Implemented |
| S008-AS-016 | Acceptance | P1 | Unmanaged lifecycle rejected | Implemented |
| S008-AS-017 | Acceptance | P1 | Hung Docker startup bounded | Implemented |
| S008-AS-018 | Acceptance | P1 | Partial create rolled back | Implemented |
| S008-AS-019 | Acceptance | P2 | Registry port and digest parsing | Implemented |
| S008-IF-001 | Interface | P1 | POST /api/v1/container/create | Implemented |
| S008-IF-002 | Interface | P1 | POST /api/v1/container/stop | Implemented |
| S008-IF-003 | Interface | P1 | POST /api/v1/container/remove | Implemented |
| S008-IF-004 | Interface | P1 | GET /api/v1/containers | Implemented |
| S008-IF-005 | Interface | P2 | GET /api/v1/container | Implemented |
| S008-IF-006 | Interface | P2 | POST /api/v1/container/pull | Implemented |
| S008-IF-007 | Interface | P1 | CLI commands | Implemented |
| S008-IF-008 | Interface | P1 | CLI output format | Implemented |
| S008-EC-001 | Edge Case | P1 | Host socket in bind mounts | Implemented |
| S008-EC-002 | Edge Case | P1 | Network does not exist | Implemented |
| S008-EC-003 | Edge Case | P1 | Docker unreachable | Implemented |
| S008-EC-004 | Edge Case | P1 | Container does not exist (stop/remove) | Implemented |
| S008-EC-005 | Edge Case | P2 | Image not found locally | Implemented |
| S008-EC-006 | Edge Case | P2 | Image pull fails | Implemented |
| S008-EC-007 | Edge Case | P1 | Container already stopped | Implemented |
| S008-EC-008 | Edge Case | P2 | Container already removed | Implemented |
| S008-EC-009 | Edge Case | P2 | Rapid create calls | Implemented |
| S008-EC-010 | Edge Case | P2 | Daemon shutdown with running containers | Implemented |
| S008-EC-011 | Edge Case | P2 | Docker disappears at runtime | Implemented |
| S008-EC-012 | Edge Case | P1 | Symlink traversal in bind mounts | Implemented |
| S008-EC-013 | Edge Case | P1 | Duplicate container name | Implemented |
| S008-EC-014 | Edge Case | P2 | Resource limit exceeds host capacity | Implemented |
| S008-EC-015 | Edge Case | P1 | Agent socket path missing | Implemented |
| S008-EC-016 | Edge Case | P1 | Shim binary path missing | Implemented |
| S008-EC-017 | Edge Case | P1 | Invalid helper source | Implemented |
| S008-EC-018 | Edge Case | P1 | Protected destination shadowing | Implemented |
| S008-EC-019 | Edge Case | P1 | Unmanaged lifecycle target | Implemented |
| S008-EC-020 | Edge Case | P1 | Hung Docker ping | Implemented |
| S008-EC-021 | Edge Case | P2 | Registry port without tag | Implemented |
| S008-SC-001 | Success | P1 | Container creation with all constraints | Implemented |
| S008-SC-002 | Success | P1 | Host socket never mounted | Implemented |
| S008-SC-003 | Success | P1 | Network attachment verified | Implemented |
| S008-SC-004 | Success | P1 | Bind mounts verified inside container | Implemented |
| S008-SC-005 | Success | P1 | Env vars verified inside container | Implemented |
| S008-SC-006 | Success | P1 | DNS resolver verified | Implemented |
| S008-SC-007 | Success | P1 | Stop and remove lifecycle | Implemented |
| S008-SC-008 | Success | P1 | Container listing accuracy | Implemented |
| S008-SC-009 | Success | P1 | No docker CLI shelling | Implemented |
| S008-SC-010 | Success | P2 | Graceful shutdown cleanup | Implemented |
| S008-SC-011 | Success | P1 | CLI round-trip | Implemented |
| S008-SC-012 | Success | P1 | Control destinations cannot be shadowed | Implemented |
| S008-SC-013 | Success | P1 | Managed-only immutable-ID lifecycle | Implemented |
| S008-SC-014 | Success | P1 | Bounded Docker startup probe | Implemented |
| S008-SC-015 | Success | P1 | Partial-create rollback | Implemented |
| S008-SC-016 | Success | P2 | Image references parsed correctly | Implemented |

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
pub const CONTAINER_PREFIX: &str = "outcall-";
pub const SHIM_CONTAINER_PATH: &str = "/usr/local/bin/outcall";
pub const AGENT_SOCKET_CONTAINER_PATH: &str = "/run/outcall/agent.sock";
pub const DEFAULT_STOP_TIMEOUT_SECS: i64 = 10;
pub const DEFAULT_MEMORY_LIMIT: i64 = 512 * 1024 * 1024;
pub const MIN_MEMORY_LIMIT: i64 = 6 * 1024 * 1024;
pub const DEFAULT_CPU_SHARES: i64 = 1024;
pub const MIN_CPU_SHARES: i64 = 2;
```

### Types

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ContainerCreateRequest {
    pub image: String,
    pub network: Option<String>,
    pub name: Option<String>,
    pub user: Option<String>,
    pub memory_limit: Option<i64>,
    pub cpu_shares: Option<i64>,
    pub env: Option<Vec<String>>,
    pub cmd: Option<Vec<String>>,
    pub entrypoint: Option<Vec<String>>,
    pub working_dir: Option<String>,
    pub volumes: Option<Vec<String>>,
    pub include_outcall_helper_mounts: Option<bool>,
    pub interactive: Option<bool>,
    pub tty: Option<bool>,
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
    pub timeout: Option<i64>,
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
