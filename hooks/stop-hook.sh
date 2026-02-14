#!/bin/bash

# Autonomous Loop Stop Hook
# Phase-aware stop hook that blocks session exit and re-prompts
# with phase-specific instructions + re-anchoring context.
#
# Reads JSON state (not markdown) for corruption resistance.
# Generates adaptive prompts per phase using CE workflow commands.

set -euo pipefail

STATE_FILE=".claude/autonomous-loop.json"

# ── No state file → allow exit ──────────────────────────────────
if [[ ! -f "$STATE_FILE" ]]; then
  exit 0
fi

# ── Require jq ──────────────────────────────────────────────────
if ! command -v jq &>/dev/null; then
  echo "⚠️  autonomous-loop: jq is required. Install: brew install jq" >&2
  rm -f "$STATE_FILE"
  exit 0
fi

# ── Read hook input (transcript path) ───────────────────────────
HOOK_INPUT=$(cat)

# ── Read and validate state ─────────────────────────────────────
STATE=$(cat "$STATE_FILE" 2>/dev/null || echo "")
if [[ -z "$STATE" ]] || ! echo "$STATE" | jq empty 2>/dev/null; then
  echo "⚠️  autonomous-loop: State file corrupted (invalid JSON). Stopping." >&2
  rm -f "$STATE_FILE"
  exit 0
fi

# ── Extract state fields ────────────────────────────────────────
PHASE=$(echo "$STATE" | jq -r '.phase // empty')
GLOBAL_ITER=$(echo "$STATE" | jq -r '.global_iteration // 0')
MAX_ITER=$(echo "$STATE" | jq -r '.max_iterations // 50')
PHASE_ITER=$(echo "$STATE" | jq -r '.phase_iteration // 0')
MAX_PHASE_ITER=$(echo "$STATE" | jq -r '.max_phase_iterations // 10')
FEATURE=$(echo "$STATE" | jq -r '.feature // empty')
PROMISE=$(echo "$STATE" | jq -r '.completion_promise // "SHIPPED"')
FIX_CYCLES=$(echo "$STATE" | jq -r '.fix_review_cycles // 0')
MAX_FIX=$(echo "$STATE" | jq -r '.max_fix_cycles // 3')
PLAN_FILE=$(echo "$STATE" | jq -r '.artifacts.plan_file // empty')
PHASES_DONE=$(echo "$STATE" | jq -r '(.phases_completed // []) | join(" → ")')

# Validate required fields
if [[ -z "$PHASE" ]] || [[ -z "$FEATURE" ]]; then
  echo "⚠️  autonomous-loop: Missing phase or feature. Stopping." >&2
  rm -f "$STATE_FILE"
  exit 0
fi

# Validate iteration is numeric
if ! [[ "$GLOBAL_ITER" =~ ^[0-9]+$ ]]; then
  echo "⚠️  autonomous-loop: global_iteration not numeric ('$GLOBAL_ITER'). Stopping." >&2
  rm -f "$STATE_FILE"
  exit 0
fi

# ── Termination check 1: global iteration limit ────────────────
if [[ $GLOBAL_ITER -ge $MAX_ITER ]]; then
  echo "🛑 autonomous-loop: Global max ($MAX_ITER) reached. Loop complete."
  # Don't delete state — user may want to inspect it
  exit 0
fi

# ── Termination check 2: completion promise in transcript ───────
TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq -r '.transcript_path // empty')
LAST_OUTPUT=""

if [[ -n "$TRANSCRIPT_PATH" ]] && [[ -f "$TRANSCRIPT_PATH" ]]; then
  if grep -q '"role":"assistant"' "$TRANSCRIPT_PATH" 2>/dev/null; then
    LAST_LINE=$(grep '"role":"assistant"' "$TRANSCRIPT_PATH" | tail -1)
    LAST_OUTPUT=$(echo "$LAST_LINE" | jq -r '
      .message.content // [] |
      map(select(.type == "text")) |
      map(.text) |
      join("\n")
    ' 2>/dev/null || echo "")

    if [[ -n "$PROMISE" ]] && [[ "$PROMISE" != "null" ]] && [[ -n "$LAST_OUTPUT" ]]; then
      PROMISE_TEXT=$(echo "$LAST_OUTPUT" | \
        perl -0777 -pe 's/.*?<promise>(.*?)<\/promise>.*/$1/s; s/^\s+|\s+$//g; s/\s+/ /g' \
        2>/dev/null || echo "")

      if [[ -n "$PROMISE_TEXT" ]] && [[ "$PROMISE_TEXT" = "$PROMISE" ]]; then
        echo "✅ autonomous-loop: Detected <promise>$PROMISE</promise> — feature shipped!"
        exit 0
      fi
    fi
  fi
fi

# ── Phase stuck check: force-advance if phase iter exceeded ─────
if [[ "$PHASE_ITER" =~ ^[0-9]+$ ]] && [[ "$MAX_PHASE_ITER" =~ ^[0-9]+$ ]] && \
   [[ $PHASE_ITER -ge $MAX_PHASE_ITER ]]; then
  echo "⚠️  autonomous-loop: Phase '$PHASE' stuck ($PHASE_ITER iters). Force-advancing." >&2

  case "$PHASE" in
    brainstorm) NEXT="plan" ;;
    plan)       NEXT="deepen" ;;
    deepen)     NEXT="work" ;;
    work)       NEXT="review" ;;
    review)     NEXT="compound" ;;
    fix)        NEXT="re_review" ;;
    re_review)  NEXT="compound" ;;
    compound)   NEXT="test" ;;
    test)       NEXT="ship" ;;
    ship)
      echo "🛑 autonomous-loop: Ship phase stuck. Stopping."
      exit 0
      ;;
    *)
      echo "⚠️  autonomous-loop: Unknown phase '$PHASE'. Stopping." >&2
      rm -f "$STATE_FILE"
      exit 0
      ;;
  esac

  STATE=$(echo "$STATE" | jq \
    --arg np "$NEXT" \
    --arg op "$PHASE" \
    '.phase = $np | .phase_iteration = 0 | .phases_completed += [$op]')
  PHASE="$NEXT"
  PHASE_ITER=0
fi

# ── Build re-anchoring header ───────────────────────────────────
REANCHOR="## Re-Anchor (do this FIRST)

1. Read \`.claude/autonomous-loop.json\` for your full state
2. Run \`git log --oneline -10\` to see recent commits
3. Run \`git diff --stat\` to check uncommitted changes"

if [[ -n "$PLAN_FILE" ]]; then
  REANCHOR="${REANCHOR}
4. Read \`${PLAN_FILE}\` for the implementation plan"
fi

# ── Generate phase-specific prompt ──────────────────────────────
case "$PHASE" in
  brainstorm)
    PHASE_PROMPT="## Phase: Brainstorm

Run \`/workflows:brainstorm\` with this feature:
> $FEATURE

When the brainstorm doc is written, update \`.claude/autonomous-loop.json\`:
- Add \"brainstorm\" to \`phases_completed\`
- Set \`artifacts.brainstorm_file\` to the output path
- Set \`phase\` to \"plan\", reset \`phase_iteration\` to 0
- Add a receipt to \`receipts\`"
    ;;

  plan)
    PHASE_PROMPT="## Phase: Plan

Run \`/workflows:plan $FEATURE\`

When the plan file is written, update \`.claude/autonomous-loop.json\`:
- Add \"plan\" to \`phases_completed\`
- Set \`artifacts.plan_file\` to the output path
- Set \`phase\` to \"deepen\", reset \`phase_iteration\` to 0
- Add a receipt"
    ;;

  deepen)
    PHASE_PROMPT="## Phase: Deepen Plan

Run \`/compound-engineering:deepen-plan\` on the plan at \`$PLAN_FILE\`

When done, update \`.claude/autonomous-loop.json\`:
- Add \"deepen\" to \`phases_completed\`
- Set \`phase\` to \"work\", reset \`phase_iteration\` to 0
- Add a receipt"
    ;;

  work)
    PHASE_PROMPT="## Phase: Work (Implementation)

Run \`/workflows:work\` to execute the plan.

This is the longest phase. Work through all tasks, commit incrementally.
When all tasks are done, update \`.claude/autonomous-loop.json\`:
- Add \"work\" to \`phases_completed\`
- Set \`artifacts.branch\` to the working branch
- Set \`artifacts.pr_url\` if a PR was created
- Set \`phase\` to \"review\", reset \`phase_iteration\` to 0
- Add a receipt"
    ;;

  review)
    PHASE_PROMPT="## Phase: Review

Run \`/workflows:review\` on the current branch.

After review, check for P1 findings. Update \`.claude/autonomous-loop.json\`:
- If P1 findings exist → set \`phase\` to \"fix\"
- If no P1 findings → add \"review\" to \`phases_completed\`, set \`phase\` to \"compound\"
- Reset \`phase_iteration\` to 0
- Add a receipt"
    ;;

  fix)
    PHASE_PROMPT="## Phase: Fix P1 Findings (cycle $((FIX_CYCLES + 1))/$MAX_FIX)

Run \`/compound-engineering:resolve_todo_parallel\` to fix all P1 issues.

When done, update \`.claude/autonomous-loop.json\`:
- Increment \`fix_review_cycles\` by 1
- Set \`phase\` to \"re_review\", reset \`phase_iteration\` to 0
- Add a receipt"
    ;;

  re_review)
    PHASE_PROMPT="## Phase: Re-Review (Verify Fixes)

Run \`/workflows:review\` to check if P1 findings are resolved.

Update \`.claude/autonomous-loop.json\`:
- If P1 remain AND \`fix_review_cycles\` < $MAX_FIX → set \`phase\` to \"fix\"
- If no P1 OR \`fix_review_cycles\` >= $MAX_FIX → add \"review\" to \`phases_completed\`, set \`phase\` to \"compound\"
- Reset \`phase_iteration\` to 0
- Add a receipt"
    ;;

  compound)
    PHASE_PROMPT="## Phase: Compound (Document Learnings)

Run \`/workflows:compound\` to document what was learned building this feature.

When done, update \`.claude/autonomous-loop.json\`:
- Add \"compound\" to \`phases_completed\`
- Set \`phase\` to \"test\", reset \`phase_iteration\` to 0
- Add a receipt"
    ;;

  test)
    PHASE_PROMPT="## Phase: Test

Run \`/compound-engineering:test-browser\` to verify the feature works end-to-end.

Update \`.claude/autonomous-loop.json\`:
- If tests pass → add \"test\" to \`phases_completed\`, set \`phase\` to \"ship\"
- If tests fail → set \`phase\` to \"fix\"
- Reset \`phase_iteration\` to 0
- Add a receipt"
    ;;

  ship)
    PHASE_PROMPT="## Phase: Ship

1. Ensure all tests pass
2. Create or update the PR (push latest commits)
3. Set \`artifacts.pr_url\` in state file
4. Add final receipt

Then output:
\`<promise>$PROMISE</promise>\`

This completes the autonomous loop."
    ;;

  *)
    echo "⚠️  autonomous-loop: Unknown phase '$PHASE'. Stopping." >&2
    rm -f "$STATE_FILE"
    exit 0
    ;;
esac

# ── Assemble full prompt ────────────────────────────────────────
FULL_PROMPT="${REANCHOR}

${PHASE_PROMPT}

## Rules
- ALWAYS update \`.claude/autonomous-loop.json\` when transitioning phases
- Record receipts: {\"phase\": \"...\", \"artifact\": \"...\", \"git_sha\": \"...\", \"timestamp\": \"...\"}
- On errors, add to \`errors\` array but do NOT change phase
- When ALL phases complete, output \`<promise>${PROMISE}</promise>\`"

# ── Update state: increment iteration counters ──────────────────
NEXT_GLOBAL=$((GLOBAL_ITER + 1))
NEXT_PHASE_ITER=$((PHASE_ITER + 1))
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

TEMP_FILE="${STATE_FILE}.tmp.$$"
echo "$STATE" | jq \
  --argjson gi "$NEXT_GLOBAL" \
  --argjson pi "$NEXT_PHASE_ITER" \
  --arg ts "$TIMESTAMP" \
  '.global_iteration = $gi | .phase_iteration = $pi | .last_updated = $ts' \
  > "$TEMP_FILE"
mv "$TEMP_FILE" "$STATE_FILE"

# ── Build system message ────────────────────────────────────────
SYS_MSG="🔄 Autonomous Loop | Phase: ${PHASE} | Global: ${NEXT_GLOBAL}/${MAX_ITER} | Phase iter: ${NEXT_PHASE_ITER}/${MAX_PHASE_ITER} | Done: [${PHASES_DONE}]"

if [[ $FIX_CYCLES -gt 0 ]]; then
  SYS_MSG="${SYS_MSG} | Fix cycles: ${FIX_CYCLES}/${MAX_FIX}"
fi

# ── Block exit and re-prompt ────────────────────────────────────
jq -n \
  --arg prompt "$FULL_PROMPT" \
  --arg msg "$SYS_MSG" \
  '{
    "decision": "block",
    "reason": $prompt,
    "systemMessage": $msg
  }'

exit 0
