# S003: Rule Engine

| Field | Value |
|-------|-------|
| Spec | S003 |
| Feature | Rule Engine |
| Date | 2026-04-21 |
| Status | Draft |
| Author | @marktopper |

## Overview

The rule engine is the core policy evaluation system in Outcall. Every request
from an agent container -- network connections, HTTP requests, DNS lookups,
Docker API calls, command executions -- passes through the rule engine, which
evaluates it against a set of YAML-defined rules and returns an allow or block
decision.

Rules are written as YAML files in a rules directory. Each file contains an
optional `definitions` section for reusable variables and a `rules` list where
each rule has a CEL (Common Expression Language) condition, an action
(`allow`, `block`, or `enrich`), and optional metadata. Files are evaluated in
filename sort order. Within a file, rules are evaluated top-to-bottom. The
first `allow` or `block` match wins. If no rule matches, the default policy is
**always BLOCK** -- this is not configurable.

Enrich hooks (`action: enrich`) are special rules that execute host-side
scripts to populate `run.context` with additional data before the allow/block
decision is reached. They do not terminate evaluation.

Static analysis runs at startup: CEL parse errors abort the daemon, while
warnings (e.g., unused definitions) are logged but allow startup to proceed.

### Rule file format

```yaml
version: "1"
definitions:
  is_github: network.hostname == "github.com"

rules:
  - id: "allow-github-api"
    condition: |
      $is_github &&
      http.method in ["GET", "POST"] &&
      http.path.startsWith("/api/v3")
    action: allow

  - id: "block-force-push"
    condition: run.tool == "git" && "-f" in run.flags
    action: block
    log: true
```

### Context variables

The CEL evaluation context exposes these variable namespaces:

| Namespace | Variables | Source |
|-----------|-----------|--------|
| `network` | `hostname`, `ip`, `port`, `protocol` | Connection metadata from bridge/nftables |
| `http` | `method`, `path`, `host`, `headers`, `body_size` | HTTP request inspection |
| `dns` | `query`, `record_type` | DNS query interception |
| `docker` | `image`, `command`, `volumes`, `env_keys`, `capabilities` | Docker API request inspection |
| `run` | `tool`, `args`, `flags`, `cwd`, `context` | Command execution metadata |

### Agent rule requests

Agents can submit rule requests through the agent-facing API. These requests
queue for host operator review and approval. The host operator can approve,
deny, or modify requested rules before they take effect.

## User Scenarios

S003-US-001 [P1] As a host operator, I want to write YAML rules that allow specific network access for agent containers so that agents can reach required APIs while everything else is blocked.

S003-US-002 [P1] As a host operator, I want rules evaluated in a predictable order so that I can reason about which rule will match a given request.

S003-US-003 [P1] As a host operator, I want the system to block all traffic by default so that I never accidentally leave a permissive gap.

S003-US-004 [P2] As a host operator, I want to define reusable variables in my rule files so that I can avoid repeating complex conditions.

S003-US-005 [P2] As a host operator, I want enrich hooks so that I can call host-side scripts to gather context before making allow/block decisions.

S003-US-006 [P1] As a host operator, I want static analysis at startup so that typos and invalid CEL expressions are caught before the daemon accepts traffic.

S003-US-007 [P2] As a host operator, I want to reload rules without restarting the daemon so that I can update policy on the fly.

S003-US-008 [P2] As a host operator, I want to inspect loaded rules and test expressions from the CLI so that I can debug policy.

S003-US-009 [P3] As an agent, I want to request additional rules so that I can ask the host operator for access I need.

S003-US-010 [P1] As a host operator, I want to review and approve or deny agent rule requests so that agents cannot self-authorize.

## Requirements Summary

| ID | Type | Priority | Title | Status |
|----|------|----------|-------|--------|
| S003-FR-001 | Functional | P1 | YAML rule file format | Draft |
| S003-FR-002 | Functional | P1 | Version field required | Draft |
| S003-FR-003 | Functional | P1 | Rule structure | Draft |
| S003-FR-004 | Functional | P1 | CEL expression evaluation | Draft |
| S003-FR-005 | Functional | P1 | Context variable schema | Draft |
| S003-FR-006 | Functional | P2 | Definition variable substitution | Draft |
| S003-FR-007 | Functional | P1 | Filename sort order | Draft |
| S003-FR-008 | Functional | P1 | First match wins | Draft |
| S003-FR-009 | Functional | P1 | Default BLOCK policy | Draft |
| S003-FR-010 | Functional | P1 | Default policy not configurable | Draft |
| S003-FR-011 | Functional | P2 | Enrich hook execution | Draft |
| S003-FR-012 | Functional | P2 | Enrich hook timeout | Draft |
| S003-FR-013 | Functional | P2 | Enrich populates run.context | Draft |
| S003-FR-014 | Functional | P1 | Static analysis at startup | Draft |
| S003-FR-015 | Functional | P1 | Startup abort on errors | Draft |
| S003-FR-016 | Functional | P1 | Startup continue on warnings | Draft |
| S003-FR-017 | Functional | P1 | CEL parsing via cel-interpreter | Draft |
| S003-FR-018 | Functional | P1 | YAML parsing via serde_yaml | Draft |
| S003-FR-019 | Functional | P1 | Rule evaluation response | Draft |
| S003-FR-020 | Functional | P1 | Log flag support | Draft |
| S003-FR-021 | Functional | P2 | Rule reload without restart | Draft |
| S003-FR-022 | Functional | P2 | File watch or API trigger reload | Draft |
| S003-FR-023 | Functional | P2 | Atomic rule reload | Draft |
| S003-FR-024 | Functional | P3 | Agent rule request submission | Draft |
| S003-FR-025 | Functional | P3 | Agent rule request queue | Draft |
| S003-FR-026 | Functional | P2 | Host approval of agent requests | Draft |
| S003-FR-027 | Functional | P1 | Rules directory configuration | Draft |
| S003-FR-028 | Functional | P1 | Rule ID uniqueness | Draft |
| S003-FR-029 | Functional | P1 | Structured logging for decisions | Draft |
| S003-FR-030 | Functional | P1 | Typed errors | Draft |
| S003-FR-031 | Functional | P1 | Evaluation latency budget | Draft |
| S003-FR-032 | Functional | P2 | Rule priority/weight field | Draft |
| S003-FR-033 | Functional | P1 | Bridge-up prerequisite | Draft |
| S003-FR-034 | Functional | P2 | CLI rule inspection commands | Draft |
| S003-FR-035 | Functional | P2 | CLI expression test command | Draft |
| S003-FR-036 | Functional | P1 | Host API endpoints | Draft |
| S003-FR-037 | Functional | P2 | Rule description field | Draft |
| S003-FR-038 | Functional | P1 | Empty rules directory | Draft |
| S003-FR-039 | Functional | P2 | Enrich hook script validation | Draft |
| S003-FR-040 | Functional | P1 | Evaluation must be synchronous per request | Draft |
| S003-AS-001 | Acceptance | P1 | Allow rule matches request | Draft |
| S003-AS-002 | Acceptance | P1 | Block rule matches request | Draft |
| S003-AS-003 | Acceptance | P1 | No rule matches (default block) | Draft |
| S003-AS-004 | Acceptance | P1 | First match wins ordering | Draft |
| S003-AS-005 | Acceptance | P2 | Definition variable expansion | Draft |
| S003-AS-006 | Acceptance | P2 | Enrich hook populates context | Draft |
| S003-AS-007 | Acceptance | P1 | Startup CEL parse error aborts | Draft |
| S003-AS-008 | Acceptance | P1 | Startup unused definition warns | Draft |
| S003-AS-009 | Acceptance | P2 | Hot reload via API | Draft |
| S003-AS-010 | Acceptance | P2 | Hot reload via file watch | Draft |
| S003-AS-011 | Acceptance | P1 | Multi-file filename sort order | Draft |
| S003-AS-012 | Acceptance | P3 | Agent submits rule request | Draft |
| S003-AS-013 | Acceptance | P2 | Host approves rule request | Draft |
| S003-AS-014 | Acceptance | P2 | Host denies rule request | Draft |
| S003-AS-015 | Acceptance | P1 | CLI lists loaded rules | Draft |
| S003-AS-016 | Acceptance | P2 | CLI tests expression against mock context | Draft |
| S003-AS-017 | Acceptance | P1 | Log flag produces audit log entry | Draft |
| S003-AS-018 | Acceptance | P1 | Daemon not running (CLI) | Draft |
| S003-IF-001 | Interface | P1 | POST /api/v1/rule/evaluate | Draft |
| S003-IF-002 | Interface | P1 | GET /api/v1/rules | Draft |
| S003-IF-003 | Interface | P1 | GET /api/v1/rule/:id | Draft |
| S003-IF-004 | Interface | P2 | POST /api/v1/rules/reload | Draft |
| S003-IF-005 | Interface | P2 | POST /api/v1/rule/test | Draft |
| S003-IF-006 | Interface | P3 | POST /api/v1/agent/rule-request | Draft |
| S003-IF-007 | Interface | P2 | GET /api/v1/rule-requests | Draft |
| S003-IF-008 | Interface | P2 | POST /api/v1/rule-request/:id/approve | Draft |
| S003-IF-009 | Interface | P2 | POST /api/v1/rule-request/:id/deny | Draft |
| S003-IF-010 | Interface | P1 | CLI commands | Draft |
| S003-IF-011 | Interface | P1 | CLI output format | Draft |
| S003-IF-012 | Interface | P1 | YAML rule file schema | Draft |
| S003-IF-013 | Interface | P1 | Context variable types | Draft |
| S003-EC-001 | Edge Case | P1 | Invalid CEL expression | Draft |
| S003-EC-002 | Edge Case | P1 | Missing context variable | Draft |
| S003-EC-003 | Edge Case | P2 | Enrich hook timeout | Draft |
| S003-EC-004 | Edge Case | P2 | Enrich hook nonexistent script | Draft |
| S003-EC-005 | Edge Case | P2 | Enrich hook non-zero exit | Draft |
| S003-EC-006 | Edge Case | P1 | Empty rules directory | Draft |
| S003-EC-007 | Edge Case | P1 | Duplicate rule ID across files | Draft |
| S003-EC-008 | Edge Case | P1 | Unsupported version field | Draft |
| S003-EC-009 | Edge Case | P2 | Undefined definition variable | Draft |
| S003-EC-010 | Edge Case | P2 | Circular definition reference | Draft |
| S003-EC-011 | Edge Case | P2 | Rule file with only definitions | Draft |
| S003-EC-012 | Edge Case | P2 | CEL expression returns non-boolean | Draft |
| S003-EC-013 | Edge Case | P1 | Rules directory does not exist | Draft |
| S003-EC-014 | Edge Case | P2 | File permissions prevent reading | Draft |
| S003-EC-015 | Edge Case | P2 | Reload with invalid new rules | Draft |
| S003-EC-016 | Edge Case | P2 | Concurrent evaluation during reload | Draft |
| S003-EC-017 | Edge Case | P3 | Agent requests rule for already-allowed action | Draft |
| S003-EC-018 | Edge Case | P1 | Malformed YAML file | Draft |
| S003-EC-019 | Edge Case | P2 | Very large rule set (performance) | Draft |
| S003-EC-020 | Edge Case | P2 | Non-YAML files in rules directory | Draft |
| S003-SC-001 | Success | P1 | Allow rule evaluated correctly | Draft |
| S003-SC-002 | Success | P1 | Block rule evaluated correctly | Draft |
| S003-SC-003 | Success | P1 | Default block on no match | Draft |
| S003-SC-004 | Success | P1 | Filename sort order verified | Draft |
| S003-SC-005 | Success | P1 | First match wins verified | Draft |
| S003-SC-006 | Success | P1 | Static analysis catches errors | Draft |
| S003-SC-007 | Success | P2 | Definition expansion works | Draft |
| S003-SC-008 | Success | P2 | Enrich hook executes and populates context | Draft |
| S003-SC-009 | Success | P2 | Hot reload applies new rules | Draft |
| S003-SC-010 | Success | P1 | Evaluation latency under budget | Draft |
| S003-SC-011 | Success | P1 | Audit log entries for logged rules | Draft |
| S003-SC-012 | Success | P1 | Bridge and network commands unaffected | Draft |
| S003-SC-013 | Success | P2 | Agent rule requests queue correctly | Draft |
| S003-SC-014 | Success | P1 | All context variables accessible in CEL | Draft |

## Out of Scope

- **nftables rule generation** -- the bridge spec (S001) handles the nftables layer; S003 evaluates policy at the application level
- **Container lifecycle management** -- starting/stopping agent containers
- **TLS or authentication** on the host socket
- **Rule versioning or rollback** -- only the current file set is active
- **Multi-tenancy** -- all rules apply to all agent containers on the same bridge
- **Custom CEL functions** -- only built-in CEL operators and standard functions
- **GUI for rule management** -- CLI and API only

## Cross-Spec Dependencies

- **Depends on:** [S001](../001-bridge-management/index.md) (bridge must be up for rule evaluation to be meaningful -- S003-FR-033)
- **Depends on:** [S002](../002-network-management/index.md) (network context variables populated from network management layer)
- **Required by:** [S004](../004-agent-api/index.md) (agent permission requests flow through the rule engine), [S005](../005-agent-shim/index.md), [S006](../006-http-proxy/index.md), [S007](../007-dns-filter/index.md), [S009](../009-dynamic-rules/index.md)

## Shared Types (outcall-api)

### Constants

```rust
pub const RULES_DIR_DEFAULT: &str = "/etc/outcall/rules.d";
pub const RULE_FILE_EXTENSION: &str = ".yaml";
pub const RULE_VERSION_SUPPORTED: &str = "1";
pub const EVALUATION_TIMEOUT_MS: u64 = 50;
pub const ENRICH_HOOK_TIMEOUT_MS: u64 = 5000;
```

### New types (added to outcall-api)

Note: `RuleAction`, `RuleRequestStatus`, `Verdict`, and `RuleRequest` are already
defined in S000. The types below extend the shared library for rule engine support.

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RuleFile {
    pub version: String,
    pub definitions: Option<HashMap<String, String>>,
    pub rules: Vec<Rule>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Rule {
    pub id: String,
    pub condition: String,
    pub action: RuleAction,          // from S000
    pub priority: Option<i32>,       // S003-FR-032: default 100, lower = higher priority
    pub log: Option<bool>,
    pub description: Option<String>,
    pub enrich: Option<EnrichConfig>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EnrichConfig {
    pub script: String,
    pub timeout_ms: Option<u64>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EvaluateRequest {
    pub context: EvaluationContext,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EvaluationContext {
    pub network: Option<NetworkContext>,
    pub http: Option<HttpContext>,
    pub dns: Option<DnsContext>,
    pub docker: Option<DockerContext>,
    pub run: Option<RunContext>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NetworkContext {
    pub hostname: Option<String>,
    pub ip: String,
    pub port: u16,
    pub protocol: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HttpContext {
    pub method: String,
    pub path: String,
    pub host: String,
    pub headers: HashMap<String, String>,
    pub body_size: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DnsContext {
    pub query: String,
    pub record_type: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DockerContext {
    pub image: String,
    pub command: Vec<String>,
    pub volumes: Vec<String>,
    pub env_keys: Vec<String>,
    pub capabilities: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RunContext {
    pub tool: String,
    pub args: Vec<String>,
    pub flags: Vec<String>,
    pub cwd: String,
    pub context: HashMap<String, serde_json::Value>,
}

/// Internal rule engine result. Translated to Verdict (S000) for agent API responses.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EvaluateResult {
    pub decision: Decision,
    pub matched_rule: Option<String>,
    pub file: Option<String>,
    pub logged: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Decision {
    Allow,
    Block,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RuleSummary {
    pub id: String,
    pub file: String,
    pub action: RuleAction,
    pub condition_preview: String,
    pub description: Option<String>,
}

/// Agent-submitted rule request (via agent API).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RuleRequestSubmission {
    pub description: String,
    pub requested_access: String,
    pub suggested_condition: Option<String>,
}

/// Server-side stored rule request (enriched with ID, timestamp, status).
/// Host API returns this via ApiResponse<StoredRuleRequest>.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StoredRuleRequest {
    pub id: String,
    pub submitted_at: String,
    pub status: RuleRequestStatus,   // from S000
    pub description: String,
    pub requested_access: String,
    pub suggested_condition: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ReloadResult {
    pub files_loaded: usize,
    pub rules_loaded: usize,
    pub warnings: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TestExpressionRequest {
    pub expression: String,
    pub context: EvaluationContext,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TestExpressionResult {
    pub result: bool,
    pub error: Option<String>,
}
```
