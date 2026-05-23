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

## S013-IF-002: Extend DockerManager::build_eval_context

**File:** `application/outcalld/src/agent_api/mod.rs`

**Changes to `build_eval_context`:**
1. Add a `socket: &impl AsRawFd` parameter (or similar) to receive the peer credential
2. Read `SO_PEERCRED` from the socket: `libc::getsockopt(fd, SOL_SOCKET, SO_PEERCRED, ...)`
3. Read `/proc/<PID>/status` → `grep "^NSpid:"` to get container PID namespace → map to container IP
4. Call `docker_manager.lookup_container_name_by_ip(&ip)` to get container name
5. Strip trailing `-N` to derive `agent_name`
6. Populate `EvalContext { agent: Some(AgentContext { name: agent_name }), ..ctx }`

**Note:** The current `build_eval_context` signature is `fn build_eval_context(req: &PermissionRequest) -> EvalContext`.
This function is called from the axum handler that has access to the `Extension<SharedDocker>` extractor.
The Unix socket peer credential must be obtained from the request's socket, not passed separately.

**Alternative approach:** The handler at `agent_api/mod.rs:360` (`axum::post(submit_permission)`) receives
a `Request<Body>`. The underlying socket is accessible via `request.extensions().get::<axum::extract::connect_info::ConnectInfo<ConnectedStream>>()`.
For Unix sockets, `ConnectInfo::connect_info` exposes the raw socket descriptor.

**Simplest path:** Add `&State<DockerManager>` as a parameter to `build_eval_context` and read peer cred
via `tokio::task::spawn_blocking` + `libc::getsockopt`. The function already runs in an async context.

## S013-IF-003: Document `agent.name` in docs/rules.md

**File:** `application/outcalld/src/docs/rules.md` (or `docs/rules.md` at repo root)

**Changes:** Add `agent` namespace entry to the context variables table.

| Namespace | Variables | Source |
|-----------|-----------|--------|
| `agent` | `name` | Resolved from SO_PEERCRED + container lookup (S013) |

**Example rule:**
```yaml
- id: "allow-foobar-db"
  condition: "agent.name == \"foobar\" && network.port == 5432"
  action: allow
```