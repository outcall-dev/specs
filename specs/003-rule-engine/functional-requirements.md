# S003 Functional Requirements

### YAML rule file format

S003-FR-001 [P1] `outcalld` **MUST** load rule files from a configurable rules directory. Each file **MUST** have a `.yaml` or `.yml` extension. Files with other extensions **MUST** be ignored.

S003-FR-002 [P1] Each rule file **MUST** contain a `version` field at the top level. The only supported value is `"1"`. An unsupported or missing version **MUST** cause a startup error.

S003-FR-003 [P1] Each rule in the `rules` list **MUST** have:
S003-FR-003.a `id` -- a string identifier unique across all loaded rule files
S003-FR-003.b `condition` -- a CEL expression that evaluates to a boolean
S003-FR-003.c `action` -- `allow` or `block`. The `enrich` value is reserved
for a future broker-mediated design and **MUST** be rejected by the current
runtime.

S003-FR-037 [P2] Each rule **MAY** have a `description` field containing a human-readable explanation. This field is for documentation and CLI display only; it has no effect on evaluation.

S003-FR-020 [P1] Each rule **MAY** have a `log: true` field. When a rule with `log: true` matches, `outcalld` **MUST** emit a structured log entry containing the rule ID, source file, and decision. Secret-bearing headers, bodies, and environment values **MUST NOT** be logged.

### CEL expression evaluation

S003-FR-004 [P1] `outcalld` **MUST** evaluate rule conditions using CEL (Common Expression Language). Conditions **MUST** be parsed and compiled at load time, not at evaluation time.

S003-FR-017 [P1] CEL evaluation **MUST** use the `cel-interpreter` crate.

S003-FR-005 [P1] The CEL evaluation context **MUST** expose the following variable namespaces:
S003-FR-005.a `network` -- `hostname` (string, optional), `ip` (string), `port` (int), `protocol` (string)
S003-FR-005.b `http` -- `method` (string), `path` (string), `host` (string), `headers` (map<string,string>), `body_size` (int)
S003-FR-005.c `dns` -- `query` (string), `record_type` (string)
S003-FR-005.d `docker` -- `image` (string), `command` (list<string>), `volumes` (list<string>), `env_keys` (list<string>), `capabilities` (list<string>)
S003-FR-005.e `run` -- `tool` (string), `args` (list<string>), `flags` (list<string>), `cwd` (string), `context` (map<string,any>). Note: the `run.context` map is populated from agent-provided `metadata` key-value pairs (see S004-FR-013).
S003-FR-005.f `agent` -- `name` (string), populated from host-verified managed-container identity rather than agent-supplied headers.
S003-FR-005.g Each namespace is optional. The implementation **MUST** inject absent namespaces as objects with all fields set to their zero values (empty string, 0, empty list/map) so that CEL field access succeeds without an evaluation error.

S003-FR-040 [P1] The rule set **MUST** be immutable during evaluation of a single request. Concurrent evaluations from multiple containers against the same immutable rule set are permitted and expected. Rule reloads **MUST** swap the entire rule set atomically (new requests see the new set, in-flight evaluations complete against the old set).

### Definition variable substitution

S003-FR-006 [P2] Rule files **MAY** contain a `definitions` section mapping names to CEL sub-expressions. In rule conditions, `$name` references **MUST** be replaced with the corresponding definition expression (parenthesized) before CEL compilation.

S003-FR-006.a Definitions **MUST** be expanded recursively -- a definition **MAY** reference another definition.
S003-FR-006.b An undefined `$name` reference **MUST** cause a startup error.
S003-FR-006.c A circular reference chain **MUST** be detected and cause a startup error.
S003-FR-006.d Definitions are scoped to the file that declares them. A definition in one file is not visible to rules in another file.

### Evaluation order

S003-FR-007 [P1] Rule files **MUST** be loaded in filename lexicographic sort order. Within a file, rules **MUST** be evaluated in the order they appear in the `rules` list. This is the base evaluation order when no `priority` field (S003-FR-032) is present. When priorities are used, priority takes precedence and filename/position is the tiebreaker within the same priority level.

S003-FR-008 [P1] Evaluation **MUST** follow first-match-wins semantics. The first rule whose condition evaluates to `true` with action `allow` or `block` determines the decision. Evaluation **MUST** stop after the first terminal match.

S003-FR-009 [P1] If no `allow` or `block` rule matches, the decision **MUST** be `block`.

S003-FR-010 [P1] The default BLOCK policy **MUST NOT** be configurable. There is no `default_action` setting.

S003-FR-032 [P2] Rules **MAY** include an optional numeric `priority` field (integer, default 100). When present, rules are sorted globally by priority (ascending — lower number = higher priority). Filename/position order is the tiebreaker within the same priority level. This means a `priority: 1` rule in `99-custom.yaml` evaluates before a `priority: 50` rule in `00-base.yaml`. Rules without a `priority` field are assigned the default (100) and sort among themselves by filename/position.

### Enrich hooks (deferred)

S003-FR-011 [P3, Deferred] A future enrich implementation may gather
additional context through a declared host-broker tool. It **MUST NOT** execute
project-provided scripts in the privileged daemon process or container.

S003-FR-012 [P3, Deferred] Broker-mediated enrich calls will require bounded
timeouts and bounded input/output before this action can be enabled.

S003-FR-013 [P3, Deferred] Broker-mediated enrich output will be a bounded JSON
object merged into `run.context` for subsequent rules.

S003-FR-039 [P3, Deferred] Enrich tool declarations will be validated against
the host resource registry before a rule set is accepted.

S003-FR-041 [P1] Until the broker-mediated enrich design is implemented,
static analysis **MUST** reject `action: enrich` and any `enrich` configuration.
The daemon **MUST NOT** silently skip or execute such a rule.

### Static analysis at startup

S003-FR-014 [P1] `outcalld` **MUST** perform static analysis on all rule files at startup before accepting any traffic.

S003-FR-015 [P1] Static analysis **MUST** treat the following as errors that abort startup:
S003-FR-015.a CEL parse/compile failure
S003-FR-015.b Missing or unsupported `version` field
S003-FR-015.c Duplicate rule IDs across all files
S003-FR-015.d Undefined `$name` variable references
S003-FR-015.e Circular definition references
S003-FR-015.f Malformed YAML (parse failure)

S003-FR-016 [P1] Static analysis **MUST** treat the following as warnings that are logged but do not prevent startup:
S003-FR-016.a Unused definitions (defined but never referenced)
S003-FR-016.b Rule files with a `definitions` section but no rules

### YAML parsing

S003-FR-018 [P1] YAML parsing **MUST** use the `serde` and `serde_yaml` crates. The rule file schema **MUST** be represented as Rust types with `Serialize` and `Deserialize` derives.

### Evaluation response

S003-FR-019 [P1] Every evaluation **MUST** return a result containing:
S003-FR-019.a The decision (`allow` or `block`)
S003-FR-019.b The ID of the matched rule, or `null` if the default block applied
S003-FR-019.c The filename of the matched rule, or `null` if the default block applied
S003-FR-019.d Whether the match was logged

### Rule reload

S003-FR-021 [P2] `outcalld` **MUST** support reloading rules without restarting the daemon.

S003-FR-022 [P2] Reload **MAY** be triggered by a host API endpoint or by file system change detection. At minimum, the API trigger **MUST** be supported.

S003-FR-023 [P2] Reload **MUST** be atomic: the new rule set is fully parsed and validated before it replaces the old set. If the new set fails validation, the old rules remain active and the reload returns an error.

### Agent rule requests

S003-FR-024 [P3] Authenticated managed agents **MAY** submit a complete versioned YAML rule file through the agent-facing API. The daemon **MUST** validate its schema, semantics, rule IDs, definition expansion, and CEL before queuing it.

S003-FR-025 [P3] Rule requests **MUST** be queued with status `pending`. They are not evaluated or applied until a host operator acts on them.

S003-FR-026 [P2] The host operator **MUST** be able to approve or reject pending rule requests via the host API. Approving a request atomically writes a mode-0600 rule file to the rules directory and triggers a policy reload. Rejecting a request **MAY** include a bounded audit reason.

### Configuration and integration

S003-FR-027 [P1] The rules directory **MUST** be configurable via `--rules-dir` flag. The default is `/etc/outcall/rules.d`.

S003-FR-028 [P1] Rule IDs **MUST** be unique across all loaded files. Duplicate IDs **MUST** be a startup error.

S003-FR-029 [P1] `outcalld` **MUST** emit structured info-level entries when a matched rule has `log: true`, and **SHOULD** emit debug-level entries for other matches and evaluation completion. Match entries **MUST** include the rule ID and decision; the tracing subscriber supplies the timestamp.

S003-FR-030 [P1] Rule loading, compilation, and reload errors **MUST** preserve actionable context, including the affected file and rule ID where available, and **MUST NOT** expose a partially loaded rule set.

S003-FR-031 [P1] CEL evaluation for a single request **MUST** complete within 50ms under normal conditions. If evaluation exceeds this budget, `outcalld` **MUST** log a warning.

S003-FR-033 [P1] The host evaluation endpoint **MUST** verify that the bridge is up before evaluating requests. If the bridge is not up, it **MUST** return an error rather than an allow decision. Internal enforcement points operate only after daemon startup has established the bridge base policy.

S003-FR-034 [P2] The `outcall` CLI **MUST** expose `rules reload` and host-operator `requests list`, `requests approve`, and `requests reject` commands over the host socket.

S003-FR-035 [P2] A future `outcall rules test` command **MUST** accept a CEL expression and a JSON context, evaluate the expression, and print the result. A `rules list` command **MUST** expose the existing list API without changing evaluation order.

S003-FR-036 [P1] Rule management endpoints **MUST** be served on the host unix socket only. The agent-facing socket **MUST** only expose the rule request submission endpoint (S003-IF-006).

S003-FR-038 [P1] If the rules directory is absent or contains no `.yaml`/`.yml` files, the daemon **MUST** start successfully with an empty rule set. All evaluations **MUST** return the default block decision.
