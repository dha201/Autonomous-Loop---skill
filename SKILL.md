---
name: autonomous-loop
description: Phase-aware autonomous engineering loop with crash recovery and spec-first testing. Combines Ralph Loop persistence with Compound Engineering workflows for long-horizon feature development. Use when running autonomous multi-phase engineering tasks.
---

# Autonomous Loop

A stop-hook-powered engineering loop that persists across context resets. State lives in `.claude/autonomous-loop.json` (JSON — resistant to model corruption). Each iteration starts with re-anchoring to prevent drift.

Acceptance tests are derived from the plan **before any implementation begins**. This prevents the circular bias where agents write tests that verify what the code does rather than what the spec requires.

## Phase Machine

```
brainstorm → plan → spec_test → deepen → work → review ──→ compound → test → ship
                        │                             │                    │
                        │ (human gate or              ↓ (P1 found)        ↓ (fail)
                        │  --skip-test-review)       fix → re_review ──→ fix
                        ↓                             ↑       │
                  Acceptance tests                    └───────┘ (max 3 cycles)
                  committed to repo
                  before any code
```

## Phases

| Phase | Command | Done When |
|-------|---------|-----------|
| brainstorm | `/workflows:brainstorm` | Brainstorm doc created |
| plan | `/workflows:plan` | Plan file created |
| spec_test | Write acceptance tests from plan (no implementation) | Tests committed, run fails confirmed |
| deepen | `/compound-engineering:deepen-plan` | Single pass (always advances) |
| work | `/workflows:work` (constrained: make spec tests pass) | All tasks done, spec tests pass, commits pushed |
| review | `/workflows:review` | Review complete |
| fix | `/compound-engineering:resolve_todo_parallel` | P1 findings resolved |
| re_review | `/workflows:review` | Verify fixes |
| compound | `/workflows:compound` | Learnings documented |
| test | `/compound-engineering:test-browser` | E2E tests pass |
| ship | Create/finalize PR | `<promise>SHIPPED</promise>` |

## Re-Anchoring Protocol

At the START of every iteration, before any other work:

1. Read `.claude/autonomous-loop.json` for current state
2. Run `git log --oneline -10` to see recent commits
3. Run `git diff --stat` to check uncommitted changes
4. Read the plan file (if `artifacts.plan_file` is set)
5. Read the acceptance tests file (if `artifacts.acceptance_tests_file` is set) — these are the contract the `work` phase must satisfy

This prevents drift when context gets compressed between iterations.

## State Management

You MUST update `.claude/autonomous-loop.json` at every phase boundary.

### Completing a phase:

1. Add the completed phase name to `phases_completed`
2. Set `phase` to the next phase name
3. Reset `phase_iteration` to 0
4. Record a receipt in `receipts`:
   ```json
   {"phase": "plan", "artifact": "docs/plans/...", "git_sha": "abc123", "timestamp": "2026-02-13T10:30:00Z"}
   ```
5. Update relevant `artifacts` fields (plan_file, pr_url, branch, acceptance_tests_file, etc.)
6. Write a checkpoint summary to `checkpoints[]` describing what was accomplished and any failed approaches
7. Update `last_updated` timestamp

### On errors:

- Add error details to the `errors` array
- Do NOT change the phase — the stop hook will retry on next iteration

### Phase-specific rules:

- **spec_test**: Set `artifacts.acceptance_tests_file`; confirm tests fail before advancing
- **fix**: Increment `fix_review_cycles` when entering fix
- **review / re_review**: Check P1 findings to pick next phase
- **ship**: Set `artifacts.pr_url` before outputting promise

## Spec-First Testing Principle

The `spec_test` phase runs in a fresh context with access to **only the plan and brainstorm artifacts** — never the implementation. This isolation is what prevents circular test bias.

When the `work` phase begins, its mandate is explicit:
> "Acceptance tests already exist in `tests/acceptance/`. Make them pass using TDD for unit-level code. Do NOT rewrite or modify acceptance tests unless the plan itself has changed."

Tests that verify what the code does (implementation-biased) are a defect. Tests that verify what the spec requires (behavior-driven) are the target.

## Long-Horizon Resilience Patterns

For complex tasks spanning many iterations:

- **Checkpoint writes**: At each phase boundary, write a short summary to `checkpoints[]` describing what was accomplished, what approaches failed, and what the next phase should know. This is the external memory that re-anchors future iterations.
- **Test output filtering**: In the `test` phase, only surface errors and failures — not verbose passing output. Every line in context must earn its place.
- **Progress tracking**: Maintain `docs/progress.md` with a log of failed approaches. Agents pick this up on re-anchor to avoid repeating dead ends.
- **Binary isolation**: When stuck on a hard bug affecting many files, divide the problem space: compile half the files with new code, half with known-good baseline. Use pass/fail to isolate the real problem.

## Safety Rails

- **Global limit**: Stops at `max_iterations` (default 50)
- **Phase limit**: Force-advances if stuck for `max_phase_iterations` (default 10)
- **Fix cycles**: Max `max_fix_cycles` (default 3) fix→re_review rounds
- **Completion**: Output `<promise>SHIPPED</promise>` to end the loop
- **Test gate**: Do not advance from `spec_test` to `deepen` until acceptance tests are committed and confirmed to fail (proving they actually test something)

## Conflict with Ralph Loop

Do not run an autonomous loop and a Ralph Loop simultaneously. Both use stop hooks — only one should be active. Cancel Ralph first: `/cancel-ralph`

## Reference

- [State file schema](references/state-schema.md)
- [Phase prompt details](references/phase-prompts.md)
