# S013: Agent-Name Rule Context — Edge Cases

## S013-EC-001: SO_PEERCRED not available (non-Unix socket)

**Condition:** Rule evaluation request arrives over a TCP socket instead of a Unix domain socket.

**Expected behavior:** `EvalContext.agent` is `None`. No error returned to caller.
Rule evaluation proceeds with remaining context fields.

**Test:** Send a request via HTTP (TCP) and verify `agent` is absent from context JSON.

---

## S013-EC-002: Container IP not found in DockerManager

**Condition:** `SO_PEERCRED` returns a valid PID, but the container's IP is not in
`DockerManager`'s container-name-by-IP map (e.g., container started before the cache
was populated, or a system process not tracked by Outcall).

**Expected behavior:** `EvalContext.agent` is `None`. No error logged at ERROR level
(INFO is acceptable). Rule evaluation proceeds.

**Test:** Mock DockerManager to return `None` for a known PID → verify agent is `None`.

---

## S013-EC-003: Container name with no trailing `-N` suffix

**Condition:** Container name is `standalone` or `myagent` with no numeric suffix.

**Expected behavior:** `agent.name` equals the full container name (`standalone`, `myagent`).
No error or warning emitted.

**Test:** Container named `standalone` → `agent.name == "standalone"` evaluates true.

---

## S013-EC-004: Container name with trailing `-0` (edge of suffix stripping)

**Condition:** Container name ends in `-0` (e.g., `agent-0`).

**Expected behavior:** The suffix `-0` is stripped, resulting in `agent.name = "agent"`.
This is correct behavior per the `-[0-9]+$` regex — `-0` is a valid numeric suffix.

**Test:** Container named `agent-0` → `agent.name == "agent"` evaluates true.

---

## S013-EC-005: Very long container name

**Condition:** Container name is a valid Docker name up to 128 characters.

**Expected behavior:** `agent.name` is derived correctly (possibly with suffix stripped).
No truncation or buffer overflow.

**Test:** Container named `a` + 120 other chars + `-1` → name derived correctly.

---

## S013-EC-006: Concurrent rule evaluations with different agent identities

**Condition:** Two requests arrive simultaneously from different agents (foobar-1 and bar-1).
`build_eval_context` resolves agent identity for each concurrently.

**Expected behavior:** Each `EvalContext` contains the correct agent name for its request.
No race condition in the resolution chain.

**Test:** Parallel requests from two different agents → each gets correct `agent.name`.

---

## S013-EC-007: Agent name resolution does not block rule evaluation latency budget

**Condition:** Rule evaluation must complete within 50ms (S003-EVAL-TIMEOUT).

**Expected behavior:** Agent name resolution adds ≤ 1ms to the evaluation path (in-memory
cache lookup only). If resolution takes longer, it should timeout and set agent to `None`.

**Test:** Time `build_eval_context` with warm cache — must be less than 1ms on a cold run.

---

## S013-EC-008: PID does not exist when reading `/proc/<PID>/status`

**Condition:** The PID from `SO_PEERCRED` has already exited between the accept and the
time we read `/proc/<PID>/status`.

**Expected behavior:** `EvalContext.agent` is `None`. No error raised.
The request still gets a verdict, just without agent identity.

**Test:** Send request from a quickly-exiting subprocess → verify graceful fallback.

---

## S013-EC-009: DockerManager not yet initialized

**Condition:** `build_eval_context` is called before DockerManager has populated its
container-name-by-IP map.

**Expected behavior:** `EvalContext.agent` is `None`. No error raised.
DockerManager's cache will be populated as containers join (S008).

**Test:** Daemon starts and immediately receives a rule evaluation request → agent is `None`.
