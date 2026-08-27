# S003 Interface Requirements

Unless stated otherwise, `/api/v1/...` endpoints are available only on the
operator-owned host Unix socket. Agent endpoints use the separately mounted
agent Unix socket and require a valid host-derived container identity and
check-in session.

### S003-IF-001 POST /api/v1/rule/evaluate [P1]

Evaluate a typed context against the loaded rules. The host endpoint first
requires the managed bridge to be up.

```json
{
  "context": {
    "network": {
      "hostname": "github.com",
      "ip": "140.82.121.4",
      "port": 443,
      "protocol": "tcp"
    },
    "http": {
      "method": "GET",
      "path": "/api/v3/repos",
      "host": "github.com",
      "headers": {},
      "body_size": 0
    },
    "agent": { "name": "review-agent" }
  }
}
```

Success returns `ApiResponse<EvaluateResult>`:

```json
{
  "success": true,
  "data": {
    "decision": "allow",
    "matched_rule": "allow-github-api",
    "file": "00-base.yaml",
    "logged": false
  }
}
```

No match returns a successful `block` decision with `matched_rule` and `file`
set to `null`. A bridge or evaluation precondition failure returns
`success: false` and no data.

### S003-IF-002 GET /api/v1/rules [P1]

Return `ApiResponse<Vec<RuleSummary>>` in effective evaluation order: ascending
priority, with filename and source position preserving order among equal
priorities.

```json
{
  "success": true,
  "data": [{
    "id": "allow-github-api",
    "file": "00-base.yaml",
    "action": "allow",
    "condition_preview": "network.hostname == \"github.com\"",
    "description": "Allow GitHub API access"
  }]
}
```

### S003-IF-003 GET /api/v1/rule/:id [P1]

Return `ApiResponse<RuleDetail>` with the fully expanded CEL condition.

```json
{
  "success": true,
  "data": {
    "id": "allow-github-api",
    "condition": "network.hostname == \"github.com\"",
    "action": "allow",
    "log": false,
    "description": "Allow GitHub API access",
    "priority": 100
  }
}
```

An unknown ID returns `success: false` with `rule not found: "<id>"`.

### S003-IF-004 POST /api/v1/rules/reload [P2]

Trigger an atomic disk reload. The request has no body.

```json
{
  "success": true,
  "data": {
    "files_loaded": 3,
    "rules_loaded": 12,
    "warnings": []
  }
}
```

Validation failure returns `success: false`; the previous rule snapshot and
derived bridge policy remain active.

### S003-IF-005 POST /api/v1/rule/test [P2]

Compile and evaluate one CEL expression without changing active policy.

```json
{
  "expression": "network.hostname == \"github.com\"",
  "context": {
    "network": {
      "hostname": "github.com",
      "ip": "140.82.121.4",
      "port": 443,
      "protocol": "tcp"
    }
  }
}
```

The response is `ApiResponse<TestExpressionResult>`. CEL syntax or runtime
errors are returned in `data.error` with `data.result` set to `false`.

### S003-IF-006 POST /v1/requests/rules [P3]

Submit a complete rule file on the agent socket:

```json
{
  "rule_file": "version: \"1\"\nrules:\n  - id: allow-pypi\n    condition: 'network.hostname == \"pypi.org\"'\n    action: allow\n"
}
```

The daemon validates the file before durably queuing it. Success is HTTP 201
with `ApiResponse<RuleRequestResponse>`:

```json
{
  "success": true,
  "data": {
    "id": "rr-aabbcc112233",
    "status": "pending",
    "reason": null
  }
}
```

`GET /v1/requests/rules/:id` lets the submitting container inspect its own
request status. Requests belonging to another container are not disclosed.

### S003-IF-007 GET /api/v1/requests/rules [P2]

Return pending requests on the host socket as
`ApiResponse<Vec<PendingRuleRequest>>`. Each item includes `id`, the verified
`container_id`, the submitted `rule_file`, `status`, and optional `reason`.
Completed requests are retained for bounded durable audit state but omitted
from this queue view.

### S003-IF-008 POST /api/v1/requests/rules/:id/approve [P2]

Approve a pending request. The request has no body. Outcall creates
`agent-<id>.yaml` atomically with mode 0600, reloads policy, and only then marks
the request approved.

```json
{
  "success": true,
  "data": {
    "id": "rr-aabbcc112233",
    "rules_loaded": 12
  }
}
```

Unknown or completed IDs return HTTP 404 or 409. A write, reload, or durable
state failure returns HTTP 500 and rolls policy back where possible.

### S003-IF-009 POST /api/v1/requests/rules/:id/reject [P2]

Reject a pending request with an optional bounded reason:

```json
{ "reason": "Use the existing package mirror rule." }
```

Success returns `ApiResponse<RejectRuleResult>` containing the request `id`.
The reason is limited to 1024 bytes and may not be empty or contain control
characters.

### S003-IF-010 CLI commands [P1]

```text
outcall rules reload
outcall requests list
outcall requests approve <request-id>
outcall requests reject <request-id> [--reason <text>]
```

All commands accept the global `--socket <path>` option. Raw rule inspection
and CEL testing remain available through S003-IF-002, S003-IF-003, and
S003-IF-005; dedicated CLI wrappers are tracked separately by S003-FR-035.

### S003-IF-011 CLI output format [P1]

The CLI prints concise human-readable results and writes errors to stderr.
Representative success output is:

```text
Reloaded 12 rule(s) from 3 file(s).
Rule request "rr-aabbcc112233" approved; 12 rule(s) loaded.
Rule request "rr-aabbcc112233" rejected.
```

`requests list` prints `ID`, `CONTAINER`, and `STATUS`, or
`No pending rule requests.` Exit status is zero on success and non-zero on
transport or API failure.

### S003-IF-012 YAML rule file schema [P1]

```yaml
version: "1"
definitions:                     # Optional, file-scoped CEL expressions.
  <name>: <CEL expression>
rules:                           # Optional; defaults to an empty list.
  - id: <string>                 # Required and globally unique.
    condition: <CEL expression>  # Required and must evaluate to bool to match.
    action: <allow|block>        # enrich is reserved and currently rejected.
    log: <boolean>               # Optional; default false.
    description: <string>        # Optional.
    priority: <integer>          # Optional; lower runs first, default 100.
    egress:                      # Optional and valid only for allow rules.
      mode: <proxy|direct_ip>
      ports: [<port>, ...]       # direct_ip only; defaults to 80 and 443.
      allow_private_ips: false   # Explicit opt-in for internal destinations.
```

Both `.yaml` and `.yml` files are accepted. Unknown fields, unsafe `enrich`,
and unimplemented `egress.mode: intercept` settings are rejected.

### S003-IF-013 Context variable types [P1]

| Variable | CEL Type | Notes |
|----------|----------|-------|
| `network.hostname` | `string` | Empty when unresolved or absent |
| `network.ip` | `string` | Empty when absent |
| `network.port` | `int` | Zero when absent |
| `network.protocol` | `string` | Usually `tcp` or `udp` |
| `http.method` | `string` | Uppercase for proxy requests |
| `http.path` | `string` | Includes leading `/` when present |
| `http.host` | `string` | Validated request authority |
| `http.headers` | `map(string, string)` | Header names are normalized |
| `http.body_size` | `int` | Bytes |
| `dns.query` | `string` | Normalized queried name |
| `dns.record_type` | `string` | For example `A` or `AAAA` |
| `docker.image` | `string` | Full image reference |
| `docker.command` | `list(string)` | Command and arguments |
| `docker.volumes` | `list(string)` | Requested mount paths |
| `docker.env_keys` | `list(string)` | Names only, never values |
| `docker.capabilities` | `list(string)` | Requested Linux capabilities |
| `run.tool` | `string` | Tool identifier |
| `run.args` | `list(string)` | Positional arguments |
| `run.flags` | `list(string)` | Flags including dashes |
| `run.cwd` | `string` | Working directory |
| `run.context` | `map(string, dyn)` | Typed request metadata |
| `agent.name` | `string` | Host-verified managed agent name |
