# Phase Reference

Detailed description of each phase, what CE command it invokes, and transition rules.

## Phase: Brainstorm

**Command**: `/workflows:brainstorm`
**Purpose**: Collaborative dialogue to explore WHAT to build
**Artifact**: `docs/brainstorms/YYYY-MM-DD-<topic>-brainstorm.md`
**Skip**: `--skip-brainstorm` flag bypasses this phase
**Next**: → plan

## Phase: Plan

**Command**: `/workflows:plan <feature>`
**Purpose**: Transform feature description into structured implementation plan with research
**Artifact**: `docs/plans/YYYY-MM-DD-<type>-<name>-plan.md`
**Research**: Parallel agents search codebase patterns + institutional learnings, optionally external docs
**Next**: → deepen

## Phase: Deepen

**Command**: `/compound-engineering:deepen-plan`
**Purpose**: Enhance each plan section with parallel research agents
**Artifact**: Updates existing plan file in-place
**Duration**: Single pass — always advances after 1 iteration
**Next**: → work

## Phase: Work

**Command**: `/workflows:work`
**Purpose**: Execute the plan — implement features, write tests, commit incrementally
**Behavior**:
- Creates TodoList from plan tasks
- Implements each task following existing codebase patterns
- Runs tests after each significant change
- Makes incremental commits after logical units
- Creates branch if needed
**Artifact**: Working branch with commits, optionally PR
**Duration**: Longest phase (multiple iterations typical)
**Next**: → review

## Phase: Review

**Command**: `/workflows:review`
**Purpose**: Multi-agent code review with 12+ parallel reviewers
**Agents**: kieran-rails-reviewer, dhh-rails-reviewer, security-sentinel, performance-oracle, architecture-strategist, pattern-recognition-specialist, code-simplicity-reviewer, data-integrity-guardian, agent-native-reviewer, git-history-analyzer, and more
**Output**: P1/P2/P3 findings as todo files
**Transition**:
- P1 findings exist → **fix**
- No P1 findings → **compound**

## Phase: Fix

**Command**: `/compound-engineering:resolve_todo_parallel`
**Purpose**: Fix all P1 findings using parallel processing
**Tracking**: Increments `fix_review_cycles` counter
**Next**: → re_review (always)

## Phase: Re-Review

**Command**: `/workflows:review`
**Purpose**: Verify that P1 fixes are actually resolved
**Transition**:
- P1 still present AND `fix_review_cycles` < `max_fix_cycles` → **fix** (loop)
- No P1 OR cycles exhausted → **compound** (advance)

## Phase: Compound

**Command**: `/workflows:compound`
**Purpose**: Document learnings from building this feature for future reference
**Agents**: 6 parallel subagents (context analyzer, solution extractor, related docs finder, prevention strategist, category classifier, documentation writer)
**Artifact**: `docs/solutions/<category>/<filename>.md`
**Next**: → test

## Phase: Test

**Command**: `/compound-engineering:test-browser`
**Purpose**: Run E2E browser tests to verify the feature works
**Transition**:
- Tests pass → **ship**
- Tests fail → **fix** (re-enters fix cycle)

## Phase: Ship

**Purpose**: Finalize and deliver
**Steps**:
1. Ensure all tests pass
2. Push latest commits
3. Create or update PR with summary
4. Set `artifacts.pr_url` in state
5. Output `<promise>SHIPPED</promise>`

**Completion**: The stop hook detects the promise tag and allows exit.

## Phase Transition Diagram

```
                    ┌─── skip_brainstorm ───┐
                    │                       │
                    ▼                       ▼
              brainstorm ──────────────→ plan
                                          │
                                          ▼
                                       deepen
                                          │
                                          ▼
                                        work
                                          │
                                          ▼
                                       review
                                      ╱       ╲
                                (P1) ╱         ╲ (clean)
                                    ▼           ▼
                                  fix       compound
                                    │           │
                                    ▼           ▼
                                re_review     test
                               ╱    │        ╱    ╲
                         (P1) ╱     │  (pass)╱    (fail)╲
                              ▼     │       ▼           ▼
                            fix     │     ship         fix
                              ↑     │       │
                              └─────┘       ▼
                          (max cycles)    DONE
                              │
                              ▼
                           compound
```
