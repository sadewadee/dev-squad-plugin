# SP1 Autonomous Mode (`--auto`) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an in-session `--auto` mode to `/dev-squad build` that runs the whole zero-to-ship workflow hands-off after one human kickoff — never pausing to ask — while staying safe and auditable via deterministic hooks.

**Architecture:** Flag → durable state (`mode:auto` in `.dev-squad/workflow-active`) → propagated to every subagent by the existing `inject-workflow-state.sh` and read by hooks. No headless / no `-p` (would need an API key; user is subscription-only). Enforcement is via dev-squad's proven `exit 2` + echo hook-block pattern. Default (no flag) behavior is byte-for-byte unchanged.

**Tech Stack:** Bash + python3 hooks (matching existing dev-squad hooks), JSON state files, JSON-Schema (`_schema.json`), markdown prompt files.

**Spec:** `docs/specs/2026-05-25-sp1-autonomous-mode.md`

**Branch:** all work commits to `feat/sp1-autonomous-mode` (already created). PR at the end. Never commit to `main`.

---

## File structure

| File | Responsibility | Action |
|------|----------------|--------|
| `.claude-plugin/workflows/_schema.json` | Canonical workflow schema | Add optional `auto_defaults` object |
| `.claude-plugin/workflows/zero-to-ship.json` | Workflow definition | Add `auto_defaults` block (the cap defaults) |
| `hooks/auto-guard.sh` | PreToolUse: block `AskUserQuestion` in auto mode | Create |
| `hooks/auto-governor.sh` | Budget governor: count dispatches (SubagentStop) + gate when over budget (PreToolUse) | Create |
| `hooks/stop-verify.sh` | Stop gate; extend with auto-mode quality-floor + fail-loud | Modify |
| `hooks/hooks.json` | Hook wiring | Add 3 wirings |
| `hooks/tests/test-auto-guard.sh` | Unit test for auto-guard | Create |
| `hooks/tests/test-auto-governor.sh` | Unit test for governor | Create |
| `hooks/tests/test-stop-verify-auto.sh` | Unit test for stop-verify auto path | Create |
| `commands/build.md` | `--auto` parse + intake-inference + conservative defaults + no-question rule | Modify |
| `skills/dev-squad/SKILL.md` | Document auto mode; update user-checkpoints note | Modify |
| `.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json` | Version bump | Modify |

**Runtime artifacts** (written in the user's project at run time, NOT committed): `.dev-squad/assumption-ledger.md`, `.dev-squad/auto-run.json`, `.dev-squad/auto-failure-report.md`.

**Simplification vs spec (DRY):** the governor enforces `max_total_dispatches` + `wall_clock_cap_min` only. Per-phase anti-thrash is already enforced by build.md's existing Phase 5 loop (`iter <= 5`); the governor does not duplicate it. `max_iterations_per_phase` stays in the config as documentation of that existing cap.

---

## Task 1: State contract — schema + workflow defaults

**Files:**
- Modify: `.claude-plugin/workflows/_schema.json`
- Modify: `.claude-plugin/workflows/zero-to-ship.json`

- [ ] **Step 1: Add `auto_defaults` to the schema's top-level properties**

In `.claude-plugin/workflows/_schema.json`, inside `"properties"` (after the `"phases"` property block, before the closing `}` of `properties`), add:

```json
    ,"auto_defaults": {
      "type": "object",
      "description": "Default budget envelope for --auto runs. Coordinator copies these into .dev-squad/workflow-active when --auto is set.",
      "additionalProperties": false,
      "properties": {
        "wall_clock_cap_min": { "type": "integer", "minimum": 1, "description": "Primary budget: max wall-clock minutes for the whole run" },
        "max_total_dispatches": { "type": "integer", "minimum": 1, "description": "Runaway/infinite-loop backstop" },
        "max_iterations_per_phase": { "type": "integer", "minimum": 1, "description": "Documents the existing Phase 5 anti-thrash cap; enforced in build.md, not the governor" },
        "on_floor_miss": { "enum": ["fail_loud"], "description": "What to do if quality floor not met" }
      }
    }
```

(`auto_defaults` is optional — it is NOT added to the top-level `required` array, so existing workflows without it stay valid.)

- [ ] **Step 2: Add the `auto_defaults` block to zero-to-ship.json**

In `.claude-plugin/workflows/zero-to-ship.json`, add a top-level key (place it after `"description"` / before `"phases"`):

```json
  "auto_defaults": {
    "wall_clock_cap_min": 480,
    "max_total_dispatches": 300,
    "max_iterations_per_phase": 5,
    "on_floor_miss": "fail_loud"
  },
```

- [ ] **Step 3: Verify both JSONs still parse**

Run: `jq empty .claude-plugin/workflows/_schema.json && jq empty .claude-plugin/workflows/zero-to-ship.json && echo OK`
Expected: `OK`

- [ ] **Step 4: Verify the drift hook still passes (no new warnings)**

Run: `CLAUDE_PLUGIN_ROOT="$(pwd)" bash hooks/validate-workflow-schema.sh; echo "exit=$?"`
Expected: `exit=0` and no `[dev-squad workflow drift]` lines (required fields unchanged, agent files unchanged).

- [ ] **Step 5: (If `python3 -c "import jsonschema"` succeeds) full schema-validate**

Run:
```bash
python3 -c "import json,jsonschema,sys; s=json.load(open('.claude-plugin/workflows/_schema.json')); d=json.load(open('.claude-plugin/workflows/zero-to-ship.json')); jsonschema.validate(d,s); print('SCHEMA OK')" 2>/dev/null || echo "jsonschema not installed — skipped (jq + drift hook cover structure)"
```
Expected: `SCHEMA OK` (or the skip message if `jsonschema` is absent).

- [ ] **Step 6: Commit**

```bash
git add .claude-plugin/workflows/_schema.json .claude-plugin/workflows/zero-to-ship.json
git commit -m "feat(sp1): add auto_defaults to workflow schema + zero-to-ship"
```

---

## Task 2: `auto-guard.sh` — block AskUserQuestion in auto mode

**Files:**
- Create: `hooks/auto-guard.sh`
- Test: `hooks/tests/test-auto-guard.sh`

- [ ] **Step 1: Write the failing test**

Create `hooks/tests/test-auto-guard.sh`:

```bash
#!/bin/bash
# Unit test for hooks/auto-guard.sh
set -u
HOOK="$(cd "$(dirname "$0")/.." && pwd)/auto-guard.sh"
TMP=$(mktemp -d); cd "$TMP"; fail=0

# Case 1: no workflow file -> no-op (exit 0)
echo '{"tool_name":"AskUserQuestion","tool_input":{}}' | bash "$HOOK" >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL case1: expected 0 got $rc"; fail=1; }

# Case 2: interactive mode -> no-op (exit 0)
mkdir -p .dev-squad; echo '{"mode":"interactive"}' > .dev-squad/workflow-active
echo '{"tool_name":"AskUserQuestion","tool_input":{}}' | bash "$HOOK" >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL case2: expected 0 got $rc"; fail=1; }

# Case 3: auto mode -> block (exit 2) + message mentions AUTO MODE
echo '{"mode":"auto"}' > .dev-squad/workflow-active
out=$(echo '{"tool_name":"AskUserQuestion","tool_input":{}}' | bash "$HOOK" 2>&1); rc=$?
[ "$rc" -eq 2 ] || { echo "FAIL case3 rc: expected 2 got $rc"; fail=1; }
echo "$out" | grep -qi "AUTO MODE" || { echo "FAIL case3 msg: '$out'"; fail=1; }

cd /; rm -rf "$TMP"
if [ "$fail" -eq 0 ]; then echo "PASS test-auto-guard"; else exit 1; fi
```

- [ ] **Step 2: Run the test, verify it fails**

Run: `bash hooks/tests/test-auto-guard.sh`
Expected: FAIL (script `hooks/auto-guard.sh` does not exist yet → non-zero exit / bash error).

- [ ] **Step 3: Implement the hook**

Create `hooks/auto-guard.sh`:

```bash
#!/bin/bash
# dev-squad: PreToolUse hook for AskUserQuestion.
# In --auto mode, block the question and tell the agent to infer + log to the ledger.
# No-op in interactive mode or when no workflow is active.

WORKFLOW_FILE=".dev-squad/workflow-active"
[ -f "$WORKFLOW_FILE" ] || exit 0

MODE=$(python3 -c "import json; print(json.load(open('$WORKFLOW_FILE')).get('mode',''))" 2>/dev/null)
[ "$MODE" = "auto" ] || exit 0

echo "AUTO MODE: do not ask the user. Infer this decision from the project description and conservative defaults, then append it to .dev-squad/assumption-ledger.md (with confidence: high|med|low + rationale + risk-if-wrong). For irreversible decisions (tenancy, identity hierarchy, billing/payment provider, compliance scope) pick the conservative default and mark confidence: low. Then continue. See commands/build.md 'Auto Mode' rules."
exit 2
```

- [ ] **Step 4: Make it executable + run the test, verify it passes**

Run: `chmod +x hooks/auto-guard.sh && bash hooks/tests/test-auto-guard.sh`
Expected: `PASS test-auto-guard`

- [ ] **Step 5: Commit**

```bash
git add hooks/auto-guard.sh hooks/tests/test-auto-guard.sh
git commit -m "feat(sp1): auto-guard hook blocks AskUserQuestion in auto mode"
```

---

## Task 3: `auto-governor.sh` — dispatch counter + budget gate

**Files:**
- Create: `hooks/auto-governor.sh`
- Test: `hooks/tests/test-auto-governor.sh`

The script handles two hook events, branching on `hook_event_name` from stdin:
- `SubagentStop` → increment `total_dispatches` in `.dev-squad/auto-run.json`.
- `PreToolUse` → if the tool is a subagent dispatch (`Task`/`Agent`, case-insensitive) AND a budget is exceeded → set `halted` + `exit 2`.

- [ ] **Step 1: Write the failing test**

Create `hooks/tests/test-auto-governor.sh`:

```bash
#!/bin/bash
# Unit test for hooks/auto-governor.sh
set -u
HOOK="$(cd "$(dirname "$0")/.." && pwd)/auto-governor.sh"
TMP=$(mktemp -d); cd "$TMP"; fail=0
mkdir -p .dev-squad

# auto mode with generous budget
cat > .dev-squad/workflow-active <<'JSON'
{"mode":"auto","auto":{"started_at":"2999-01-01T00:00:00Z","max_total_dispatches":2,"wall_clock_cap_min":480}}
JSON

# Case 1: SubagentStop increments total_dispatches 0 -> 1
echo '{"hook_event_name":"SubagentStop"}' | bash "$HOOK" >/dev/null 2>&1
n=$(python3 -c "import json; print(json.load(open('.dev-squad/auto-run.json'))['total_dispatches'])" 2>/dev/null)
[ "$n" = "1" ] || { echo "FAIL case1: expected 1 got '$n'"; fail=1; }

# Case 2: PreToolUse dispatch under budget (1 < 2) -> allow (exit 0)
echo '{"hook_event_name":"PreToolUse","tool_name":"Task"}' | bash "$HOOK" >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] || { echo "FAIL case2: expected 0 got $rc"; fail=1; }

# Bump to the cap
echo '{"hook_event_name":"SubagentStop"}' | bash "$HOOK" >/dev/null 2>&1  # ->2

# Case 3: PreToolUse dispatch at/over budget (2 >= 2) -> block (exit 2)
out=$(echo '{"hook_event_name":"PreToolUse","tool_name":"Task"}' | bash "$HOOK" 2>&1); rc=$?
[ "$rc" -eq 2 ] || { echo "FAIL case3 rc: expected 2 got $rc"; fail=1; }
echo "$out" | grep -qi "GOVERNOR" || { echo "FAIL case3 msg: '$out'"; fail=1; }

# Case 4: non-dispatch tool (Bash) never blocked even over budget -> exit 0
rc=$(echo '{"hook_event_name":"PreToolUse","tool_name":"Bash"}' | bash "$HOOK" >/dev/null 2>&1; echo $?)
[ "$rc" -eq 0 ] || { echo "FAIL case4: expected 0 got $rc"; fail=1; }

# Case 5: interactive mode -> no-op (no auto-run.json writes, exit 0)
rm -f .dev-squad/auto-run.json; echo '{"mode":"interactive"}' > .dev-squad/workflow-active
rc=$(echo '{"hook_event_name":"PreToolUse","tool_name":"Task"}' | bash "$HOOK" >/dev/null 2>&1; echo $?)
[ "$rc" -eq 0 ] || { echo "FAIL case5: expected 0 got $rc"; fail=1; }
[ ! -f .dev-squad/auto-run.json ] || { echo "FAIL case5: should not create auto-run.json in interactive"; fail=1; }

cd /; rm -rf "$TMP"
if [ "$fail" -eq 0 ]; then echo "PASS test-auto-governor"; else exit 1; fi
```

- [ ] **Step 2: Run the test, verify it fails**

Run: `bash hooks/tests/test-auto-governor.sh`
Expected: FAIL (hook does not exist yet).

- [ ] **Step 3: Implement the hook**

Create `hooks/auto-governor.sh`:

```bash
#!/bin/bash
# dev-squad: --auto budget governor.
# SubagentStop -> increment total_dispatches.
# PreToolUse(dispatch tool) -> block when over budget (total_dispatches or wall-clock).
# No-op unless mode==auto.

WORKFLOW_FILE=".dev-squad/workflow-active"
RUN_FILE=".dev-squad/auto-run.json"
[ -f "$WORKFLOW_FILE" ] || exit 0

INPUT=$(cat - 2>/dev/null || echo '{}')

MODE=$(python3 -c "import json; print(json.load(open('$WORKFLOW_FILE')).get('mode',''))" 2>/dev/null)
[ "$MODE" = "auto" ] || exit 0

EVENT=$(printf '%s' "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('hook_event_name',''))" 2>/dev/null)
TOOL=$(printf '%s' "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_name',''))" 2>/dev/null)

# Ensure run file exists
[ -f "$RUN_FILE" ] || printf '%s' '{"total_dispatches":0,"halted":false,"halt_reason":null}' > "$RUN_FILE"

if [ "$EVENT" = "SubagentStop" ]; then
  python3 - "$RUN_FILE" <<'PY' 2>/dev/null
import json,sys
p=sys.argv[1]
d=json.load(open(p))
d["total_dispatches"]=int(d.get("total_dispatches",0))+1
json.dump(d,open(p,"w"))
PY
  exit 0
fi

if [ "$EVENT" = "PreToolUse" ]; then
  TL=$(printf '%s' "$TOOL" | tr '[:upper:]' '[:lower:]')
  case "$TL" in
    task|agent) ;;            # dispatch tool — check budget
    *) exit 0 ;;              # any other tool — never gated
  esac

  # Returns "OK" or "EXCEEDED: <reason>"
  VERDICT=$(python3 - "$WORKFLOW_FILE" "$RUN_FILE" <<'PY' 2>/dev/null
import json,sys,datetime
wf=json.load(open(sys.argv[1])); run=json.load(open(sys.argv[2]))
auto=wf.get("auto",{})
maxd=int(auto.get("max_total_dispatches",300))
maxmin=int(auto.get("wall_clock_cap_min",480))
n=int(run.get("total_dispatches",0))
if n>=maxd:
    print(f"EXCEEDED: max_total_dispatches ({n}>={maxd})"); sys.exit(0)
started=auto.get("started_at")
if started:
    try:
        t0=datetime.datetime.fromisoformat(started.replace("Z","+00:00"))
        now=datetime.datetime.now(datetime.timezone.utc)
        if (now-t0).total_seconds()/60.0 > maxmin:
            print(f"EXCEEDED: wall_clock_cap_min ({maxmin})"); sys.exit(0)
    except Exception:
        pass
print("OK")
PY
)

  if [ "${VERDICT#EXCEEDED}" != "$VERDICT" ]; then
    REASON="${VERDICT#EXCEEDED: }"
    python3 - "$RUN_FILE" "$REASON" <<'PY' 2>/dev/null
import json,sys
p=sys.argv[1]; d=json.load(open(p))
d["halted"]=True; d["halt_reason"]=sys.argv[2]
json.dump(d,open(p,"w"))
PY
    echo "AUTO GOVERNOR: budget exceeded ($REASON). Stop dispatching, finalize, and let the termination hook write the report."
    exit 2
  fi
  exit 0
fi

exit 0
```

- [ ] **Step 4: Make executable + run the test, verify it passes**

Run: `chmod +x hooks/auto-governor.sh && bash hooks/tests/test-auto-governor.sh`
Expected: `PASS test-auto-governor`

- [ ] **Step 5: Commit**

```bash
git add hooks/auto-governor.sh hooks/tests/test-auto-governor.sh
git commit -m "feat(sp1): auto-governor hook (dispatch count + budget gate)"
```

---

## Task 4: `stop-verify.sh` — auto-mode quality floor + fail-loud

**Files:**
- Modify: `hooks/stop-verify.sh` (insert auto block after `ERRORS` is computed, before the final `if [ -z "$ERRORS" ]; then exit 0; fi`)
- Test: `hooks/tests/test-stop-verify-auto.sh`

- [ ] **Step 1: Write the failing test**

Create `hooks/tests/test-stop-verify-auto.sh`:

```bash
#!/bin/bash
# Unit test for the auto-mode termination path in hooks/stop-verify.sh
set -u
HOOK="$(cd "$(dirname "$0")/.." && pwd)/stop-verify.sh"
TMP=$(mktemp -d); cd "$TMP"; fail=0
mkdir -p .dev-squad
# Minimal project so stop-verify does not early-exit, but no real build to run:
echo '{}' > package.json   # has package.json, no "test" script, no tsconfig -> verification no-ops cleanly

# Case A: auto mode, governor halted -> floor FAIL: writes report + exit 2
echo '{"workflow":"zero-to-ship","mode":"auto","phases":{}}' > .dev-squad/workflow-active
echo '{"total_dispatches":999,"halted":true,"halt_reason":"max_total_dispatches"}' > .dev-squad/auto-run.json
out=$(echo '{"stop_hook_active":false}' | bash "$HOOK" 2>&1); rc=$?
[ "$rc" -eq 2 ] || { echo "FAIL A rc: expected 2 got $rc"; fail=1; }
[ -f .dev-squad/auto-failure-report.md ] || { echo "FAIL A: failure report not written"; fail=1; }

# Case B: auto mode, clean floor -> exit 0, no failure report
rm -f .dev-squad/auto-failure-report.md
echo '{"total_dispatches":3,"halted":false,"halt_reason":null}' > .dev-squad/auto-run.json
rc=$(echo '{"stop_hook_active":false}' | bash "$HOOK" >/dev/null 2>&1; echo $?)
[ "$rc" -eq 0 ] || { echo "FAIL B: expected 0 got $rc"; fail=1; }
[ ! -f .dev-squad/auto-failure-report.md ] || { echo "FAIL B: should not write failure report on clean floor"; fail=1; }

# Case C: interactive mode unaffected (no workflow-active mode=auto) -> exit 0
echo '{"workflow":"zero-to-ship","mode":"interactive","phases":{}}' > .dev-squad/workflow-active
rc=$(echo '{"stop_hook_active":false}' | bash "$HOOK" >/dev/null 2>&1; echo $?)
[ "$rc" -eq 0 ] || { echo "FAIL C: expected 0 got $rc"; fail=1; }

# Case D: re-entrancy guard honored (stop_hook_active true -> exit 0 even if halted)
echo '{"workflow":"zero-to-ship","mode":"auto","phases":{}}' > .dev-squad/workflow-active
echo '{"total_dispatches":999,"halted":true,"halt_reason":"x"}' > .dev-squad/auto-run.json
rc=$(echo '{"stop_hook_active":true}' | bash "$HOOK" >/dev/null 2>&1; echo $?)
[ "$rc" -eq 0 ] || { echo "FAIL D: expected 0 got $rc"; fail=1; }

cd /; rm -rf "$TMP"
if [ "$fail" -eq 0 ]; then echo "PASS test-stop-verify-auto"; else exit 1; fi
```

- [ ] **Step 2: Run the test, verify it fails**

Run: `bash hooks/tests/test-stop-verify-auto.sh`
Expected: FAIL (Case A: no failure report written / wrong exit, because the auto block does not exist yet).

- [ ] **Step 3: Implement — insert the auto block**

In `hooks/stop-verify.sh`, locate the final section:

```bash
# If no project files detected, skip verification
if [ -z "$ERRORS" ]; then
  exit 0
fi

# Block stop with errors
echo "STOP BLOCKED — verification failed: ${ERRORS}Fix all errors before claiming done."
exit 2
```

Replace it with:

```bash
# --- SP1 auto-mode termination contract (runs before the interactive exit) ---
AUTO_MODE=$(python3 -c "import json; print(json.load(open('.dev-squad/workflow-active')).get('mode',''))" 2>/dev/null)
if [ "$AUTO_MODE" = "auto" ]; then
  FLOOR_FAIL=""
  [ -n "$ERRORS" ] && FLOOR_FAIL="${FLOOR_FAIL}verification failed: ${ERRORS}; "

  if [ -f ".dev-squad/iteration-log.md" ] && grep -qiE 'UNRESOLVED (P0|P1)|escalate to user' ".dev-squad/iteration-log.md"; then
    FLOOR_FAIL="${FLOOR_FAIL}unresolved P0/P1 findings; "
  fi

  if [ -f ".dev-squad/auto-run.json" ] && python3 -c "import json,sys; sys.exit(0 if json.load(open('.dev-squad/auto-run.json')).get('halted') else 1)" 2>/dev/null; then
    HALT_REASON=$(python3 -c "import json; print(json.load(open('.dev-squad/auto-run.json')).get('halt_reason') or 'budget exceeded')" 2>/dev/null)
    FLOOR_FAIL="${FLOOR_FAIL}governor halted run (${HALT_REASON}); "
  fi

  if [ -n "$FLOOR_FAIL" ]; then
    {
      echo "# Auto-mode run did NOT meet the quality floor"
      echo ""
      echo "Generated by stop-verify.sh at $(date -u +%Y-%m-%dT%H:%M:%SZ)"
      echo ""
      echo "## Reasons"
      echo "${FLOOR_FAIL}"
      echo ""
      echo "## Next steps"
      echo "- Review .dev-squad/assumption-ledger.md for inferred decisions (especially LOW confidence)."
      echo "- This run is NOT shippable. Human review required before merge."
    } > ".dev-squad/auto-failure-report.md"
    echo "STOP BLOCKED — auto-mode quality floor not met: ${FLOOR_FAIL}See .dev-squad/auto-failure-report.md."
    exit 2
  fi
  # floor met -> fall through to clean exit below
fi
# --- end auto-mode block ---

# If no verification errors, allow stop
if [ -z "$ERRORS" ]; then
  exit 0
fi

# Block stop with errors (interactive path)
echo "STOP BLOCKED — verification failed: ${ERRORS}Fix all errors before claiming done."
exit 2
```

(The existing `stop_hook_active` re-entrancy guard at the top of the file is unchanged — it already short-circuits on the second Stop attempt, preventing an infinite block loop.)

- [ ] **Step 4: Run the test, verify it passes**

Run: `bash hooks/tests/test-stop-verify-auto.sh`
Expected: `PASS test-stop-verify-auto`

- [ ] **Step 5: Commit**

```bash
git add hooks/stop-verify.sh hooks/tests/test-stop-verify-auto.sh
git commit -m "feat(sp1): stop-verify auto-mode quality floor + fail-loud report"
```

---

## Task 5: Wire the new hooks in `hooks.json`

**Files:**
- Modify: `hooks/hooks.json`

- [ ] **Step 1: Add auto-guard to PreToolUse + auto-governor to PreToolUse and SubagentStop**

In `hooks/hooks.json`:

(a) In the existing `"SubagentStop"` array, add a second hook entry alongside `check-workflow.sh`:

```json
    "SubagentStop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/check-workflow.sh\""
          },
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/auto-governor.sh\""
          }
        ]
      }
    ],
```

(b) In the existing `"PreToolUse"` array, add two new matcher blocks (after the existing `Bash` and `Write|Edit|...` blocks):

```json
      {
        "matcher": "AskUserQuestion",
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/auto-guard.sh\""
          }
        ]
      },
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/auto-governor.sh\""
          }
        ]
      }
```

(The governor uses matcher `*` and filters on `tool_name` internally — see Task 1 simplification note and spec §13 Q1. Tool names vary across harnesses; matching `*` + filtering is robust.)

- [ ] **Step 2: Verify hooks.json is valid JSON**

Run: `jq empty hooks/hooks.json && echo OK`
Expected: `OK`

- [ ] **Step 3: Sanity-check the wiring shape**

Run: `jq '.hooks.PreToolUse | length, (.hooks.SubagentStop[0].hooks | length)' hooks/hooks.json`
Expected: PreToolUse count increased by 2 (was 2 → now 4); SubagentStop inner hooks = 2.

- [ ] **Step 4: Commit**

```bash
git add hooks/hooks.json
git commit -m "feat(sp1): wire auto-guard + auto-governor hooks"
```

---

## Task 6: `commands/build.md` — `--auto` parsing, inference, defaults, no-question rule

This is a prompt file (not unit-testable); verification is a review checklist. Make the edits exactly, then run the checklist.

**Files:**
- Modify: `commands/build.md`

- [ ] **Step 1: Add an "Auto Mode" section near the top (after the canonical-workflow note, before Phase 0)**

Insert:

```markdown
## Auto Mode (`--auto`)

If the argument string contains `--auto`, this run is UNATTENDED after kickoff. The coordinator MUST:

1. **Write mode + budget to state.** At workflow start, write `.dev-squad/workflow-active` with `"mode": "auto"` and copy the `auto_defaults` block from `.claude-plugin/workflows/zero-to-ship.json` into an `"auto"` object, adding `"started_at"` (current UTC ISO timestamp). Example:
   `{"workflow":"zero-to-ship","mode":"auto","auto":{"started_at":"<ISO>","wall_clock_cap_min":480,"max_total_dispatches":300,"max_iterations_per_phase":5,"on_floor_miss":"fail_loud"},"phases":{...}}`
2. **Never ask the user.** Do NOT call `AskUserQuestion`. Do NOT end any turn with a question. Every decision that would normally be a question is INFERRED from the project description + defaults and recorded in `.dev-squad/assumption-ledger.md`.
3. **Skip the Phase 1 PRD checkpoint.** The Phase 1 haiku phase-gate judge substitutes for human approval. Record "PRD auto-approved by Phase 1 gate" in the ledger.

(Without `--auto`, mode is `interactive`; behavior is unchanged and all auto hooks no-op.)

### Assumption ledger format (`.dev-squad/assumption-ledger.md`)

| # | Phase | Decision point | Inferred value | Confidence | Source | Risk if wrong |
|---|-------|----------------|----------------|-----------|--------|---------------|

- Confidence: `high` / `med` / `low`; Source: `description-derived` / `default` / `heuristic`.
- Mark LOW-confidence rows clearly; the Phase 7 report surfaces them.

### Conservative defaults for IRREVERSIBLE decisions (auto mode)

When inference confidence is not high, the 4 irreversible dimensions use these conservative defaults and are logged as `confidence: low`:

| Dimension | Conservative default | Rationale |
|-----------|---------------------|-----------|
| Tenancy strategy (ADR-001) | shared-DB + RLS | standard B2B SaaS default; flag for review |
| Identity hierarchy (Intake Q2) | 3-tier (Platform / Tenant / User-in-tenant) | dev-squad's documented default |
| Billing + payment provider (ADR-002) | Stripe | most common; widest pattern coverage |
| Compliance scope (Intake Q10) | none, UNLESS a regulation is explicitly named in the description | do not impose GDPR/SOC2/etc. speculatively |

The other 6 SaaS intake dimensions are inferred ad hoc from the description (no fixed default).
```

- [ ] **Step 2: Update Phase 0 Step 2.5 (SaaS detection) for auto mode**

In the Step 2.5 section, after the existing SaaS-confirmation paragraph, add:

```markdown
**Auto mode:** skip the confirmation `AskUserQuestion`. Apply the keyword heuristic deterministically (3+ keywords OR `--saas` → SaaS enabled; else standard). Log the decision + matched keywords + confidence to the assumption ledger.
```

- [ ] **Step 3: Update Phase 0 Step 2.5b (SaaS Intake) for auto mode**

After the intake-blocks description, add:

```markdown
**Auto mode:** do NOT run the 3 AskUserQuestion blocks. Infer all 10 dimensions: the 4 irreversible ones use the conservative-defaults table above (logged `confidence: low`); the other 6 are inferred from the description. Write every inference to the assumption ledger. Do not require Phase 1 clarification for unanswered dimensions (there is no human) — record them as low-confidence assumptions instead.
```

- [ ] **Step 4: Update the Phase 1 checkpoint references**

Find the two lines that read approximately `Only stop for user input at the Phase 1 CHECKPOINT (PRD approval)` and the `>>> CHECKPOINT: Present PRD to user for approval before continuing <<<` line. Add an auto-mode caveat next to each:

```markdown
(Auto mode: SKIP this checkpoint — the Phase 1 haiku phase-gate judge approves the PRD; log "PRD auto-approved by Phase 1 gate" to the assumption ledger.)
```

- [ ] **Step 5: Update the "User checkpoints" summary**

Find the summary line listing user checkpoints (e.g., "up to 2 — Phase 0 Step 2.5 SaaS confirmation + Phase 1 PRD approval"). Append:

```markdown
In `--auto` mode there are ZERO user checkpoints; all decisions are inferred and recorded in `.dev-squad/assumption-ledger.md`.
```

- [ ] **Step 6: Verification checklist (manual review)**

Confirm by reading `commands/build.md`:
- [ ] `--auto` parsing + `mode:auto` state write is documented.
- [ ] No-question rule present ("do NOT call AskUserQuestion", "do NOT end a turn with a question").
- [ ] Assumption-ledger format present.
- [ ] Conservative-defaults table lists exactly the 4 irreversible dimensions.
- [ ] All three touchpoints (Step 2.5, 2.5b, Phase 1 checkpoint) have an auto-mode branch.
- [ ] Interactive behavior text is unchanged (auto rules are additive, gated on the flag).

- [ ] **Step 7: Commit**

```bash
git add commands/build.md
git commit -m "feat(sp1): build.md --auto mode (inference + ledger + no-question rule)"
```

---

## Task 7: `skills/dev-squad/SKILL.md` — document auto mode

**Files:**
- Modify: `skills/dev-squad/SKILL.md`

- [ ] **Step 1: Add `--auto` to the build command description**

In the command list near the top, update the `build` line to mention the flag:

```markdown
- `/dev-squad build <description> [--auto]` - Zero-to-ship; `--auto` runs unattended after kickoff (no questions; decisions inferred + logged to `.dev-squad/assumption-ledger.md`). See commands/build.md "Auto Mode".
```

- [ ] **Step 2: Update the "User checkpoints" note**

Find the line: `**User checkpoints:** up to 2 — Phase 0 Step 2.5 SaaS confirmation (only if SaaS keywords detected) + Phase 1 PRD approval. All other phases run autonomously.`
Append: ` In \`--auto\` mode there are ZERO checkpoints — all decisions inferred + recorded in the assumption ledger; a run that does not meet the quality floor writes \`.dev-squad/auto-failure-report.md\` instead of reporting success.`

- [ ] **Step 3: Verification (manual review)**

Confirm: build command line shows `[--auto]`; checkpoints note mentions zero-checkpoint auto behavior + fail-loud report. No other behavior changed.

- [ ] **Step 4: Commit**

```bash
git add skills/dev-squad/SKILL.md
git commit -m "docs(sp1): document --auto mode in SKILL.md"
```

---

## Task 8: Version bump + integration & regression verification

**Files:**
- Modify: `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`

- [ ] **Step 1: Run the full hook test suite**

Run: `for t in hooks/tests/test-*.sh; do bash "$t" || exit 1; done`
Expected: three `PASS` lines, exit 0.

- [ ] **Step 2: Regression — interactive default unchanged**

In a scratch dir with a `package.json` and `.dev-squad/workflow-active` set to `{"mode":"interactive","phases":{}}`:
- `echo '{"tool_name":"AskUserQuestion"}' | bash <plugin>/hooks/auto-guard.sh; echo $?` → `0`
- `echo '{"hook_event_name":"PreToolUse","tool_name":"Task"}' | bash <plugin>/hooks/auto-governor.sh; echo $?` → `0`, and no `.dev-squad/auto-run.json` created.
Expected: all no-op (proves zero regression to interactive mode).

- [ ] **Step 3: Integration — manual `--auto` smoke (interactive session, subscription auth, NO -p)**

In a throwaway project, run `/dev-squad build "tiny in-memory todo CLI" --auto`. Verify:
- [ ] `.dev-squad/workflow-active` has `"mode":"auto"` + an `"auto"` block with `started_at`.
- [ ] The run never shows an `AskUserQuestion` prompt.
- [ ] `.dev-squad/assumption-ledger.md` is created and populated.
- [ ] On success, the completion report references the ledger; OR if forced to fail (e.g., set `max_total_dispatches` to 1 in `zero-to-ship.json`), `.dev-squad/auto-failure-report.md` is written and the run is NOT reported as shipped.
- [ ] Empirical confirm (flagged in spec §9): `exit 2` from `auto-guard.sh` propagates its message to the agent, and the dispatch tool name observed is `Task` (or whatever the runtime uses — governor's `*`+filter handles either).

- [ ] **Step 4: Bump version**

Edit both `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`: bump `version` from `4.17.0` to `4.18.0` (new minor feature).

- [ ] **Step 5: Commit + push branch**

```bash
git add .claude-plugin/plugin.json .claude-plugin/marketplace.json
git commit -m "chore(sp1): v4.18.0 — autonomous --auto mode"
git push -u origin feat/sp1-autonomous-mode
```

- [ ] **Step 6: Open PR** (after user confirmation — see handoff)

```bash
gh pr create --title "feat: SP1 autonomous --auto mode (in-session, hook-enforced)" --body "<summary + test plan from this plan>"
```

---

## Self-review (against spec)

- **Spec coverage:** C1 flag+state → Task 1 + Task 6 Step 1. C2 inference + conservative defaults → Task 6 Steps 1-3. C3 ledger → Task 6 Step 1. C4 auto-guard → Task 2. C5 governor → Task 3 (with documented per-phase simplification). C6 termination/fail-loud → Task 4. Wiring → Task 5. Docs → Task 7. Default-preservation → Task 8 Step 2 + every hook's `mode != auto -> exit 0`. Testing plan (spec §10) → Tasks 2-4 unit tests + Task 8 integration/regression. All spec sections mapped.
- **Placeholder scan:** every code step contains complete bash/json; no TBD/TODO; the only "fill from this plan" is the PR body (acceptable).
- **Type/name consistency:** state key `mode` ("auto"/"interactive"); run file `.dev-squad/auto-run.json` with keys `total_dispatches`/`halted`/`halt_reason`; ledger `.dev-squad/assumption-ledger.md`; failure report `.dev-squad/auto-failure-report.md`; config keys `wall_clock_cap_min`/`max_total_dispatches`/`max_iterations_per_phase`/`on_floor_miss` — consistent across schema, hooks, build.md, and tests.

**Known deviation from spec (intentional):** governor enforces `max_total_dispatches` + `wall_clock_cap_min` only; per-phase anti-thrash relies on the existing Phase 5 loop (DRY). Documented in the file-structure note above.
