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

## FR-003: SO_PEERCRED to immutable container identity

**Requirement:** In the Unix socket accept path (where `PermissionRequest` arrives from the agent),
read `SO_PEERCRED` to obtain the caller's host-namespace PID. Resolve the PID's
cgroup to a Docker container ID, inspect that exact ID, require the
`managed-by=outcalld` label, and use the inspected container name.

**Rationale:** An agent-supplied name or mutable IP is not sufficient identity
for the shared Unix socket. The kernel credential and immutable Docker ID bind
the request to the actual caller.

**Acceptance:** A request from agent container `foobar-1` produces container name `"foobar-1"`.

## FR-007: Network enforcement requires managed identity

**Requirement:** The HTTP proxy and DNS filter must map each peer source IP to
a currently managed Docker container before rule evaluation. Missing identity,
Docker lookup failure, or an unhealthy identity source must reject the request
with HTTP 403 or DNS REFUSED. These paths must not evaluate generic rules with
`agent: None`.

**Acceptance:** A request from an unmanaged bridge peer is rejected even when a
generic allow rule would otherwise match.

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

## Edge cases

Identity failure, suffix handling, concurrency, and bounded lookup behavior are
defined once in [edge-cases.md](./edge-cases.md).
