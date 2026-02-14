---
description: "Cancel the active autonomous loop"
allowed-tools: ["Bash(test -f .claude/autonomous-loop.json:*)", "Bash(rm .claude/autonomous-loop.json)", "Read(.claude/autonomous-loop.json)"]
hide-from-slash-command-tool: "true"
---

# Cancel Autonomous Loop

To cancel the autonomous loop:

1. Check if `.claude/autonomous-loop.json` exists
2. If it exists:
   - Read and display final status (feature, phase, iteration, phases completed)
   - Delete the file: `rm .claude/autonomous-loop.json`
   - Confirm: "Autonomous loop cancelled."
3. If not: "No active autonomous loop found."
