#!/bin/bash
# dev-squad: PreToolUse hook for Bash
# Block dangerous commands that agents should never run

# Read command from stdin JSON
COMMAND=$(cat - 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null)

if [ -z "$COMMAND" ]; then
  exit 0
fi

# Block patterns
# NOTE: force-push is only blocked when targeting protected branches (main/master).
# Force-push to feature branches is legitimate workflow (rebase, history cleanup).
# Both long-form (--force), short-form (-f), and force-with-lease variants caught.
# NOTE: rm -rf is handled by RM_ROOT_REGEX below, not this list — substring matching
# on "rm -rf /" or "rm -rf ." false-positives on legitimate subpaths like
# "rm -rf /tmp/scratch" or "rm -rf ./node_modules".
BLOCKED_PATTERNS=(
  "DROP DATABASE"
  "DROP TABLE"
  "TRUNCATE TABLE"
  "git push --force origin main"
  "git push --force origin master"
  "git push -f origin main"
  "git push -f origin master"
  "git push --force-with-lease origin main"
  "git push --force-with-lease origin master"
  "git push -f origin main:"
  "git push -f origin master:"
  "git reset --hard origin"
  ":(){ :|:& };:"
  "mkfs."
  "dd if="
  "> /dev/sda"
  "kubectl delete namespace"
  "kubectl delete ns "
  "terraform destroy"
  "aws s3 rb"
)

# rm -rf (or -fr) targeting a filesystem root exactly — /, ~, ., $HOME — optionally
# with a trailing slash or quotes. Subpaths (rm -rf /tmp/x, rm -rf ./node_modules,
# rm -rf ~/scratch) are allowed.
RM_ROOT_REGEX='rm -(rf|fr)[[:space:]]+"?(/|~|\.|\$HOME)/?"?([[:space:]]|$|;)'

if echo "$COMMAND" | grep -Eq "$RM_ROOT_REGEX"; then
  echo "BLOCKED by dev-squad safety guard: rm -rf targeting a filesystem root (/, ~, ., \$HOME). If this is intentional, run it manually outside dev-squad."
  exit 2
fi

for pattern in "${BLOCKED_PATTERNS[@]}"; do
  if echo "$COMMAND" | grep -qiF "$pattern"; then
    echo "BLOCKED by dev-squad safety guard: command matches dangerous pattern '$pattern'. If this is intentional, run it manually outside dev-squad."
    exit 2
  fi
done

# Conditional guard: failure injection / destructive env manipulation (auditor Bucket D) is
# permitted ONLY in an isolated staging env, signalled by the .dev-squad/staging-env flag.
# auditor.md carries a prose "HARD GUARD" for this, but prose fires only if the agent remembers
# to include it — this enforces the highest-risk patterns deterministically. (kill -SIG of a
# worker pid stays prose-guarded: too ambiguous to match without false-positiving on legitimate
# process kills.) When the flag IS present, these are allowed.
if [ ! -f ".dev-squad/staging-env" ]; then
  if echo "$COMMAND" | grep -Eq 'iptables|docker[ -]compose (stop|kill)'; then
    echo "BLOCKED by dev-squad safety guard: '$COMMAND' is a failure-injection / destructive environment operation, allowed only in an isolated staging env. Create .dev-squad/staging-env (confirms: ephemeral, no real users, no real data) first, or run it manually outside dev-squad."
    exit 2
  fi
fi

exit 0
