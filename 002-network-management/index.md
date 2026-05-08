# S002: Network Management

| Field | Value |
|-------|-------|
| Spec | S002 |
| Feature | Network Management |
| Date | 2026-04-22 |
| Status | Draft |
| Author | @marktopper |

## Overview

Manage the isolated networks that agent containers run on. Every agent container
connects to an outcall-managed network where all outbound traffic is governed by
the bridge and nftables policy layer. The host operator creates, inspects, and
destroys these networks through the `outcall` CLI and the `outcalld` host API.

A default network (`outcall-default`) is created on first use and can be
destroyed and recreated at any time. Additional named networks can be created
for workload isolation — each network shares the same bridge and nftables
policy, but provides a separate address space and container group.

### Subnet allocation

Outcall reserves the `10.200.0.0/16` block. This range was chosen because it
avoids collisions with Docker (172.17+), Kubernetes (10.96, 10.244), AWS VPCs
(10.0-10.10), k3s (10.42-10.43), OpenVPN (10.8), home routers (10.0, 192.168),
and Podman (10.88). Each network gets a `/24` subnet auto-allocated from this
block:

```
outcall-default    → 10.200.0.0/24   (first available)
outcall-staging    → 10.200.1.0/24   (next available)
outcall-prod       → 10.200.2.0/24   (next available)
...up to 255 networks
```

Before allocating, outcalld checks both its own records and Docker's live
network list to avoid collisions. A specific subnet can be requested with
`--subnet` to override auto-allocation.

## User Scenarios

S002-US-001 [P1] As a host operator, I want to create isolated networks for agent containers so that each workload group has its own address space.

S002-US-002 [P1] As a host operator, I want to inspect which containers are connected to each network so that I can manage workload placement.

S002-US-003 [P1] As a host operator, I want to destroy networks I no longer need so that resources are cleaned up.

## Requirements Summary

| ID | Type | Priority | Title | Status |
|----|------|----------|-------|--------|
| S002-FR-001 | Functional | P1 | Docker Engine API only | Draft |
| S002-FR-002 | Functional | P1 | Network creation parameters | Draft |
| S002-FR-003 | Functional | P1 | Idempotent create | Draft |
| S002-FR-004 | Functional | P1 | Bridge-up prerequisite | Draft |
| S002-FR-005 | Functional | P2 | Post-create bridge verification | Draft |
| S002-FR-006 | Functional | P1 | Default network definition | Draft |
| S002-FR-007 | Functional | P1 | Default network on bare create | Draft |
| S002-FR-008 | Functional | P1 | Default network destroyable | Draft |
| S002-FR-009 | Functional | P1 | Named network prefix | Draft |
| S002-FR-010 | Functional | P1 | Shared bridge interface | Draft |
| S002-FR-011 | Functional | P2 | Name validation | Draft |
| S002-FR-012 | Functional | P1 | Subnet auto-allocation | Draft |
| S002-FR-013 | Functional | P1 | Collision detection | Draft |
| S002-FR-014 | Functional | P2 | Subnet exhaustion error | Draft |
| S002-FR-015 | Functional | P1 | Explicit subnet collision check | Draft |
| S002-FR-016 | Functional | P1 | Status response content | Draft |
| S002-FR-017 | Functional | P1 | No state caching | Draft |
| S002-FR-018 | Functional | P1 | List endpoint discovery | Draft |
| S002-FR-019 | Functional | P1 | Destroy refuses when connected | Draft |
| S002-FR-020 | Functional | P2 | Idempotent destroy | Draft |
| S002-FR-021 | Functional | P1 | No force-disconnect | Draft |
| S002-FR-022 | Functional | P1 | In-process Docker management | Draft |
| S002-FR-023 | Functional | P2 | Docker client startup resilience | Draft |
| S002-FR-024 | Functional | P1 | Host socket only | Draft |
| S002-FR-025 | Functional | P1 | CLI subcommands | Draft |
| S002-FR-026 | Functional | P1 | CLI transport mechanism | Draft |
| S002-FR-027 | Functional | P1 | CLI error handling | Draft |
| S002-FR-028 | Functional | P1 | Constants in outcall-api | Draft |
| S002-FR-029 | Functional | P2 | Configurable subnet block | Draft |
| S002-FR-030 | Functional | P2 | RFC 1918 validation | Draft |
| S002-FR-031 | Functional | P2 | Config query endpoint | Draft |
| S002-FR-032 | Functional | P1 | Network rediscovery on startup | Draft |
| S002-AS-001 | Acceptance | P1 | Create default network | Draft |
| S002-AS-002 | Acceptance | P1 | Create named network (auto-subnet) | Draft |
| S002-AS-003 | Acceptance | P1 | Create already exists | Draft |
| S002-AS-004 | Acceptance | P1 | Create bridge not up | Draft |
| S002-AS-005 | Acceptance | P1 | Status with containers | Draft |
| S002-AS-006 | Acceptance | P1 | Status named network | Draft |
| S002-AS-007 | Acceptance | P1 | Status does not exist | Draft |
| S002-AS-008 | Acceptance | P1 | List multiple networks | Draft |
| S002-AS-009 | Acceptance | P1 | Destroy named network | Draft |
| S002-AS-010 | Acceptance | P1 | Destroy default network | Draft |
| S002-AS-011 | Acceptance | P1 | Destroy containers connected | Draft |
| S002-AS-012 | Acceptance | P2 | Destroy does not exist | Draft |
| S002-AS-013 | Acceptance | P1 | Daemon not running | Draft |
| S002-AS-014 | Acceptance | P1 | Docker not available | Draft |
| S002-IF-001 | Interface | P1 | POST /api/v1/network/create | Draft |
| S002-IF-002 | Interface | P1 | GET /api/v1/network | Draft |
| S002-IF-003 | Interface | P1 | GET /api/v1/networks | Draft |
| S002-IF-004 | Interface | P1 | POST /api/v1/network/destroy | Draft |
| S002-IF-005 | Interface | P1 | CLI commands | Draft |
| S002-IF-006 | Interface | P1 | CLI output format | Draft |
| S002-EC-001 | Edge Case | P1 | Network already exists | Draft |
| S002-EC-002 | Edge Case | P1 | Bridge not up | Draft |
| S002-EC-003 | Edge Case | P1 | Docker unreachable | Draft |
| S002-EC-004 | Edge Case | P1 | Status for missing network | Draft |
| S002-EC-005 | Edge Case | P2 | Destroy missing network | Draft |
| S002-EC-006 | Edge Case | P1 | Containers connected on destroy | Draft |
| S002-EC-007 | Edge Case | P1 | Destroy default network | Draft |
| S002-EC-008 | Edge Case | P2 | Bridge mismatch | Draft |
| S002-EC-009 | Edge Case | P2 | Rapid create calls | Draft |
| S002-EC-010 | Edge Case | P2 | Daemon shutdown with networks | Draft |
| S002-EC-011 | Edge Case | P2 | Docker disappears at runtime | Draft |
| S002-EC-012 | Edge Case | P1 | Subnet collision | Draft |
| S002-EC-013 | Edge Case | P2 | Subnets exhausted | Draft |
| S002-EC-014 | Edge Case | P2 | Invalid network name | Draft |
| S002-SC-001 | Success | P1 | Default network creation verified | Draft |
| S002-SC-002 | Success | P1 | Named network auto-allocation | Draft |
| S002-SC-003 | Success | P1 | Status accuracy | Draft |
| S002-SC-004 | Success | P1 | List completeness | Draft |
| S002-SC-005 | Success | P1 | Named network destroy | Draft |
| S002-SC-006 | Success | P1 | Default network destroy+recreate | Draft |
| S002-SC-007 | Success | P1 | Connected container rejection | Draft |
| S002-SC-008 | Success | P1 | Idempotency | Draft |
| S002-SC-009 | Success | P1 | Collision-aware allocation | Draft |
| S002-SC-010 | Success | P1 | No docker CLI shelling | Draft |
| S002-SC-011 | Success | P1 | Bridge commands unaffected | Draft |

## Out of Scope

- **Container lifecycle management** (start, stop, attach, exec)
- **Connecting/disconnecting individual containers** to/from a network
- **Agent-side API exposure** — network management endpoints are host-only
- **TLS or authentication** on the host socket
- **Network policy rules** (per-container allow/deny) — handled by bridge + nftables
- **DNS configuration** within networks
- **IPv6 support**
- **Automated bridge-up before network create**

## Cross-Spec Dependencies

- **Depends on:** [S001](../001-bridge-management/index.md) (bridge must be up before network creation — S002-FR-004)
- **Required by:** [S006](../006-http-proxy/index.md), [S007](../007-dns-filter/index.md), [S008](../008-docker-manager/index.md)

## Shared Types (outcall-api)

### Constants

```rust
pub const NETWORK_PREFIX: &str = "outcall-";
pub const DEFAULT_NETWORK_NAME: &str = "outcall-default";
pub const SUBNET_BLOCK: &str = "10.200.0.0/16";
pub const DEFAULT_SUBNET: &str = "10.200.0.0/24";
pub const DEFAULT_GATEWAY: &str = "10.200.0.1";
```

### Types

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NetworkCreateRequest {
    pub name: Option<String>,
    pub subnet: Option<String>,
    pub gateway: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NetworkCreateResult {
    pub network_id: String,
    pub name: String,
    pub created: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NetworkStatus {
    pub exists: bool,
    pub network_id: Option<String>,
    pub name: String,
    pub subnet: Option<String>,
    pub gateway: Option<String>,
    pub containers: Vec<NetworkContainer>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NetworkContainer {
    pub name: String,
    pub ipv4_address: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NetworkDestroyRequest {
    pub name: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NetworkDestroyResult {
    pub name: String,
    pub destroyed: bool,
}
```
