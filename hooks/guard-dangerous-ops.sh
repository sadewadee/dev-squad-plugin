#!/bin/bash
# dev-squad: PreToolUse hook for Bash
# Block dangerous commands that agents should never run

# Read command from stdin JSON
COMMAND=$(cat - 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null)

if [ -z "$COMMAND" ]; then
  exit 0
fi

# Block patterns
BLOCKED_PATTERNS=(
  "rm -rf /"
  "rm -rf ~"
  "rm -rf \."
  "DROP DATABASE"
  "DROP TABLE"
  "TRUNCATE TABLE"
  "git push --force origin main"
  "git push --force origin master"
  "git reset --hard origin"
  ":(){ :|:& };:"
  "mkfs\."
  "dd if="
  "> /dev/sda"
)

for pattern in "${BLOCKED_PATTERNS[@]}"; do
  if echo "$COMMAND" | grep -qi "$pattern"; then
    echo "BLOCKED by dev-squad safety guard: command matches dangerous pattern '$pattern'. If this is intentional, run it manually outside dev-squad."
    exit 2
  fi
done

exit 0
