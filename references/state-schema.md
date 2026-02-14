# State File Schema

## Location

`.claude/autonomous-loop.json`

JSON format chosen over YAML/markdown because models are less likely to corrupt structured JSON during updates (per Anthropic's long-running agent research).

## Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `version` | number | 1 | Schema version for future migrations |
| `feature` | string | — | Feature description from user |
| `phase` | string | — | Current phase name |
| `phase_iteration` | number | 0 | Iterations spent in current phase |
| `global_iteration` | number | 0 | Total iterations across all phases |
| `max_iterations` | number | 50 | Global iteration limit (stop hook allows exit) |
| `max_phase_iterations` | number | 10 | Per-phase limit (stop hook force-advances) |
| `fix_review_cycles` | number | 0 | Completed fix→re_review cycles |
| `max_fix_cycles` | number | 3 | Max cycles before forcing advance past review |
| `phases_completed` | string[] | [] | Ordered list of completed phase names |
| `artifacts.brainstorm_file` | string\|null | null | Path to brainstorm doc |
| `artifacts.plan_file` | string\|null | null | Path to plan doc |
| `artifacts.pr_url` | string\|null | null | PR URL when created |
| `artifacts.branch` | string\|null | null | Working branch name |
| `receipts` | Receipt[] | [] | Phase completion proofs |
| `errors` | Error[] | [] | Errors encountered |
| `budget_limit_usd` | number | 20 | Informational budget limit |
| `completion_promise` | string | "SHIPPED" | Text for `<promise>` tags |
| `skip_brainstorm` | boolean | false | Whether brainstorm was skipped |
| `started_at` | string | — | ISO 8601 creation timestamp |
| `last_updated` | string | — | ISO 8601 last modification |

## Phase Names

Valid values for `phase`:

`brainstorm` · `plan` · `deepen` · `work` · `review` · `fix` · `re_review` · `compound` · `test` · `ship`

## Receipt Format

```json
{
  "phase": "plan",
  "artifact": "docs/plans/2026-02-13-feat-auth-plan.md",
  "git_sha": "a1b2c3d",
  "timestamp": "2026-02-13T10:30:00Z"
}
```

Receipts serve as proof-of-work: the stop hook can verify that a phase actually produced output before advancing.

## Error Format

```json
{
  "phase": "work",
  "message": "Test suite failed: 3 failures in auth_test.py",
  "iteration": 12,
  "timestamp": "2026-02-13T11:15:00Z"
}
```

## Example: Mid-Implementation State

```json
{
  "version": 1,
  "feature": "Add user authentication with JWT and session management",
  "phase": "work",
  "phase_iteration": 2,
  "global_iteration": 7,
  "max_iterations": 50,
  "max_phase_iterations": 10,
  "fix_review_cycles": 0,
  "max_fix_cycles": 3,
  "phases_completed": ["brainstorm", "plan", "deepen"],
  "artifacts": {
    "brainstorm_file": "docs/brainstorms/2026-02-13-auth-brainstorm.md",
    "plan_file": "docs/plans/2026-02-13-feat-auth-plan.md",
    "pr_url": null,
    "branch": "feat/auth-system"
  },
  "receipts": [
    {"phase": "brainstorm", "artifact": "docs/brainstorms/2026-02-13-auth-brainstorm.md", "git_sha": "a1b2c3d", "timestamp": "2026-02-13T10:15:00Z"},
    {"phase": "plan", "artifact": "docs/plans/2026-02-13-feat-auth-plan.md", "git_sha": "d4e5f6g", "timestamp": "2026-02-13T10:30:00Z"},
    {"phase": "deepen", "artifact": "docs/plans/2026-02-13-feat-auth-plan.md", "git_sha": "h7i8j9k", "timestamp": "2026-02-13T10:45:00Z"}
  ],
  "errors": [],
  "budget_limit_usd": 20,
  "completion_promise": "SHIPPED",
  "skip_brainstorm": false,
  "started_at": "2026-02-13T10:00:00Z",
  "last_updated": "2026-02-13T11:00:00Z"
}
```
