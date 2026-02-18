# State File Schema

## Location

`.claude/autonomous-loop.json`

JSON format chosen over YAML/markdown because models are less likely to corrupt structured JSON during updates (per Anthropic's long-running agent research).

## Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `version` | number | 2 | Schema version for future migrations |
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
| `artifacts.acceptance_tests_file` | string\|null | null | Path to spec-derived acceptance tests (written before any implementation) |
| `artifacts.progress_file` | string\|null | null | Path to `docs/progress.md` — log of failed approaches for long-horizon resilience |
| `artifacts.pr_url` | string\|null | null | PR URL when created |
| `artifacts.branch` | string\|null | null | Working branch name |
| `receipts` | Receipt[] | [] | Phase completion proofs |
| `checkpoints` | Checkpoint[] | [] | Per-phase summaries for re-anchoring after context resets |
| `errors` | Error[] | [] | Errors encountered |
| `budget_limit_usd` | number | 20 | Informational budget limit |
| `completion_promise` | string | "SHIPPED" | Text for `<promise>` tags |
| `skip_brainstorm` | boolean | false | Whether brainstorm was skipped |
| `skip_test_review` | boolean | false | Whether human gate at spec_test is skipped |
| `started_at` | string | — | ISO 8601 creation timestamp |
| `last_updated` | string | — | ISO 8601 last modification |

## Phase Names

Valid values for `phase`:

`brainstorm` · `plan` · `spec_test` · `deepen` · `work` · `review` · `fix` · `re_review` · `compound` · `test` · `ship`

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

## Checkpoint Format

Written at every phase boundary. Used by re-anchoring protocol when context resets.

```json
{
  "phase": "spec_test",
  "summary": "Wrote 7 acceptance tests covering login, logout, session expiry, and invalid credentials. All 7 confirmed failing before any implementation. Human approved tests — no changes requested.",
  "failed_approaches": [],
  "timestamp": "2026-02-13T10:35:00Z"
}
```

The `failed_approaches` array is most valuable during `work` and `fix` phases — recording what was tried and why it failed prevents the next iteration from repeating the same dead end.

## Example: Mid-Implementation State (v2)

```json
{
  "version": 2,
  "feature": "Add user authentication with JWT and session management",
  "phase": "work",
  "phase_iteration": 2,
  "global_iteration": 9,
  "max_iterations": 50,
  "max_phase_iterations": 10,
  "fix_review_cycles": 0,
  "max_fix_cycles": 3,
  "phases_completed": ["brainstorm", "plan", "spec_test", "deepen"],
  "artifacts": {
    "brainstorm_file": "docs/brainstorms/2026-02-13-auth-brainstorm.md",
    "plan_file": "docs/plans/2026-02-13-feat-auth-plan.md",
    "acceptance_tests_file": "tests/acceptance/2026-02-13-auth-acceptance.rb",
    "progress_file": "docs/progress.md",
    "pr_url": null,
    "branch": "feat/auth-system"
  },
  "receipts": [
    {"phase": "brainstorm", "artifact": "docs/brainstorms/2026-02-13-auth-brainstorm.md", "git_sha": "a1b2c3d", "timestamp": "2026-02-13T10:15:00Z"},
    {"phase": "plan", "artifact": "docs/plans/2026-02-13-feat-auth-plan.md", "git_sha": "d4e5f6g", "timestamp": "2026-02-13T10:30:00Z"},
    {"phase": "spec_test", "artifact": "tests/acceptance/2026-02-13-auth-acceptance.rb", "git_sha": "e1f2g3h", "timestamp": "2026-02-13T10:40:00Z"},
    {"phase": "deepen", "artifact": "docs/plans/2026-02-13-feat-auth-plan.md", "git_sha": "h7i8j9k", "timestamp": "2026-02-13T10:55:00Z"}
  ],
  "checkpoints": [
    {"phase": "spec_test", "summary": "Wrote 7 acceptance tests. All confirmed failing before impl. Human approved.", "failed_approaches": [], "timestamp": "2026-02-13T10:40:00Z"},
    {"phase": "deepen", "summary": "Added JWT library comparison and security hardening notes to plan.", "failed_approaches": [], "timestamp": "2026-02-13T10:55:00Z"}
  ],
  "errors": [],
  "budget_limit_usd": 20,
  "completion_promise": "SHIPPED",
  "skip_brainstorm": false,
  "skip_test_review": false,
  "started_at": "2026-02-13T10:00:00Z",
  "last_updated": "2026-02-13T11:00:00Z"
}
```
