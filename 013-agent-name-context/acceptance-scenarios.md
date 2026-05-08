# S013: Agent-Name Rule Context — Acceptance Scenarios

## S013-AS-001: Agent name matches all replicas

**Given** containers `foobar-1` and `foobar-2` are running as agents
**And** the rule engine has evaluated a request from `foobar-1`
**When** the CEL expression `agent.name == "foobar"` is evaluated
**Then** the result is `true` (matches foobar-1)

**Given** containers `foobar-1` and `foobar-2` are running as agents
**And** the rule engine has evaluated a request from `foobar-2`
**When** the CEL expression `agent.name == "foobar"` is evaluated
**Then** the result is `true` (matches foobar-2)

## S013-AS-002: Agent name does not match different agent

**Given** container `foobar-1` is running as agent
**And** container `bar-1` is running as agent
**When** the CEL expression `agent.name == "foobar"` is evaluated on a request from `bar-1`
**Then** the result is `false`

## S013-AS-003: Agent name absent when SO_PEERCRED unavailable

**Given** the rule engine evaluates a request from a non-Unix socket context
**When** `build_eval_context` is called
**Then** `EvalContext.agent` is `None`
**And** the rule engine evaluates using all other context fields without agent

## S013-AS-004: Agent name absent when container not found

**Given** a request arrives from a PID whose IP is not in DockerManager's container map
**When** `build_eval_context` resolves the agent name
**Then** `EvalContext.agent` is `None`
**And** no error is raised to the caller

## S013-AS-005: Existing EvalContext consumers unchanged

**Given** existing code creates an `EvalContext` with only `network` or `run` fields set
**When** the code runs with the new `agent` field added
**Then** serialization and deserialization behave identically to before
**And** no new required fields are introduced (all new fields are `Option<T>`)

## S013-AS-006: agent.name usable with other context fields

**Given** a rule with condition `agent.name == "foobar" && network.port == 5432`
**When** the condition is evaluated against a request from `foobar-1` on port 5432
**Then** the result is `true`

**Given** a rule with condition `agent.name == "foobar" && network.port == 5432`
**When** the condition is evaluated against a request from `foobar-1` on port 8080
**Then** the result is `false`

## S013-AS-007: Agent name with no trailing replica suffix

**Given** a container named `standalone` makes a request
**When** `agent.name` is resolved
**Then** `agent.name` equals `"standalone"` (no suffix to strip, full name used)