# S003 Success Criteria

| ID | Criterion |
|----|-----------|
| S003-SC-001 | A rule with `action: allow` and a matching condition results in `decision: allow` with the correct `matched_rule` ID. |
| S003-SC-002 | A rule with `action: block` and a matching condition results in `decision: block` with the correct `matched_rule` ID. |
| S003-SC-003 | A request that matches no rule results in `decision: block` with `matched_rule: null`. |
| S003-SC-004 | Given files `00-base.yaml`, `25-team.yaml`, `50-custom.yaml`, rules from `00-base.yaml` are always evaluated first. |
| S003-SC-005 | Given two rules where both conditions match, the first rule in evaluation order determines the decision. |
| S003-SC-006 | `outcalld` refuses to start when any rule file contains an invalid CEL expression, logging the file, rule ID, and error. |
| S003-SC-007 | Definition variables (`$name`) are correctly expanded in rule conditions before CEL evaluation. |
| S003-SC-008 | An enrich hook script runs, its JSON output is merged into `run.context`, and subsequent rules can reference the enriched values. |
| S003-SC-009 | `POST /api/v1/rules/reload` loads new rules atomically; old rules remain active until the new set passes validation. |
| S003-SC-010 | CEL evaluation for a single request completes within 50ms under normal load. |
| S003-SC-011 | Rules with `log: true` produce structured audit log entries containing rule ID, decision, timestamp, and context summary. |
| S003-SC-012 | Existing `outcall bridge *` and `outcall network *` commands continue to work unchanged. |
| S003-SC-013 | Agent rule requests are queued as `pending` and do not affect evaluation until a host operator approves them. |
| S003-SC-014 | All six context variable namespaces (`network`, `http`, `dns`, `docker`, `run`, `agent`) are accessible in CEL expressions. |
