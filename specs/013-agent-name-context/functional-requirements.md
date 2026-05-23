# S013: Agent-Name Rule Context — Functional Requirements

## FR-001: AgentContext type in outcall-api

**Requirement:** Add `AgentContext` to `outcall-api/src/lib.rs` with a `name: String` field.

**Rationale:** The CEL evaluation context needs a structured agent identity type.
`AgentContext` is optional because resolution may fail (see EC-001, EC-002).

**Acceptance:** `AgentContext` is serializable, cloneable, and has a `Default` impl.

## FR-002: `agent` field in EvalContext

**Requirement:** Add `pub agent: Option<AgentContext>` to `EvalContext` in `outcall-api/src/lib.rs`.

**Rationale:** `EvalContext` is the top-level CEL context struct. Adding `agent` exposes
the resolved identity to CEL expressions without breaking existing callers (Option field
with Default means `None` for backwards-compatible JSON serialization).

**Acceptance:** Existing `EvalContext` JSON roundtrip tests still pass (no new required fields).

## FR-003: SO_PEERCRED to container name resolution

**Requirement:** In the Unix socket accept path (where `PermissionRequest` arrives from the agent),
read `SO_PEERCRED` to obtain the caller's PID. Resolve PID → container IP via `/proc/<PID>/status`,
then call `DockerManager::lookup_container_name_by_ip(ip)` to get the container name.

**Rationale:** `SO_PEERCRED` is the only reliable way to identify the calling container on a
Unix domain socket. The existing `container_name_for_ip` already handles the Docker API lookup.

**Acceptance:** A request from agent container `foobar-1` produces container name `"foobar-1"`.

## FR-004: Agent name derived from container name

**Requirement:** Strip the trailing `-N` (where N is a decimal number) from the container name
to derive `agent_name`. If the container name has no trailing `-N` pattern, use the full
container name as the agent name.

**Rationale:** The established naming convention uses `-N` suffix for replica indexing.
Agents expect `agent.name == "foobar"` to match all replicas (`foobar-1`, `foobar-2`, etc.).

**Acceptance:**
- `"foobar-1"` → `name = "foobar"`
- `"my-agent-12"` → `name = "my-agent"`
- `"standalone"` → `name = "standalone"` (no suffix to strip)

## FR-005: `agent.name` exposed in CEL

**Requirement:** In `rules/engine.rs`, add `agent.name` as a CEL variable binding so that
CEL expressions can reference `agent.name` directly.

**Rationale:** CEL evaluation requires explicit variable bindings. Adding `agent.name`
to the evaluation context makes it available in all rule conditions.

**Acceptance:** A rule with condition `agent.name == "foobar"` evaluates correctly for
container `foobar-1`.

## FR-006: DockerContext.image remains unchanged

**Requirement:** The existing `DockerContext.image` field must not be modified or deprecated.
Both `docker.image` and `agent.name` coexist in the evaluation context.

**Rationale:** `docker.image` identifies the container image; `agent.name` identifies the
agent identity. They serve different purposes and both are needed.

**Acceptance:** Existing rules using `docker.image == "..."` continue to work unchanged.

## EC-001: SO_PEERCRED not available (non-Unix socket)

If the rule evaluation request arrives over a non-Unix socket (e.g., HTTP over TCP),
`SO_PEERCRED` is not available. In this case, `AgentContext` should be `None`.

**Handling:** `build_eval_context` receives a reference to the raw socket (or a flag)
indicating whether SO_PEERCRED is available. If not, `agent: None`.

## EC-002: Container IP not found in DockerManager

If `SO_PEERCRED` returns a valid PID but the container IP cannot be resolved
(`/proc/<PID>/status` missing or DockerManager has no entry for that IP),
`AgentContext` should be `None`.

**Handling:** `container_name_for_ip` already returns `Option<String>`. Propagate `None`
through the resolution chain.

## EC-003: Agent name with no trailing `-N`

**Handling:** The strip function should only strip when the suffix matches `-[0-9]+$`.
If no match, return the full name. This preserves container names that genuinely
do not follow the `-N` pattern.

## EC-004: Async resolution does not block rule evaluation

**Handling:** The PID → container name resolution is synchronous (reads `/proc` and
checks an in-memory `HashMap` in DockerManager). It must not do an async Docker API
call during rule evaluation. `lookup_container_name_by_ip` on `DockerManager` is
already `async` but returns instantly from the cache. Ensure the cache is populated
on container join (S008) so that rule evaluation never hits a Docker API delay.