# S003 Edge Cases

| ID | Scenario | Expected Behavior |
|----|----------|-------------------|
| S003-EC-001 | Invalid CEL expression in rule file | Startup error. Daemon aborts with file name, rule ID, and parse error details. |
| S003-EC-002 | Rule condition references a context variable from an absent namespace (e.g., `http.method` on a DNS-only request) | The namespace is injected with zero values, so field access does not error. Conditions requiring a non-empty value normally evaluate to `false`; evaluation continues. |
| S003-EC-003 | Future broker-mediated enrich call exceeds its timeout | Deferred. The broker design must fail closed with bounded execution before enrich can be enabled. |
| S003-EC-004 | Future enrich tool is not declared or unavailable | Deferred. Rule-set validation must reject undeclared resources; runtime failures must not add context or authorization. |
| S003-EC-005 | Future enrich tool returns an error | Deferred. The error must not add context or authorization and must be audit logged without leaking secrets. |
| S003-EC-006 | Rules directory exists but contains zero `.yaml` files | Daemon starts successfully. All evaluations return the default block decision. |
| S003-EC-007 | Two rule files contain rules with the same ID | Startup error. Daemon aborts, naming both files and the duplicate ID. |
| S003-EC-008 | Rule file has `version: "2"` (unsupported) | Startup error. Daemon aborts, naming the file and the unsupported version. |
| S003-EC-009 | A `$name` reference in a condition has no matching definition | Startup error. Daemon aborts, naming the file, rule ID, and undefined variable. |
| S003-EC-010 | Definitions form a circular reference (`a` references `$b`, `b` references `$a`) | Startup error. Daemon aborts, naming the file and the cycle chain. |
| S003-EC-011 | Rule file has a `definitions` section but no `rules` section | Startup warning. File is loaded (definitions available for that file scope) but contributes no rules. |
| S003-EC-012 | CEL expression evaluates to a non-boolean value (e.g., returns a string) | Treated as a non-match (equivalent to `false`). A warning is logged with the rule ID and the actual return type. |
| S003-EC-013 | Rules directory path does not exist | Daemon starts with an empty rule set and logs that no rule files were found. Default deny remains active. |
| S003-EC-014 | A rule file exists but is not readable (permissions) | Startup error. Daemon aborts, naming the unreadable file. |
| S003-EC-015 | Reload triggered but new rules have validation errors | Reload fails. Old rules remain active. Error response includes the validation details. |
| S003-EC-016 | Evaluation requests arrive during an active reload | Old rules remain active until the new set is fully validated and swapped atomically. In-flight evaluations complete against the old set. |
| S003-EC-017 | Agent requests a rule for access that is already allowed | Request is queued normally. The host operator can deny it as redundant. |
| S003-EC-018 | Rule file contains invalid YAML (not parseable) | Startup error. Daemon aborts, naming the file and the YAML parse error. |
| S003-EC-019 | Rule set contains 1000+ rules across many files | The engine **MUST** still meet the 50ms evaluation latency budget under normal conditions. Evaluations over budget emit a warning. |
| S003-EC-020 | Rules directory contains `.json`, `.txt`, or other non-YAML files | Files without `.yaml` or `.yml` extensions are silently ignored. |
