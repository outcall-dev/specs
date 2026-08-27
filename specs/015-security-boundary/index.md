# S015: Security Boundary and Rule Enforcement

| Field | Value |
|-------|-------|
| Spec | S015 |
| Feature | Security Boundary Verification |
| Date | 2026-05-14 |
| Status | Implemented |
| Author | @marktopper |

## Overview

This spec proves that Outcall's network enforcement happens **outside and
around** the agent container, not inside it. On native Linux this is the host
network namespace; on macOS it is Docker Desktop's Linux runtime. The agent
cannot bypass rules by modifying its internal configuration because its only
network is backed by the inspected Outcall bridge where nftables rules apply.

## Security Model

```
┌─────────────────────────────────────────────────────────────┐
│                        HOST                                  │
│  ┌─────────────────────────────────────────────────────┐   │
│  │           nftables FORWARD chain (DROP)             │   │
│  │  ┌─────────────────────────────────────────────┐   │   │
│  │  │           outcall0 bridge                    │   │   │
│  │  │                                              │   │   │
│  │  │   ┌──────────┐        ┌──────────────┐     │   │   │
│  │  │   │  veth    │◄──────►│   agent1     │     │   │   │
│  │  │   │  (host)  │        │  (namespace) │     │   │   │
│  │  │   └──────────┘        └──────────────┘     │   │   │
│  │  │                                              │   │   │
│  │  └─────────────────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

**Key principle**: Traffic from the agent namespace MUST pass through the host
bridge's FORWARD chain. The agent cannot bypass this because:
1. The veth pair connects the namespace to the bridge
2. The daemon accepts only a Docker `bridge` network backed by its exact bridge interface
3. Bridge netfilter MUST be enabled before container creation
4. All forwarded traffic hits the daemon-managed nftables rules
5. The agent has no second Docker network, host networking, or added capabilities
6. Docker `HostConfig.NetworkMode` is pinned to the same inspected managed network
7. The agent process uses a numeric non-root UID/GID

## Acceptance Scenarios

### AS-001: iptables Modification Inside Container Does Not Bypass Rules
**Given** an agent container is running with outbound TCP blocked
**When** the agent runs `iptables -A OUTPUT -d 1.1.1.1 -j ACCEPT` inside its namespace
**Then** outbound TCP to 1.1.1.1 is **still blocked**
**Because** enforcement happens on the host bridge, not inside the container

### AS-002: Flushing Container iptables Does Not Bypass Rules
**Given** an agent container is running with outbound TCP blocked
**When** the agent runs `iptables -F` inside its namespace
**Then** outbound TCP to 1.1.1.1 is **still blocked**
**Because** host nftables rules are independent of container iptables

### AS-003: Agent Cannot Modify Host nftables
**Given** an agent container is running
**When** the agent tries to run `nft add rule inet outcall forward accept`
**Then** the command **fails with permission denied**
**Because** the agent namespace cannot access host nftables

### AS-004: Trusted Repository Access
**Given** rules allow apt traffic to trusted repositories
**When** the agent runs `apt-get update` from a trusted repo
**Then** the traffic is **allowed**

### AS-005: Untrusted Repository Blocked
**Given** rules block traffic to untrusted repositories
**When** the agent tries to access an untrusted repo
**Then** the traffic is **blocked**

### AS-006: Host CLI Isolation
**Given** an agent container is running
**When** the agent tries to access a Docker/containerd control socket, undeclared host file, or host process
**Then** all attempts **fail**
**Because** control-socket and ancestor mounts are denied, undeclared host resources are absent, and the agent is isolated in its own namespace

The project workspace and any operator-declared Docker volumes are intentional
exceptions: once mounted, their contents are container files and are not
mediated per filesystem operation. `.outcall` is separately over-mounted
read-only.

### AS-007: Forged Network Rejected
**Given** a Docker network has an `outcall-` name but uses the default, host, or a different bridge
**When** a managed container creation request selects it
**Then** `outcalld` rejects the request before Docker creates the container

### AS-008: Netfilter Preflight Fails Closed
**Given** either bridge netfilter hook is disabled
**When** the CLI or daemon API attempts a managed recipe launch
**Then** creation is refused and no agent container remains

### AS-009: Network Services Require Managed Peer Identity
**Given** a process that is not an Outcall-managed container can reach the proxy or DNS listener
**When** it submits an HTTP, HTTPS CONNECT, or DNS request
**Then** the request is rejected before rule evaluation
**Because** generic allow rules cannot authorize an unidentified network peer

### AS-010: Private Destinations Require Explicit Opt-In
**Given** an allowed hostname resolves to a private, loopback, link-local, or otherwise restricted address
**When** the matched rule does not set `egress.allow_private_ips: true`
**Then** DNS and proxy forwarding fail closed without connecting to that address

### AS-011: Container Control Mounts Cannot Be Shadowed
**Given** a create request includes a caller-controlled bind or named volume
**When** its destination equals or covers the agent socket, helper shim, or resolver path
**Then** `outcalld` rejects the request before Docker creation

### AS-012: Host Container Lifecycle Is Outcall-Scoped
**Given** a host container lacks the exact `managed-by=outcalld` label
**When** an operator calls the Outcall inspect, stop, or remove endpoint for it
**Then** the request is rejected without exposing details or changing the container

### AS-013: Daemon Container Uses Explicit Capabilities
**Given** the CLI starts the trusted `outcalld` container
**When** Docker evaluates its host configuration
**Then** Docker's default capabilities are dropped; `NET_ADMIN` and
`NET_BIND_SERVICE` are added; Linux Unix-socket transport additionally adds only
`CHOWN` and `DAC_OVERRIDE`; Docker-exec transport omits those two;
`no-new-privileges` is set; and process creation is bounded

## E2E Test Inventory

| Test | File | Validates |
|------|------|-----------|
| Managed hardening | `scripts/test-managed-container-security.sh` | Labels, non-root user, capabilities, rootfs, limits, DNS/proxy, mounts |
| Network isolation | `scripts/test-container-isolation.sh` | Bridge identity, default drop, host/peer blocking |
| Netfilter preflight | `scripts/test-netfilter-preflight.sh` | AS-008, CLI and daemon fail-closed behavior |
| Bind source/destination validation | `outcalld/src/bind_mount.rs` tests | AS-006/AS-011, direct, ancestor, malformed, symlink, and control-shadow mounts |
| Managed network validation | `outcalld/src/managed_network.rs` tests | AS-007 |
| Managed Docker configuration | `outcalld/src/docker/` tests | Network mode, hardening, helper preflight, managed label, image references |
| Daemon launch configuration | `outcall/src/daemon_commands.rs` tests | Capability drop/add, no-new-privileges, init, PID limit, and rules-directory validation |

## Implementation Notes

- nftables rules are applied in the **Linux enforcement namespace**
- The agent runs in a **separate network namespace** connected via veth pair
- The bridge (`outcall0`) is the enforcement point
- Container iptables rules only affect traffic **inside** the container namespace
- Runtime nftables rules affect all traffic **forwarded** through the bridge
- HTTP proxy variables improve protocol visibility, but the bridge firewall is the non-bypassable boundary
- Host tools and files outside explicit mounts require the tokenized broker and matching rules
- The daemon is a trusted host-control component because it owns `NET_ADMIN` and
  the Docker socket; the agent receives neither the socket nor the daemon host API
