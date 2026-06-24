---
name: hook-stocktake
description: Audit dev-squad's own hook artifact loops — every .dev-squad/* file a hook writes should have a consumer, and every file a hook reads should have a producer. Catches write-only orphans (a hook saves state nothing ever restores) and dangling reads (a hook reads a file nothing writes) as the plugin grows. Report only.
---

# /dev-squad hook-stocktake

Audit the producer/consumer loops of this plugin's own hooks. A growing plugin accumulates hooks that **write an artifact nothing reads** (e.g. a state file saved on PreCompact that no SessionStart hook ever restores) or **read an artifact nothing writes** (a dangling consumer). Both are silent dead-ends: the hook runs, the work looks done, but the loop is never closed. This surfaces them before they rot. **Report only — change nothing.**

This is the hook-layer companion to `/dev-squad skill-stocktake` (which audits `skills/`). Run it whenever you add or change a hook that touches `.dev-squad/`.

## Check

Every `.dev-squad/<artifact>` path referenced anywhere in `hooks/` should be referenced by **at least two files**: something produces it, something consumes it. An artifact referenced by only one file is a dead-end candidate.

Run this from the plugin root (deterministic — do not eyeball the hooks by hand):

```bash
ROOT="${CLAUDE_PLUGIN_ROOT:-.}"; cd "$ROOT" || exit 1
# -I ignores binaries; exclude compiled/cache/git/test noise so counts are real.
GREP() { grep "$@" -I --exclude-dir=__pycache__ --exclude-dir=.git --exclude='*.pyc' --exclude-dir=tests; }
arts=$(GREP -rhoE '\.dev-squad/[A-Za-z0-9._/-]+' hooks/ 2>/dev/null \
  | sed -E 's#^\.dev-squad/##' | grep -vE '/$' | grep -E '\.[a-z]+$' | sort -u)
printf '%-26s %5s  %s\n' "ARTIFACT" "FILES" "AREAS (h=hooks c=cmd s=skill g=agent)  [FLAG]"
for a in $arts; do
  files=$(GREP -rl "$a" hooks/ commands/ skills/ agents/ 2>/dev/null | sort -u)
  n=$(printf '%s' "$files" | grep -c .)
  h=$(printf '%s\n' "$files" | grep -c '^hooks/');    c=$(printf '%s\n' "$files" | grep -c '^commands/')
  s=$(printf '%s\n' "$files" | grep -c '^skills/');   g=$(printf '%s\n' "$files" | grep -c '^agents/')
  flag=""
  [ "$n" -le 1 ] && flag="  <-- ORPHAN (<=1 referencer: write-only or dead-end)"
  [ "$n" -gt 1 ] && [ "$c" = 0 ] && [ "$s" = 0 ] && [ "$g" = 0 ] && flag="  (hooks-only: confirm producer AND consumer both present)"
  printf '%-26s %5s  h=%s c=%s s=%s g=%s%s\n' "$a" "$n" "$h" "$c" "$s" "$g" "$flag"
done
```

## Interpreting the result

The reference count is a robust signal (it survives variable-based redirects like `> "$STATE_FILE"`, which literal-path matching misses), but it is a **candidate filter, not a verdict** — confirm each flag by reading the files:

- **ORPHAN (`<=1` referencer)** — the artifact is touched by a single file. Either it is write-only (a hook saves it, nothing restores it — the bug this audit exists to catch) or read-only (a hook reads it, nothing produces it). Open the file and decide. A deliberate forensic/append log (e.g. a security warnings log meant for humans, not programmatic consumption) is a legitimate write-only — note it as intentional rather than "broken".
- **hooks-only** — referenced only inside `hooks/`, never by a command/skill/agent. Fine for internal hook state (e.g. a governor that reads back its own budget file across invocations). Open the files and confirm one hook writes it AND one reads it; a pair of pure writers with no reader is still a dead-end.
- **Otherwise** — the loop spans producers and consumers across areas; almost always healthy.

One side being prose (an agent writes the file via its prompt, a hook reads it — or vice versa) is acceptable by design; flag it only if the prose side is the *restore* of something the user relies on surviving (that should be hook-enforced, not hoped for).

## Output

```
Hook artifact stocktake: <N> artifacts audited
  ORPHAN     — <artifact>: <write-only|read-only> (<the one file>) — <bug | intentional?>
  HOOKS-ONLY — <artifact>: confirm producer + consumer (<files>)
Clean: <count> artifacts with a closed loop
```

If every artifact has a closed loop: `All <N> artifacts have both a producer and a consumer. No dead-ends.`

Do not edit hooks — this is an audit. Hand the fix-list to the maintainer.
