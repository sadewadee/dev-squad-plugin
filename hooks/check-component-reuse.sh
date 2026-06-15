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

# Fuzzy match component names + aliases from registry
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
