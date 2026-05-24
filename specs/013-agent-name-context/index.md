# S013: Agent-Name Rule Context

| Field | Value |
|-------|-------|
| Spec | S013 |
| Feature | Agent-Name CEL Context |
| Date | 2026-05-08 |
| Status | Implemented (proxy + agent_api paths both populate `agent.name`); S013-FR-003 strict-SO_PEERCRED enforcement remains partial — see [issue #4](https://github.com/outcall-dev/outcall/issues/4) |
| Author | @marktopper |

## Overview

The rule engine's CEL evaluation context currently exposes `docker.image` but not
the container name or agent identity. This prevents operators from writing rules
that gate on which agent container made the request — for example, "allow
`foo-1` to reach port 5432 but block `bar-3`."

This spec adds `agent.name` to the CEL evaluation context by resolving the
caller's PID to a container IP using `SO_PEERCRED`, then looking up the
container name via `container_name_for_ip` (already implemented in
`DockerManager`).

## Background

The agent naming convention strips the trailing `-N` from container names:
- Container `foobar-1` → agent name `foobar`
- Container `foobar-2` → agent name `foobar`
- Container `my-agent-12` → agent name `my-agent`

The `SO_PEERCRED` socket option provides the caller's PID. The existing
`DockerManager::lookup_container_name_by_ip` resolves an IP to container name.

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
| S013-FR-003 | Functional | P1 | SO_PEERCRED to container name resolution | Partial — proxy path uses peer-IP lookup; agent_api shim path tracked in issue #4 |
| S013-FR-004 | Functional | P1 | Agent name derived from container name | Implemented (`agent_api/mod.rs:derive_agent_name`) |
| S013-FR-005 | Functional | P1 | `agent.name` exposed in CEL | Implemented for proxy + agent_api paths |
| S013-FR-006 | Functional | P1 | DockerContext.image remains unchanged | Implemented |
| S013-IF-001 | Interface | P1 | AgentContext struct in outcall-api | Implemented |
| S013-IF-002 | Interface | P2 | Extend DockerManager::build_eval_context | Implemented (proxy uses `lookup_container_name_by_ip`) |
| S013-IF-003 | Interface | P1 | Document `agent.name` in docs/rules.md | Implemented |
| S013-EC-001 | Edge Case | P1 | SO_PEERCRED not available (non-Unix socket) | Implemented (proxy returns `None`) |
| S013-EC-002 | Edge Case | P1 | Container IP not found in DockerManager | Implemented (`resolve_agent_name` returns `None`) |
| S013-EC-003 | Edge Case | P2 | Agent name with no trailing `-N` | Implemented (regex `-[0-9]+$` only; tested) |
| S013-EC-004 | Edge Case | P1 | Async resolution does not block rule evaluation | Implemented (one Docker label-filtered list per connection; cached) |
| S013-SC-001 | Success | P1 | `agent.name` accessible in CEL rules | Implemented |
| S013-SC-002 | Success | P1 | Rule `agent.name == "foobar"` matches foobar-1 and foobar-2 | Implemented (covered by `derive_agent_name` unit tests + full-test.sh 5.8/5.9) |
| S013-SC-003 | Success | P1 | AgentContext does not break existing EvalContext consumers | Implemented (Default-derived Optional; existing tests green) |

> **Implementation note (2026-05-10, release prep):** S013 was originally
> drafted around the agent_api shim's `SO_PEERCRED` path. During v0.1
> release prep the proxy/HTTPS path was identified as a parallel enrichment
> site and now resolves `agent.name` via TCP peer-IP →
> `DockerManager::lookup_container_name_by_ip` (filters on
> `managed-by=outcalld`). Both paths converge on the same `derive_agent_name`
> helper. FR-003 strict SO_PEERCRED in the agent_api path remains tracked in
> [issue #4](https://github.com/outcall-dev/outcall/issues/4) — it does not
> block v0.1 because real apt/curl/HTTPS traffic transits the proxy path.

## Cross-Spec Dependencies

- **Depends on:** [S003](../003-rule-engine/index.md) (CEL context structure, evaluation path)
- **Depends on:** [S008](../008-docker-manager/index.md) (`lookup_container_name_by_ip` exists)
- **Required by:** Operator rules that need per-agent gating (no downstream specs currently reference this)

## Shared Types (outcall-api)

```rust
/// Agent identity resolved from SO_PEERCRED + container lookup.
/// None when resolution fails (non-Unix socket, container not found).
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