---
description: "Show current status of the active autonomous loop"
allowed-tools: ["Read(.claude/autonomous-loop.json)"]
hide-from-slash-command-tool: "true"
---

# Autonomous Loop Status

1. Read `.claude/autonomous-loop.json`. If missing: "No active autonomous loop."
2. Display: feature, current phase, phase iteration, global iteration, phases completed, fix cycles, artifacts, receipt count, error count, timestamps.
3. If errors exist, show the last 3 with details.
