# S010 Edge Cases

| ID | Scenario | Expected Behavior |
|----|----------|-------------------|
| S010-EC-001 | Dashboard accessed on macOS dev (no bridge) | Dashboard loads. Bridge section shows "down". Other sections show empty/unavailable state. No crash. |
| S010-EC-002 | No containers running | Container list is empty. Dashboard shows "0 containers" in overview. |
