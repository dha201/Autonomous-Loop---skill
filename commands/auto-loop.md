---
description: "Start a phase-aware autonomous engineering loop (brainstorm → plan → work → review → fix → compound → test → ship)"
argument-hint: "\"feature description\" [--budget N] [--max-iterations N] [--skip-brainstorm] [--max-fix-cycles N]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-loop.sh:*)", "Read(.claude/autonomous-loop.json)", "Write(.claude/autonomous-loop.json)"]
hide-from-slash-command-tool: "true"
---

# Start Autonomous Loop

Execute the setup script to initialize the autonomous loop:

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-loop.sh" $ARGUMENTS
```

If the setup script fails (e.g. missing --feature flag), parse $ARGUMENTS yourself:

- **Feature description**: Everything before any `--` flag (required)
- `--budget N`: Budget limit in USD (default: 20)
- `--max-iterations N`: Global max iterations (default: 50)
- `--max-phase-iterations N`: Per-phase max (default: 10)
- `--skip-brainstorm`: Skip brainstorm, start at plan phase
- `--completion-promise "TEXT"`: Completion text (default: SHIPPED)
- `--max-fix-cycles N`: Max fix→review cycles (default: 3)

Then create `.claude/autonomous-loop.json` directly with the Write tool:

```json
{
  "version": 1,
  "feature": "<feature>",
  "phase": "<brainstorm or plan if --skip-brainstorm>",
  "phase_iteration": 0,
  "global_iteration": 0,
  "max_iterations": 50,
  "max_phase_iterations": 10,
  "fix_review_cycles": 0,
  "max_fix_cycles": 3,
  "phases_completed": [],
  "artifacts": {
    "brainstorm_file": null,
    "plan_file": null,
    "pr_url": null,
    "branch": null
  },
  "receipts": [],
  "errors": [],
  "budget_limit_usd": 20,
  "completion_promise": "SHIPPED",
  "skip_brainstorm": false,
  "started_at": "<ISO8601 now>",
  "last_updated": "<ISO8601 now>"
}
```

After state file is created, read `.claude/autonomous-loop.json` and display a configuration summary.

Then begin the first phase:
- If `skip_brainstorm` is true: Run `/workflows:plan <FEATURE>`
- Otherwise: Run `/workflows:brainstorm <FEATURE>`

After the first phase completes, update `.claude/autonomous-loop.json`:
- Add the completed phase to `phases_completed`
- Set the artifact path in `artifacts`
- Advance `phase` to the next phase
- Reset `phase_iteration` to 0
- Add a receipt with artifact path, git SHA, and timestamp

Then continue to the next phase. The stop hook will catch you if context resets.
