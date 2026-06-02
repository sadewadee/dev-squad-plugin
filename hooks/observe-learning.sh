#!/bin/bash
# dev-squad: PostToolUse observe hook (continuous-learning CAPTURE tier)
# Appends ONE compact JSONL observation per tool call to .dev-squad/observations.jsonl.
# This is the deterministic capture half of continuous-learning — NO LLM, 100% reliable.
# Distillation (observations -> confidence-scored instincts) happens IN-SESSION
# (coordinator Phase 7 LEARN, or the /dev-squad evolve command) — never a headless
# daemon, because the user is subscription-only (no API key for background agents).
#
# No-ops entirely outside a dev-squad project (no .dev-squad/ dir = nothing to learn).

DS=".dev-squad"
[ -d "$DS" ] || exit 0

export DS_OBS="$DS/observations.jsonl"

python3 -c '
import sys, json, time, os
raw = sys.stdin.read()
try:
    d = json.loads(raw)
except Exception:
    sys.exit(0)

tool = d.get("tool_name") or d.get("tool") or ""
ti = d.get("tool_input") or {}
tr = d.get("tool_response") or d.get("tool_result") or {}

# signature: the command, or the edited file path
sig = ti.get("command") or ti.get("file_path") or ti.get("description") or ""

# crude outcome signal for error->fix resolution detection
text = ""
if isinstance(tr, dict):
    text = (str(tr.get("stderr", "")) + " " + str(tr.get("stdout", "")))[:500]
elif isinstance(tr, str):
    text = tr[:500]
err = 1 if any(k in text.lower() for k in
              ("error", "err!", "err:", "failed", "failure", "exception",
               "cannot", "could not", "unable", "fatal",
               "not found", "no such", "undefined", "denied", "refused",
               "panic", "traceback")) else 0

rec = {"ts": int(time.time()), "tool": tool, "sig": str(sig)[:200], "err": err}
try:
    with open(os.environ["DS_OBS"], "a") as f:
        f.write(json.dumps(rec) + "\n")
except Exception:
    pass
' 2>/dev/null

exit 0
