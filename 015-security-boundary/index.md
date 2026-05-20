# S015: Security Boundary and Rule Enforcement

| Field | Value |
|-------|-------|
| Spec | S015 |
| Feature | Security Boundary Verification |
| Date | 2026-05-14 |
| Status | Implemented |
| Author | @marktopper |

## Overview

This spec proves that Outcall's security enforcement happens **outside and
around** the agent container, not inside it. The agent cannot bypass rules by
modifying its internal configuration because all traffic flows through the host
bridge where nftables rules are applied.

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
2. All forwarded traffic hits nftables rules on the host
3. The agent namespace has no direct route to external interfaces

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
**When** the agent tries to access Docker socket, host filesystem, or host processes
**Then** all attempts **fail**
**Because** the agent is isolated in its own namespace

## E2E Test Inventory

| Test | File | Validates |
|------|------|-----------|
| Security Boundary | `14-security-boundary.sh` | AS-001, AS-002, AS-003 |
| Trusted Repos | `15-trusted-repos.sh` | AS-004, AS-005 |
| Hostname/IP Allowlist | `16-hostname-ip-allowlist.sh` | Allowed vs blocked hosts/IPs |
| Host CLI Restrictions | `17-host-cli-restrictions.sh` | AS-006 |

## Implementation Notes

- nftables rules are applied in the **host network namespace**
- The agent runs in a **separate network namespace** connected via veth pair
- The bridge (`outcall0`) is the enforcement point
- Container iptables rules only affect traffic **inside** the container namespace
- Host nftables rules affect all traffic **forwarded** through the bridge
