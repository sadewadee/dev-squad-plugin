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
# it — this enforces it deterministically. Substring regex is both leaky (whitespace, flags,
# alternate tools) AND over-broad (matches the word inside `echo`/`grep` args), so detection is
# command-POSITION based: tokenize on separators, skip env-assignments/sudo, and only match when
# the destructive binary is the actual command being run. (kill -SIG <pid> stays prose-guarded:
# too ambiguous to match without false-positiving on legitimate process kills.) Flag present = allowed.
# Fast path: only invoke python when a trigger word is present at all.
if [ ! -f ".dev-squad/staging-env" ] && printf '%s' "$COMMAND" | grep -Eqw 'iptables|ip6tables|nft|pkill|systemctl|docker|docker-compose|podman'; then
  STAGING_VERDICT=$(python3 - "$COMMAND" <<'PY' 2>/dev/null
import sys, re, os, shlex
cmd = sys.argv[1] if len(sys.argv) > 1 else ""
SIMPLE = {"iptables", "ip6tables", "nft", "pkill"}
def hit(c):
    for seg in re.split(r"&&|\|\||\||;|\n", c):
        try: toks = shlex.split(seg)
        except Exception: toks = seg.split()
        i = 0
        while i < len(toks) and (re.match(r"^[A-Za-z_]\w*=", toks[i]) or toks[i] in ("sudo", "env", "nohup", "time", "exec", "command")):
            i += 1
        if i >= len(toks): continue
        base = os.path.basename(toks[i]); rest = toks[i+1:]
        if base in SIMPLE: return True
        if base == "systemctl" and any(a in ("stop", "kill", "restart", "mask") for a in rest): return True
        if base in ("docker", "podman"):
            # plain form: docker stop|kill|rm <ctr>
            if rest[:1] and rest[0] in ("stop", "kill", "rm"): return True
            # management-command form (canonical since Docker 1.13): docker container|service|stack stop|kill|rm
            if len(rest) >= 2 and rest[0] in ("container", "service", "stack") and rest[1] in ("stop", "kill", "rm"): return True
            if rest[:2] == ["network", "disconnect"]: return True
            if rest[:1] == ["compose"] and any(a in ("stop", "kill", "down", "rm") for a in rest[1:]): return True
        if base == "docker-compose" and any(a in ("stop", "kill", "down", "rm") for a in rest): return True
        # NOTE: 'restart' is deliberately NOT blocked — it is self-healing (the service comes back)
        # and a routine ops action (config reload / bounce); the auditor's failure injection uses
        # 'stop' (sustained outage), not 'restart'. Blocking restart would false-positive on legit ops.
    return False
print("BLOCK" if hit(cmd) else "OK")
PY
)
  if [ "$STAGING_VERDICT" = "BLOCK" ]; then
    echo "BLOCKED by dev-squad safety guard: '$COMMAND' is destructive failure-injection / teardown (service stop|kill|down|rm, network manipulation, process kill), allowed only in an isolated staging env. Create .dev-squad/staging-env (confirms: ephemeral, no real users, no real data) first, or run it manually outside dev-squad."
    exit 2
  fi
fi

exit 0
