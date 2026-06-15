# CRISP Enforcement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enforce CRISP (Consistent, Responsive, Intuitive, Simple, Purposeful) component quality across dev-squad's designer and frontend agents via a hook-enforced + protocol hybrid approach.

**Architecture:** Three layers — (1) `check-component-reuse.sh` hook warns when a new component file duplicates an existing registry entry, (2) designer agent gets a 5-item CRISP gate appended to its Phase 3.5 output check, (3) frontend agent gets a Reuse-First Protocol as Step 0 before any component work. A new `crisp-patterns` skill provides the framework definition both agents load.

**Tech Stack:** Bash (hook script), Markdown (agent prompts + skill), JSON (hooks.json wiring + component registry schema)

---

## File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `skills/crisp-patterns/SKILL.md` | Create | CRISP framework reference — 5 lenses with concrete tests |
| `agents/designer.md` | Modify | Add `dev-squad:crisp-patterns` to skills frontmatter + CRISP gate to output check |
| `agents/frontend.md` | Modify | Add `dev-squad:crisp-patterns` to skills frontmatter + Reuse-First Protocol as Step 0 |
| `hooks/check-component-reuse.sh` | Create | Bash hook — parse Write tool stdin, detect component duplication against registry |
| `hooks/hooks.json` | Modify | Wire new hook to PostToolUse(Write) event |
| `.claude-plugin/plugin.json` | Modify | Bump version 4.29.0 → 4.30.0 |
| `.claude-plugin/marketplace.json` | Modify | Bump version 4.29.0 → 4.30.0 |

---

### Task 1: Create crisp-patterns skill

**Files:**
- Create: `skills/crisp-patterns/SKILL.md`

- [ ] **Step 1: Create skill directory and file**

```bash
mkdir -p skills/crisp-patterns
```

Then write `skills/crisp-patterns/SKILL.md`:

```markdown
---
name: crisp-patterns
description: CRISP component quality framework for dev-squad agents. Five evaluation lenses — Consistent, Responsive, Intuitive, Simple, Purposeful — each with a concrete field-test. Used by designer (Phase 3.5 output gate) and frontend (Reuse-First Protocol Step 0).
---

# CRISP Component Quality Framework

CRISP is a 5-dimension quality check for every UI component.
Use as evaluation lenses, not a mechanical checklist — each has a field test.

## C — Consistent

Component uses the same design tokens as every other component for the same
property type. No arbitrary color, spacing, or motion values.

- Color: always from `design-tokens.md`, never raw hex
- Spacing: always from spacing scale, never arbitrary `px`
- Motion: always from motion tokens, never hardcoded `ms`

**Field test:** Swap this component into a different page in the same app —
does the visual rhythm stay cohesive, or does it feel out of place?

## R — Responsive

Component works correctly at every breakpoint defined in `responsive-spec.md`.
Mobile-first: base styles for `sm`, scaled up with `md`/`lg`/`xl` prefixes.
Touch targets ≥ 44px on mobile. No hover-only affordances on touch devices.

**Field test:** Resize the browser to 375px — is the component still usable,
or does it overflow, collapse, or become untappable?

## I — Intuitive

Users know how to interact with the component without instruction.
All states are visually distinct: hover, focus, disabled, loading.
Error feedback appears near the source of the error, not in a distant toast.
Interactions are predictable: clicking a button does what its label says.

**Field test:** Show the component to someone who hasn't seen the app.
Do they immediately know what to click, or do they pause and look around?

## S — Simple

Component does one thing well. Props are the minimum needed for screens
that exist right now — no hypothetical future props. File ≤ 200 lines.
If the file is longer, extract a sub-component.

**Field test:** Remove one prop from the component. Does any currently-rendered
screen break? If not, that prop doesn't belong yet — remove it.

## P — Purposeful

The component exists for a specific, articulable reason.
`crisp.purposeful` in `.dev-squad/component-registry.json` is filled and honest.
No functional overlap with other components in the registry.
No ghost components (components defined but never rendered anywhere).

**Field test:** Can you complete "this component exists to ___" in one sentence?
If you can't, or if another component already does that job, don't build it.

---

## Component Registry Schema

When designer initializes or frontend updates `.dev-squad/component-registry.json`,
every entry must conform to this schema:

```json
{
  "version": 1,
  "generated_from": ".dev-squad/design/component-inventory.md",
  "components": [
    {
      "name": "Button",
      "path": "src/components/ui/Button.tsx",
      "aliases": ["Btn", "CTA", "ActionButton"],
      "variants": ["primary", "secondary", "ghost", "destructive", "link"],
      "states": ["default", "hover", "active", "focus", "disabled", "loading"],
      "crisp": {
        "purposeful": "Primary action trigger across all interactive surfaces",
        "simple": true,
        "consistent_token": "--color-primary"
      },
      "owner": "frontend",
      "phase_created": 4
    }
  ]
}
```

Field rules:
- `aliases`: other names frontend might search before creating a duplicate
- `crisp.purposeful`: mandatory one-sentence justification — empty = unjustified component
- `crisp.simple`: false requires a `simplicity_note` field explaining the complexity
- `path`: used by hook to verify file existence
```

- [ ] **Step 2: Verify file content and structure**

```bash
head -5 skills/crisp-patterns/SKILL.md
```

Expected output starts with:
```
---
name: crisp-patterns
description: CRISP component quality framework...
```

- [ ] **Step 3: Commit**

```bash
git add skills/crisp-patterns/SKILL.md
git commit -m "feat: add crisp-patterns reference skill"
```

---

### Task 2: Edit designer.md — CRISP gate + skill load

**Files:**
- Modify: `agents/designer.md`

- [ ] **Step 1: Add crisp-patterns to skills frontmatter**

In `agents/designer.md`, find the skills block in the YAML frontmatter (lines 8-17):

```yaml
skills:
  - frontend-design:frontend-design
  - ui-ux-pro-max
  - superpowers:brainstorming
  - superpowers:verification-before-completion
  - superpowers-chrome:browsing
  - playwright-skill:playwright-skill
  - dev-squad:frontend-patterns
  - dev-squad:react-stack-2026
  - dev-squad:accessibility
```

Replace with:

```yaml
skills:
  - frontend-design:frontend-design
  - ui-ux-pro-max
  - superpowers:brainstorming
  - superpowers:verification-before-completion
  - superpowers-chrome:browsing
  - playwright-skill:playwright-skill
  - dev-squad:frontend-patterns
  - dev-squad:react-stack-2026
  - dev-squad:accessibility
  - dev-squad:crisp-patterns
```

- [ ] **Step 2: Add CRISP Gate to Phase 3.5 output check**

In `agents/designer.md`, find the output check section (search for `### Output check`):

```markdown
### Output check (verify before handing back to coordinator)

- [ ] All 4 artifacts exist in `.dev-squad/design/`
- [ ] design-tokens.md has concrete values (no TBD), all categories filled
- [ ] visual-spec.md has ≥ 3 reference URLs with screenshots in `.dev-squad/design/refs/`
- [ ] visual-spec.md anti-pattern list is project-specific (not pasted boilerplate)
- [ ] component-inventory.md covers every component implied by PRD's pages
- [ ] responsive-spec.md has wireframes for every page in PRD, at least 3 breakpoints each
- [ ] Reduced-motion fallback explicitly stated
- [ ] Dark mode policy stated
- [ ] No emoji used as icon spec; SVG library named
```

Replace with (append the CRISP Gate block after the existing 9 items):

```markdown
### Output check (verify before handing back to coordinator)

- [ ] All 4 artifacts exist in `.dev-squad/design/`
- [ ] design-tokens.md has concrete values (no TBD), all categories filled
- [ ] visual-spec.md has ≥ 3 reference URLs with screenshots in `.dev-squad/design/refs/`
- [ ] visual-spec.md anti-pattern list is project-specific (not pasted boilerplate)
- [ ] component-inventory.md covers every component implied by PRD's pages
- [ ] responsive-spec.md has wireframes for every page in PRD, at least 3 breakpoints each
- [ ] Reduced-motion fallback explicitly stated
- [ ] Dark mode policy stated
- [ ] No emoji used as icon spec; SVG library named

### CRISP Gate (mandatory — same weight as the 9 items above)

- [ ] Every component in component-inventory.md has a `purposeful` justification
      (one sentence: "this component exists to ___") — vague entries blocked
- [ ] No two components have overlapping primary function — if overlap exists,
      merge or remove the redundant one before handoff to frontend
- [ ] Initialize `.dev-squad/component-registry.json` from component-inventory.md
      using the schema in the crisp-patterns skill
      (fields: name/path/aliases/variants/states/crisp.purposeful/owner/phase_created)
- [ ] Every token in design-tokens.md has at least one component that uses it —
      tokens with no consumer are dead tokens, remove them
- [ ] Responsive spec covers ALL components in inventory, not just page-level layouts
```

- [ ] **Step 3: Verify the section was added correctly**

```bash
grep -n "CRISP Gate" agents/designer.md
```

Expected: one match at the line after the original 9-item checklist.

```bash
grep -n "crisp-patterns" agents/designer.md
```

Expected: two matches — one in frontmatter skills list, one in the CRISP Gate section.

- [ ] **Step 4: Commit**

```bash
git add agents/designer.md
git commit -m "feat: add CRISP gate to designer Phase 3.5 output check"
```

---

### Task 3: Edit frontend.md — Reuse-First Protocol + skill load

**Files:**
- Modify: `agents/frontend.md`

- [ ] **Step 1: Add crisp-patterns to skills frontmatter**

In `agents/frontend.md`, find the skills block in the YAML frontmatter:

```yaml
skills:
  - superpowers:test-driven-development
  - dev-squad:verification
  - superpowers:verification-before-completion
  - frontend-design:frontend-design
  - dev-squad:frontend-patterns
  - dev-squad:tdd-workflow
  - dev-squad:react-stack-2026
  - dev-squad:react-testing
  - dev-squad:accessibility
```

Replace with:

```yaml
skills:
  - superpowers:test-driven-development
  - dev-squad:verification
  - superpowers:verification-before-completion
  - frontend-design:frontend-design
  - dev-squad:frontend-patterns
  - dev-squad:tdd-workflow
  - dev-squad:react-stack-2026
  - dev-squad:react-testing
  - dev-squad:accessibility
  - dev-squad:crisp-patterns
```

- [ ] **Step 2: Insert Reuse-First Protocol as Step 0**

In `agents/frontend.md`, find the section heading:

```markdown
## DESIGN ARTIFACTS WORKFLOW (Before Coding ANY UI)

**You do NOT design. The designer agent designs.** Your job is to translate designer's spec into code with zero deviation.

### Step 1: Read ALL 4 Designer Artifacts (BLOCKING — cannot skip)
```

Replace with:

```markdown
## DESIGN ARTIFACTS WORKFLOW (Before Coding ANY UI)

**You do NOT design. The designer agent designs.** Your job is to translate designer's spec into code with zero deviation.

### Step 0: Reuse-First Protocol (BLOCKING — before any component work)

Before creating ANY new component file, you MUST:

1. **Query component registry**
   Read `.dev-squad/component-registry.json` if it exists.
   Search for your intended component name AND its common aliases (e.g. searching
   for "Button" should also check "Btn", "CTA", "ActionButton").

2. **Decision tree:**
   - Registry has an **exact or alias match** → USE the existing component.
     Do not create a new file. Extend via a new variant or prop if needed.
   - Registry has a **partial match** (similar name or function) → EXTEND the
     existing component via a new variant/prop. Update the registry entry.
   - **No match** → CREATE the new file. Then ADD an entry to the registry
     with ALL fields filled: name, path, aliases, variants, states,
     crisp.purposeful, owner, phase_created.
   - Registry **doesn't exist yet** → Designer hasn't completed Phase 3.5.
     Flag this to coordinator before writing any component.

3. **Registry update after creating a new component (mandatory):**
   Edit `.dev-squad/component-registry.json` and add the new entry.
   `crisp.purposeful` must be a real one-sentence justification — not empty,
   not "general purpose". Empty purposeful = incomplete task, coordinator rejects.

4. **CRISP self-check before submitting each component:**
   - **Consistent:** every value comes from design-tokens.md — no inline `text-[#abc]` or `mt-[17px]`
   - **Responsive:** breakpoints match responsive-spec.md at 375px / 768px / 1280px
   - **Intuitive:** hover/focus/disabled/loading states visually distinct; errors near their source
   - **Simple:** no props unused by any currently-rendered screen; file ≤ 200 lines
   - **Purposeful:** `crisp.purposeful` in registry is filled and you'd stand behind it in a review

The hook `check-component-reuse.sh` will emit a warning if it detects a new
`src/components/**/*.tsx` file whose name fuzzy-matches an existing registry entry.
Do not dismiss the warning without either (a) updating the registry to explain the
distinction, or (b) reusing the existing component instead.

### Step 1: Read ALL 4 Designer Artifacts (BLOCKING — cannot skip)
```

- [ ] **Step 3: Verify insertion**

```bash
grep -n "Step 0\|Reuse-First\|crisp-patterns" agents/frontend.md | head -10
```

Expected: Step 0 heading visible, Reuse-First Protocol heading visible, crisp-patterns in frontmatter.

- [ ] **Step 4: Confirm Step 1 still exists after the insertion**

```bash
grep -n "Step 1: Read ALL 4" agents/frontend.md
```

Expected: one match.

- [ ] **Step 5: Commit**

```bash
git add agents/frontend.md
git commit -m "feat: add Reuse-First Protocol + CRISP self-check to frontend agent"
```

---

### Task 4: Create check-component-reuse.sh hook

**Files:**
- Create: `hooks/check-component-reuse.sh`

- [ ] **Step 1: Write the hook script**

Create `hooks/check-component-reuse.sh`:

```bash
#!/bin/bash
# dev-squad: PostToolUse(Write) hook
# Warns when a new component file name fuzzy-matches an existing registry entry.
# Non-blocking — always exits 0. Warning only.

# Parse file_path from Write tool stdin JSON
FILE_PATH=$(cat - 2>/dev/null | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('file_path', ''))
except Exception:
    print('')
" 2>/dev/null)

# Only act on src/components/**/*.tsx paths
if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

if [[ ! "$FILE_PATH" =~ src/components/.*\.tsx$ ]]; then
  exit 0
fi

# Extract component name from filename (strip path + extension, lowercase)
COMPONENT_NAME=$(basename "$FILE_PATH" .tsx | tr '[:upper:]' '[:lower:]')

# Find registry — walk up from cwd to find .dev-squad/component-registry.json
REGISTRY=""
DIR="$PWD"
for _ in 1 2 3 4 5; do
  if [[ -f "$DIR/.dev-squad/component-registry.json" ]]; then
    REGISTRY="$DIR/.dev-squad/component-registry.json"
    break
  fi
  DIR=$(dirname "$DIR")
done

# No registry found — designer hasn't initialized it yet, skip
if [[ -z "$REGISTRY" ]]; then
  exit 0
fi

# Extract existing component names + aliases from registry via python3
MATCH=$(python3 - "$COMPONENT_NAME" "$REGISTRY" <<'PYEOF'
import sys, json

new_name = sys.argv[1].lower()
registry_path = sys.argv[2]

def levenshtein(a, b):
    if len(a) < len(b):
        return levenshtein(b, a)
    if len(b) == 0:
        return len(a)
    prev = list(range(len(b) + 1))
    for i, ca in enumerate(a):
        curr = [i + 1]
        for j, cb in enumerate(b):
            curr.append(min(prev[j + 1] + 1, curr[j] + 1, prev[j] + (ca != cb)))
        prev = curr
    return prev[len(b)]

# Strip common suffixes that don't distinguish components
STRIP = ("form", "list", "item", "card", "view", "wrapper", "container")
def normalize(s):
    s = s.lower()
    for suffix in STRIP:
        if s.endswith(suffix) and len(s) > len(suffix):
            s = s[:-len(suffix)]
    return s

with open(registry_path) as f:
    registry = json.load(f)

normalized_new = normalize(new_name)

for component in registry.get("components", []):
    candidates = [component.get("name", "")] + component.get("aliases", [])
    for candidate in candidates:
        norm_cand = normalize(candidate.lower())
        # Match on: exact, substring, or Levenshtein ≤ 2
        if (normalized_new == norm_cand
                or normalized_new in norm_cand
                or norm_cand in normalized_new
                or levenshtein(normalized_new, norm_cand) <= 2):
            print(f"{component['name']}|{component.get('path','?')}")
            sys.exit(0)
PYEOF
)

if [[ -n "$MATCH" ]]; then
  EXISTING_NAME=$(echo "$MATCH" | cut -d'|' -f1)
  EXISTING_PATH=$(echo "$MATCH" | cut -d'|' -f2)
  echo "" >&2
  echo "[CRISP] Component reuse warning:" >&2
  echo "  New file: $FILE_PATH" >&2
  echo "  Matches existing: $EXISTING_NAME at $EXISTING_PATH" >&2
  echo "" >&2
  echo "  Options:" >&2
  echo "  1. USE the existing component — don't create a new file" >&2
  echo "  2. EXTEND via new variant/prop — update registry entry" >&2
  echo "  3. GENUINELY different — add crisp.purposeful justification to registry" >&2
  echo "" >&2
fi

exit 0
```

- [ ] **Step 2: Make executable**

```bash
chmod +x hooks/check-component-reuse.sh
```

- [ ] **Step 3: Test — non-component path (should produce no output)**

```bash
echo '{"tool_name":"Write","tool_input":{"file_path":"src/pages/home.tsx","content":""}}' \
  | bash hooks/check-component-reuse.sh 2>&1
```

Expected: empty output (no warning, no error).

- [ ] **Step 4: Test — component path, no registry (should produce no output)**

```bash
echo '{"tool_name":"Write","tool_input":{"file_path":"src/components/ui/Button.tsx","content":""}}' \
  | bash hooks/check-component-reuse.sh 2>&1
```

Expected: empty output (no registry found, hook skips gracefully).

- [ ] **Step 5: Test — component path, registry exists with matching entry (should warn)**

Create a temporary test registry:

```bash
mkdir -p /tmp/crisp-test/.dev-squad
cat > /tmp/crisp-test/.dev-squad/component-registry.json <<'EOF'
{
  "version": 1,
  "components": [
    {
      "name": "Button",
      "path": "src/components/ui/Button.tsx",
      "aliases": ["Btn", "CTA"],
      "variants": ["primary"],
      "states": ["default"],
      "crisp": { "purposeful": "Primary action trigger" },
      "owner": "frontend",
      "phase_created": 4
    }
  ]
}
EOF

cd /tmp/crisp-test && \
echo '{"tool_name":"Write","tool_input":{"file_path":"src/components/ui/Btn.tsx","content":""}}' \
  | bash /Users/sadewadee/Downloads/Plugin\ Pro/dev-squad-plugin/hooks/check-component-reuse.sh 2>&1
```

Expected output contains:
```
[CRISP] Component reuse warning:
  New file: src/components/ui/Btn.tsx
  Matches existing: Button at src/components/ui/Button.tsx
```

- [ ] **Step 6: Clean up test registry**

```bash
rm -rf /tmp/crisp-test
```

- [ ] **Step 7: Commit**

```bash
cd "/Users/sadewadee/Downloads/Plugin Pro/dev-squad-plugin"
git add hooks/check-component-reuse.sh
git commit -m "feat: add check-component-reuse hook for CRISP enforcement"
```

---

### Task 5: Wire hook in hooks.json

**Files:**
- Modify: `hooks/hooks.json`

- [ ] **Step 1: Add PostToolUse Write entry for the new hook**

In `hooks/hooks.json`, find the `"PostToolUse"` array. It currently has three entries
(Write|Edit for auto-lint, Grep|Bash for truncation-check, Write|Edit|Bash for observe-learning).

Add a new entry as the **first** item in the PostToolUse array (before auto-lint):

```json
"PostToolUse": [
  {
    "matcher": "Write",
    "hooks": [
      {
        "type": "command",
        "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/check-component-reuse.sh\""
      }
    ]
  },
  {
    "matcher": "Write|Edit",
    "hooks": [
      {
        "type": "command",
        "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/auto-lint.sh\"",
        "async": true
      }
    ]
  },
  {
    "matcher": "Grep|Bash",
    "hooks": [
      {
        "type": "command",
        "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/truncation-check.sh\""
      }
    ]
  },
  {
    "matcher": "Write|Edit|Bash",
    "hooks": [
      {
        "type": "command",
        "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/observe-learning.sh\"",
        "async": true
      }
    ]
  }
]
```

- [ ] **Step 2: Validate JSON is well-formed**

```bash
python3 -c "import json; json.load(open('hooks/hooks.json')); print('OK')"
```

Expected: `OK`

- [ ] **Step 3: Verify the new entry is present**

```bash
python3 -c "
import json
d = json.load(open('hooks/hooks.json'))
entries = d['hooks']['PostToolUse']
matchers = [e['matcher'] for e in entries]
print(matchers)
assert 'Write' in matchers, 'Missing Write-only entry'
print('check-component-reuse entry found')
"
```

Expected output:
```
['Write', 'Write|Edit', 'Grep|Bash', 'Write|Edit|Bash']
check-component-reuse entry found
```

- [ ] **Step 4: Commit**

```bash
git add hooks/hooks.json
git commit -m "feat: wire check-component-reuse hook to PostToolUse(Write)"
```

---

### Task 6: Bump version + final commit

**Files:**
- Modify: `.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`

- [ ] **Step 1: Bump version in plugin.json**

In `.claude-plugin/plugin.json`, change `"version": "4.29.0"` to `"version": "4.30.0"`.

- [ ] **Step 2: Bump version in marketplace.json**

In `.claude-plugin/marketplace.json`, change `"version": "4.29.0"` to `"version": "4.30.0"`.

- [ ] **Step 3: Verify both files show 4.30.0**

```bash
python3 -c "
import json
pv = json.load(open('.claude-plugin/plugin.json'))['version']
mv = json.load(open('.claude-plugin/marketplace.json'))['version']
assert pv == '4.30.0', f'plugin.json version wrong: {pv}'
assert mv == '4.30.0', f'marketplace.json version wrong: {mv}'
print(f'Both files: {pv} OK')
"
```

Expected: `Both files: 4.30.0 OK`

- [ ] **Step 4: Commit and tag**

```bash
git add .claude-plugin/plugin.json .claude-plugin/marketplace.json
git commit -m "feat: v4.30.0 — CRISP enforcement (hook + protocol + registry)"
git tag v4.30.0
```

- [ ] **Step 5: Final sanity check — all expected files exist**

```bash
test -f skills/crisp-patterns/SKILL.md && echo "crisp-patterns skill: OK"
grep -q "crisp-patterns" agents/designer.md && echo "designer skill load: OK"
grep -q "CRISP Gate" agents/designer.md && echo "designer CRISP gate: OK"
grep -q "crisp-patterns" agents/frontend.md && echo "frontend skill load: OK"
grep -q "Reuse-First Protocol" agents/frontend.md && echo "frontend reuse-first: OK"
test -x hooks/check-component-reuse.sh && echo "hook executable: OK"
python3 -c "import json; d=json.load(open('hooks/hooks.json')); [e['matcher'] for e in d['hooks']['PostToolUse']].index('Write'); print('hook wired: OK')"
```

Expected: all 7 lines print OK.
