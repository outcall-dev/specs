# S013: Agent-Name Rule Context — Interface Requirements

## S013-IF-001: AgentContext struct in outcall-api

**File:** `application/outcall-api/src/lib.rs`

```rust
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct AgentContext {
    pub name: String,
}
```

**Where to add:** Near `DockerContext` (line ~138 of `lib.rs`).

**Changes:**
1. Add `AgentContext` struct after `DockerContext`
2. Add `pub agent: Option<AgentContext>` to `EvalContext`
3. Ensure JSON serialization is backwards-compatible (Option field, None = not present)

## S013-IF-002: DockerManager identity lookup interfaces

**Files:** `application/outcalld/src/agent_api/` and
`application/outcalld/src/docker/identity.rs`

The Unix listener attaches a `UnixPeerCred` containing Linux `SO_PEERCRED` PID.
`lookup_container_by_pid` maps its cgroup to an immutable container ID and
requires the managed label. `lookup_container_name_by_ip` serves proxy and DNS
from the lifecycle-managed identity index, with an authoritative Docker-list
fallback on cache miss. Both return failure/absence separately so enforcement
callers can reject unknown peers.

## S013-IF-003: Document `agent.name` in docs/rules.md

**File:** `application/outcalld/src/docs/rules.md` (or `docs/rules.md` at repo root)

**Changes:** Add `agent` namespace entry to the context variables table.

| Namespace | Variables | Source |
|-----------|-----------|--------|
| `agent` | `name` | Resolved from a daemon-validated managed container (S013) |

**Example rule:**
```yaml
- id: "allow-foobar-db"
  condition: "agent.name == \"foobar\" && network.port == 5432"
  action: allow
```
