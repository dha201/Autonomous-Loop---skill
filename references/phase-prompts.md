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
**Next**: → spec_test

## Phase: Spec Test

**Command**: (inline — executed as a dedicated sub-session, no slash command)
**Purpose**: Derive and commit behavioral acceptance tests from the plan before any implementation exists. Tests written here define "done" for the `work` phase — they are the contract, not a verification afterthought.

**Context isolation rule**: This phase reads ONLY the plan file and brainstorm doc. No implementation code exists yet. This is what makes the tests implementation-independent.

**Steps**:
1. Read `artifacts.plan_file` — extract every acceptance criterion, user story, and behavioral requirement
2. For each criterion, write a test in Given-When-Then or observable-behavior form:
   - **Given**: precondition state the system must be in
   - **When**: the user action or system event that triggers the behavior
   - **Then**: the observable outcome the user sees (not an internal function call)
3. Save tests to `tests/acceptance/YYYY-MM-DD-<feature>-acceptance.[ext]`
4. Run the test suite: **confirm every new test fails** with a meaningful failure message (not an error)
   - A test that passes immediately is testing existing behavior, not new behavior — revise or remove it
   - A test that errors (crashes the harness) means a setup problem — fix the harness before advancing
5. Commit the failing tests: `git commit -m "test: acceptance tests for <feature> (failing — no impl yet)"`
6. Set `artifacts.acceptance_tests_file` in state
7. If `--skip-test-review` is NOT set: pause and present tests to the human for review before advancing

**Human gate** (default: ON, skippable with `--skip-test-review`):
- Present the acceptance tests to the human
- Ask: "Do these tests correctly capture what the spec requires, from the user's perspective?"
- Wait for approval or corrections
- If corrections: revise tests, re-confirm failures, re-commit, repeat gate

**Anti-patterns to reject in this phase**:
- Tests that reference internal function names, module structure, or database schemas
- Tests that pass immediately before any implementation (test existing behavior, not new behavior)
- Tests that mirror the plan's task list step-by-step (test outcomes, not implementation steps)
- Any test written while looking at implementation code (isolation is the entire point of this phase)

**Artifact**: `tests/acceptance/YYYY-MM-DD-<feature>-acceptance.[ext]`
**State update**: Set `artifacts.acceptance_tests_file`
**Next**: → deepen

## Phase: Deepen

**Command**: `/compound-engineering:deepen-plan`
**Purpose**: Enhance each plan section with parallel research agents
**Artifact**: Updates existing plan file in-place
**Duration**: Single pass — always advances after 1 iteration
**Next**: → work

## Phase: Work

**Command**: `/workflows:work`
**Purpose**: Execute the plan — implement features using TDD for unit-level code, making spec tests pass
**Behavior**:
- Reads `artifacts.acceptance_tests_file` at start — these are the behavioral contract to satisfy
- Creates TodoList from plan tasks
- For each task: writes unit tests first (TDD), then minimal implementation
- Does NOT modify acceptance tests — they are frozen requirements
- Runs acceptance test suite after each logical unit of implementation
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
                                 spec_test ←─── (revise tests)
                                     │               ↑
                                     │ (human gate)  │
                                     ▼               │
                               [human reviews] ──────┘
                                     │ (approved)
                                     ▼
                                  deepen
                                     │
                                     ▼
                                   work  ←── reads acceptance_tests_file
                                     │        as frozen contract
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

**Key invariant**: No implementation code exists when `spec_test` runs. The acceptance test file is committed and confirmed-failing before `deepen` or `work` begin. This is the structural guarantee against implementation-biased tests.
