#!/bin/bash

# Autonomous Loop Setup
# Creates the initial .claude/autonomous-loop.json state file.
# Called by Claude when user runs /auto-loop, or manually from terminal.

set -euo pipefail

# ── Require jq ──────────────────────────────────────────────────
if ! command -v jq &>/dev/null; then
  echo "Error: jq is required. Install: brew install jq" >&2
  exit 1
fi

# ── Defaults ────────────────────────────────────────────────────
FEATURE=""
BUDGET=20
MAX_ITER=50
MAX_PHASE_ITER=10
SKIP_BRAIN="false"
PROMISE="SHIPPED"
MAX_FIX=3

# ── Parse arguments ─────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case $1 in
    --feature)          FEATURE="$2";         shift 2 ;;
    --budget)           BUDGET="$2";          shift 2 ;;
    --max-iterations)   MAX_ITER="$2";        shift 2 ;;
    --max-phase-iterations) MAX_PHASE_ITER="$2"; shift 2 ;;
    --skip-brainstorm)  SKIP_BRAIN="true";    shift ;;
    --completion-promise) PROMISE="$2";       shift 2 ;;
    --max-fix-cycles)   MAX_FIX="$2";         shift 2 ;;
    -h|--help)
      echo "Usage: setup-loop.sh --feature \"description\" [options]"
      echo ""
      echo "Options:"
      echo "  --feature TEXT              Feature description (required)"
      echo "  --budget N                  Budget limit USD (default: 20)"
      echo "  --max-iterations N          Global max iterations (default: 50)"
      echo "  --max-phase-iterations N    Per-phase max iterations (default: 10)"
      echo "  --skip-brainstorm           Start at plan phase"
      echo "  --completion-promise TEXT    Completion text (default: SHIPPED)"
      echo "  --max-fix-cycles N          Max fix→review cycles (default: 3)"
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Run with --help for usage" >&2
      exit 1
      ;;
  esac
done

# ── Validate ────────────────────────────────────────────────────
if [[ -z "$FEATURE" ]]; then
  echo "Error: --feature is required" >&2
  exit 1
fi

# ── Check for existing loop ─────────────────────────────────────
if [[ -f .claude/autonomous-loop.json ]]; then
  EXISTING_PHASE=$(jq -r '.phase' .claude/autonomous-loop.json 2>/dev/null || echo "unknown")
  EXISTING_ITER=$(jq -r '.global_iteration' .claude/autonomous-loop.json 2>/dev/null || echo "?")
  echo "⚠️  An autonomous loop is already active!" >&2
  echo "   Phase: $EXISTING_PHASE (iteration $EXISTING_ITER)" >&2
  echo "   Run /loop-cancel first, or delete .claude/autonomous-loop.json" >&2
  exit 1
fi

# ── Determine starting phase ────────────────────────────────────
START_PHASE="brainstorm"
if [[ "$SKIP_BRAIN" == "true" ]]; then
  START_PHASE="plan"
fi

TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# ── Create state file ───────────────────────────────────────────
mkdir -p .claude

jq -n \
  --arg feature "$FEATURE" \
  --arg phase "$START_PHASE" \
  --argjson max_iter "$MAX_ITER" \
  --argjson max_phase "$MAX_PHASE_ITER" \
  --argjson max_fix "$MAX_FIX" \
  --argjson budget "$BUDGET" \
  --arg promise "$PROMISE" \
  --argjson skip "$SKIP_BRAIN" \
  --arg ts "$TIMESTAMP" \
  '{
    version: 1,
    feature: $feature,
    phase: $phase,
    phase_iteration: 0,
    global_iteration: 0,
    max_iterations: $max_iter,
    max_phase_iterations: $max_phase,
    fix_review_cycles: 0,
    max_fix_cycles: $max_fix,
    phases_completed: [],
    artifacts: {
      brainstorm_file: null,
      plan_file: null,
      pr_url: null,
      branch: null
    },
    receipts: [],
    errors: [],
    budget_limit_usd: $budget,
    completion_promise: $promise,
    skip_brainstorm: $skip,
    started_at: $ts,
    last_updated: $ts
  }' > .claude/autonomous-loop.json

echo "✅ Autonomous loop initialized!"
echo "   Feature:     $FEATURE"
echo "   Phase:       $START_PHASE"
echo "   Budget:      \$$BUDGET"
echo "   Iterations:  max $MAX_ITER (per phase: $MAX_PHASE_ITER)"
echo "   Fix cycles:  max $MAX_FIX"
echo "   Promise:     $PROMISE"
echo "   State:       .claude/autonomous-loop.json"
