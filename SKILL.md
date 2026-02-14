---
name: autonomous-loop
description: Phase-aware autonomous engineering loop with crash recovery. Combines Ralph Loop persistence with Compound Engineering workflows for long-horizon feature development. Use when running autonomous multi-phase engineering tasks.
---

# Autonomous Loop

A stop-hook-powered engineering loop that persists across context resets. State lives in `.claude/autonomous-loop.json` (JSON — resistant to model corruption). Each iteration starts with re-anchoring to prevent drift.

## Phase Machine

```
brainstorm → plan → deepen → work → review ──→ compound → test → ship
                                      │                        │
                                      ↓ (P1 found)             ↓ (fail)
                                     fix → re_review ──────→ fix
                                      ↑       │
                                      └───────┘ (max 3 cycles)
```

## Phases

| Phase | Command | Done When |
|-------|---------|-----------|
| brainstorm | `/workflows:brainstorm` | Brainstorm doc created |
| plan | `/workflows:plan` | Plan file created |
| deepen | `/compound-engineering:deepen-plan` | Single pass (always advances) |
| work | `/workflows:work` | All tasks done, commits pushed |
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
5. Update relevant `artifacts` fields (plan_file, pr_url, branch, etc.)
6. Update `last_updated` timestamp

### On errors:

- Add error details to the `errors` array
- Do NOT change the phase — the stop hook will retry on next iteration

### Phase-specific rules:

- **fix**: Increment `fix_review_cycles` when entering fix
- **review / re_review**: Check P1 findings to pick next phase
- **ship**: Set `artifacts.pr_url` before outputting promise

## Safety Rails

- **Global limit**: Stops at `max_iterations` (default 50)
- **Phase limit**: Force-advances if stuck for `max_phase_iterations` (default 10)
- **Fix cycles**: Max `max_fix_cycles` (default 3) fix→re_review rounds
- **Completion**: Output `<promise>SHIPPED</promise>` to end the loop

## Conflict with Ralph Loop

Do not run an autonomous loop and a Ralph Loop simultaneously. Both use stop hooks — only one should be active. Cancel Ralph first: `/cancel-ralph`

## Reference

- [State file schema](references/state-schema.md)
- [Phase prompt details](references/phase-prompts.md)
