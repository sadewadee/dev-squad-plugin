---
name: hook-stocktake
description: Audit dev-squad's own hook artifact loops — every .dev-squad/* file a hook writes should have a consumer, and every file a hook reads should have a producer. Catches write-only orphans (a hook saves state nothing ever restores) and dangling reads (a hook reads a file nothing writes) as the plugin grows. Report only.
---

# /dev-squad hook-stocktake

Audit the producer/consumer loops of this plugin's own hooks. A growing plugin accumulates hooks that **write an artifact nothing reads** (e.g. a state file saved on PreCompact that no SessionStart hook ever restores) or **read an artifact nothing writes** (a dangling consumer). Both are silent dead-ends: the hook runs, the work looks done, but the loop is never closed. This surfaces them before they rot. **Report only — change nothing.**

This is the hook-layer companion to `/dev-squad skill-stocktake` (which audits `skills/`). Run it whenever you add or change a hook that touches `.dev-squad/`.

## Check

For every `.dev-squad/<artifact>` a hook touches, the audit classifies **each side** of the loop as a deterministic hook or only prose:

- **deterministic producer** — a hook script that WRITES it (`>`/`>>`/`tee`, or a Python open-for-write).
- **deterministic consumer** — a hook script that READS it (`cat`/`head`/`grep`/`[ -f ]`/`source`/`<`, or a Python open-for-read).
- **prose touch** — a `commands`/`skills`/`agents` `.md` that merely mentions it (an agent is *told* to write/read it — fires ~50-80%).

Plain reference-counting is not enough: it can't tell a real hook-closed loop from a prose mention, so it marks half-prose loops "healthy" (this is the exact blind spot that let the `pre-compact-state.md` orphan and the `iteration-log.md` fail-open hide). This audit resolves variable indirection (`> "$STATE_FILE"`) so the write/read classification is real, not literal-path-only.

Run from the plugin root (uses `python3`, already a hook dependency):

```bash
python3 - <<'PY'
import os, re, glob, sys
ROOT = os.environ.get("CLAUDE_PLUGIN_ROOT") or "."
os.chdir(ROOT)
if not (os.path.isdir("hooks") and os.path.isfile(".claude-plugin/plugin.json")):
    print("hook-stocktake: not the dev-squad plugin root (need hooks/ + .claude-plugin/plugin.json).")
    print("Run from the plugin repo or set CLAUDE_PLUGIN_ROOT. Aborting rather than auditing the wrong tree.")
    sys.exit(1)
DEV = re.compile(r'\.dev-squad/([A-Za-z0-9._/-]+)')
WRITE = re.compile(r'(>>?\s|\btee\b|open\([^)]*[\'"][aw]|\.write\()')
READ = re.compile(r'(\bcat\b|\bhead\b|\btail\b|\bgrep\b|\bsed\b|\bawk\b|\bsource\b|\[\s*-[fs]\b|<\s|json\.load\(open|open\([^)]*[\'"]r)')
VARDEF = r'(?m)^\s*(?:export\s+)?([A-Za-z_]\w*)\s*='   # bash VAR=, export VAR=, python var =
EXTLESS_OK = {"workflow-active"}  # known extensionless state files (real files, not dirs)
def hooks():
    return [f for f in sorted(glob.glob("hooks/*.sh")+glob.glob("hooks/*.py")) if "/tests/" not in f]
def file_artifacts(path):
    # Discover artifacts even when the path is built from variables (e.g. PLAN_FILE="$STATE_DIR/master-plan.md",
    # export DS_OBS="$DS/observations.jsonl") by resolving VAR assignments before scanning for .dev-squad/ paths.
    text = open(path, errors="ignore").read()
    vrs = {m.group(1): m.group(2).strip() for m in re.finditer(VARDEF + r'\s*"?([^"\n#]+?)"?\s*$', text)}
    def resolve(v, d=0):
        if d > 4: return v
        nv = re.sub(r'\$\{?([A-Za-z_]\w*)\}?', lambda m: vrs.get(m.group(1), m.group(0)), v)
        return resolve(nv, d + 1) if nv != v else nv
    found = set()
    for blob in [text] + [resolve(v) for v in vrs.values()]:
        for m in DEV.finditer(blob):
            p = m.group(1).rstrip(".,;:)")   # strip trailing sentence punctuation from comment captures
            if p.endswith("/"): continue
            base = p.split("/")[-1]
            if re.search(r'\.[a-z0-9]+$', base) or base in EXTLESS_OK:  # keep files (incl. extensionless state files), drop dirs
                found.add(p)
    return found
def artifacts():
    a = set()
    for f in hooks(): a |= file_artifacts(f)
    return sorted(a)
def role(path, art):
    text=open(path, errors="ignore").read()
    vrs=re.findall(VARDEF + r'\s*.*'+re.escape(art)+r'["\']?\s*$', text)
    pats=[re.escape(art)]+[r'\$\{?'+v+r'\b' for v in vrs]+[r'\b'+v+r'\b' for v in vrs]
    refre=re.compile("|".join(pats)); w=r=False
    for line in text.splitlines():
        if refre.search(line):
            if WRITE.search(line): w=True
            if READ.search(line): r=True
    return w, r
def prose(art):
    fs=glob.glob("commands/**/*.md",recursive=True)+glob.glob("skills/**/*.md",recursive=True)+glob.glob("agents/**/*.md",recursive=True)
    return [f for f in fs if art in open(f, errors="ignore").read()]
print(f"{'ARTIFACT':28} {'HOOK-W':22} {'HOOK-R':22} PROSE  VERDICT")
for a in artifacts():
    w=[os.path.basename(h) for h in hooks() if role(h,a)[0]]
    r=[os.path.basename(h) for h in hooks() if role(h,a)[1]]
    p=prose(a)
    if w and r: v="OK         deterministic loop closed"
    elif w and not r: v="FRAGILE    det-write / PROSE-only read (pre-compact class)" if p else "ORPHAN     write-only (no consumer at all)"
    elif r and not w: v="FRAGILE    det-read / PROSE-only write (fail-open class)" if p else "ORPHAN     read-only / dangling (no producer)"
    else: v="prose-only (no hook either side)" if p else "?? unreferenced"
    print(f"{a:28} {(','.join(w) or '-'):22} {(','.join(r) or '-'):22} {len(p):^5}  {v}")
PY
```

## Interpreting the result

The classification is real (write vs read, resolving variables), but the **severity is a judgment call** — read the file before acting:

- **ORPHAN** — no hook (and no prose) on one side. A genuine dead-end *unless* it is a deliberate forensic/append log meant for humans, not programmatic consumption (e.g. a security-warnings log) — note that as intentional, not broken.
- **FRAGILE: det-write / PROSE-only read** (the pre-compact class) — a hook invests effort writing a file, but only an agent-prose instruction reads it. If the read is something the user relies on (restoring state, surfacing a failure), make the consumer a hook. If the producer also emits a deterministic pointer at the right moment (e.g. a Stop-hook message), it is softer.
- **FRAGILE: det-read / PROSE-only write** (the fail-open class) — a hook makes a decision based on a file only an agent-prose instruction writes. **Dangerous when the hook is a safety gate** (absent/misformatted file → silent wrong pass — this is how `iteration-log.md`'s escalation gate failed open). **Acceptable when the consumer degrades gracefully** and the file is inherently agent-authored knowledge a hook cannot generate (`gotchas.md`, `design-tokens.md`, `memory.md`, `record.md`, `component-registry.json`, the core `workflow-active`). Decide which it is by reading what the hook DOES with the file.
- **OK** — both sides are hooks. The loop is deterministically closed.

## Output

```
Hook artifact stocktake: <N> artifacts audited
  ORPHAN   — <artifact>: <write-only|read-only> (<file>) — <bug | intentional log?>
  FRAGILE  — <artifact>: <pre-compact|fail-open> class — <safety-critical? then fix : by-design?>
  OK       — <count> artifacts with a deterministic closed loop
```

If every artifact is OK or by-design: `No dead-ends and no safety-critical prose legs.`

Do not edit hooks — this is an audit. Hand the fix-list to the maintainer.
