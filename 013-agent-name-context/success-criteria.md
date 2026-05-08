# S013: Agent-Name Rule Context — Success Criteria

## S013-SC-001: agent.name accessible in CEL rules

**Test:** Write a YAML rule file with condition `agent.name == "test-agent"` and submit
a mock `PermissionRequest` from a container named `test-agent-1`. The CEL evaluator
must bind `agent.name` to `"test-agent"`.

**Validation:** `cargo test -p outcall-api eval_context` includes a roundtrip test for
`EvalContext` with `agent` field. All existing tests pass.

---

## S013-SC-002: Rule agent.name == "foobar" matches foobar-1 and foobar-2

**Test:** Two requests, one from `foobar-1` and one from `foobar-2`, both evaluated
with condition `agent.name == "foobar"`. Both return `true`.

**Validation:** Integration test in `outcalld/tests/` sends requests from two different
agent containers and verifies the correct agent name is resolved.

---

## S013-SC-003: AgentContext does not break existing EvalContext consumers

**Test:** JSON serialization of `EvalContext { network: Some(...), docker: None, agent: None }`
produces the same output as before the `agent` field was added. No new required fields.

**Validation:** `cargo test -p outcall-api` passes. `serde_json::to_string` of default
`EvalContext` is valid JSON with no `agent` key (Option field omitted when None).

---

## S013-SC-004: SO_PEERCRED resolution path implemented

**Test:** Unix socket connection from agent container → `SO_PEERCRED` → `/proc/<PID>/status`
→ container IP → `lookup_container_name_by_ip` → agent name. All steps present and
correctly chained.

**Validation:** `cargo build --workspace` succeeds. `cargo clippy --all-targets --all-features`
produces no new warnings. Existing socket credential tests (if any) still pass.

---

## S013-SC-005: docs/rules.md updated with agent namespace

**Test:** `docs/rules.md` (or `outcalld/src/docs/rules.md`) includes `agent` in the
context variables table with description of `name` field.

**Validation:** `rg "agent.name" docs/` or `rg "agent.name" outcalld/src/docs/` returns
at least one reference to the new namespace.

---

## S013-SC-006: Agent name derivation strips trailing -N correctly

**Test:** Unit tests for the derivation function cover:
- `"foobar-1"` → `"foobar"`
- `"my-agent-12"` → `"my-agent"`
- `"standalone"` → `"standalone"`
- `"agent-0"` → `"agent"`

**Validation:** `cargo test -p outcall-api agent_context` (or equivalent) passes all cases.