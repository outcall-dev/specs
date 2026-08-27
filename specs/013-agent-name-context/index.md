# S013: Agent-Name Rule Context

| Field | Value |
|-------|-------|
| Spec | S013 |
| Feature | Agent-Name CEL Context |
| Date | 2026-05-08 |
| Status | Implemented |
| Author | @marktopper |

## Overview

The CEL evaluation context exposes `agent.name` so operators can gate policy by
the daemon-managed container that originated a request. The container-facing
Unix API resolves Linux `SO_PEERCRED` PID to an immutable Docker container ID.
The HTTP proxy and DNS filter resolve the source IP through a lifecycle-managed
Docker identity index. All three enforcement paths reject requests when a
managed identity cannot be proven.

## Background

The agent naming convention strips the trailing `-N` from container names:
- Container `foobar-1` → agent name `foobar`
- Container `foobar-2` → agent name `foobar`
- Container `my-agent-12` → agent name `my-agent`

The `SO_PEERCRED` socket option provides the caller's host-namespace PID. Proxy
and DNS traffic instead carries a bridge source IP. `DockerManager` validates
both forms against the `managed-by=outcalld` label and maintains an IP identity
index from Docker lifecycle events.

## User Scenarios

S013-US-001 [P1] As a host operator, I want to write rules that allow specific agents
by name so that I can enforce per-agent access policies.

S013-US-002 [P1] As a host operator, I want `agent.name` exposed in the CEL
context so that existing rule authors can use it immediately.

S013-US-003 [P2] As a host operator, I want to debug which agent made a request
by inspecting the `agent.name` field in evaluation logs.

## Requirements Summary

| ID | Type | Priority | Title | Status |
|----|------|----------|-------|--------|
| S013-FR-001 | Functional | P1 | AgentContext type in outcall-api | Implemented (`outcall-api/src/lib.rs:158`) |
| S013-FR-002 | Functional | P1 | `agent` field in EvalContext | Implemented (`outcall-api/src/lib.rs:163`) |
| S013-FR-003 | Functional | P1 | SO_PEERCRED to immutable container identity | Implemented |
| S013-FR-004 | Functional | P1 | Agent name derived from container name | Implemented (`agent_api/mod.rs:derive_agent_name`) |
| S013-FR-005 | Functional | P1 | `agent.name` exposed in CEL | Implemented for proxy + agent_api paths |
| S013-FR-006 | Functional | P1 | DockerContext.image remains unchanged | Implemented |
| S013-IF-001 | Interface | P1 | AgentContext struct in outcall-api | Implemented |
| S013-FR-007 | Functional | P1 | Network enforcement rejects unidentified peers | Implemented |
| S013-IF-002 | Interface | P2 | DockerManager identity lookup interfaces | Implemented |
| S013-IF-003 | Interface | P1 | Document `agent.name` in docs/rules.md | Implemented |
| S013-AS-001 | Acceptance | P1 | Agent name matches all replicas | Implemented |
| S013-AS-002 | Acceptance | P1 | Different agent does not match | Implemented |
| S013-AS-003 | Acceptance | P1 | Missing peer credentials rejected | Implemented |
| S013-AS-004 | Acceptance | P1 | Unknown container identity rejected | Implemented |
| S013-AS-005 | Acceptance | P1 | Existing EvalContext consumers unchanged | Implemented |
| S013-AS-006 | Acceptance | P2 | Agent name combines with other context | Implemented |
| S013-AS-007 | Acceptance | P2 | Name without replica suffix preserved | Implemented |
| S013-EC-001 | Edge Case | P1 | SO_PEERCRED unavailable | Implemented (agent API rejects request) |
| S013-EC-002 | Edge Case | P1 | Container identity not found | Implemented (enforcement path rejects request) |
| S013-EC-003 | Edge Case | P2 | Agent name with no trailing `-N` | Implemented (regex `-[0-9]+$` only; tested) |
| S013-EC-004 | Edge Case | P1 | Async resolution does not block rule evaluation | Implemented (event-maintained cache with authoritative fallback) |
| S013-EC-005 | Edge Case | P2 | Very long container name | Implemented |
| S013-EC-006 | Edge Case | P1 | Concurrent identities remain isolated | Implemented |
| S013-EC-007 | Edge Case | P1 | Identity lookup is bounded | Implemented |
| S013-EC-008 | Edge Case | P1 | Peer PID exits during lookup | Implemented |
| S013-EC-009 | Edge Case | P1 | Docker manager not initialized | Implemented |
| S013-SC-001 | Success | P1 | `agent.name` accessible in CEL rules | Implemented |
| S013-SC-002 | Success | P1 | Rule `agent.name == "foobar"` matches foobar-1 and foobar-2 | Implemented (covered by `derive_agent_name` unit tests + full-test.sh 5.8/5.9) |
| S013-SC-003 | Success | P1 | AgentContext does not break existing EvalContext consumers | Implemented (Default-derived Optional; existing tests green) |
| S013-SC-004 | Success | P1 | SO_PEERCRED resolution path | Implemented |
| S013-SC-005 | Success | P2 | Rule docs include agent namespace | Implemented |
| S013-SC-006 | Success | P1 | Replica suffix derivation | Implemented |

The Unix API and network services use different transport identities but
converge on the same validated Docker container name and `derive_agent_name`
helper. A synthetic host-side rule evaluation may omit `agent`; a request on a
container-facing enforcement path may not.

## Cross-Spec Dependencies

- **Depends on:** [S003](../003-rule-engine/index.md) (CEL context structure, evaluation path)
- **Depends on:** [S008](../008-docker-manager/index.md) (`lookup_container_name_by_ip` exists)
- **Required by:** Operator rules that need per-agent gating (no downstream specs currently reference this)

## Shared Types (outcall-api)

```rust
/// Agent identity resolved from a daemon-validated managed container.
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct AgentContext {
    pub name: String,  // e.g. "foobar" from "foobar-1"
}
```

```rust
/// Full CEL evaluation context (S003, extended with agent).
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct EvalContext {
    pub network: Option<NetworkContext>,
    pub http: Option<HttpContext>,
    pub dns: Option<DnsContext>,
    pub docker: Option<DockerContext>,
    pub run: Option<RunContext>,
    pub agent: Option<AgentContext>,  // S013-FR-002
}
```

## CEL Usage

Once implemented, operators can write:

```yaml
rules:
  - id: "allow-foobar-db"
    condition: |
      agent.name == "foobar" &&
      network.port == 5432
    action: allow

  - id: "block-bar-agents-ssh"
    condition: agent.name == "bar" && network.port == 22
    action: block
```
