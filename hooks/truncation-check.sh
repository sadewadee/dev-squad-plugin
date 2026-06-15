#!/bin/bash
# dev-squad: PostToolUse hook — truncation detection
# Inspired by iamfakeguru/claude-md truncation-check.sh
# Warns agent when tool output was truncated (>50K chars)
# Non-blocking — just adds context

HOOK_INPUT=$(cat - 2>/dev/null || echo "{}")

# Check for truncation markers in tool result
TRUNCATED=$(echo "$HOOK_INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    result = str(d.get('tool_result', ''))
    # Check for common truncation markers
    if 'Output too large' in result or 'output truncated' in result.lower():
        print('true')
    elif len(result) > 50000:
        print('true')
    else:
        print('false')
except:
    print('false')
" 2>/dev/null || echo "false")

if [ "$TRUNCATED" = "true" ]; then
  # Non-blocking warning (exit 0, not exit 2)
  echo '{"additionalContext": "WARNING: Tool output was truncated (~85k char limit). For large build/test commands, redirect to file and read selectively: `<command> 2>&1 | tee .dev-squad/logs/<agent>-<phase>.log && grep -E \"error:|Error|FAIL\" .dev-squad/logs/<agent>-<phase>.log`. For existing files: use Read with offset/limit. For search: use grep with a more specific pattern."}'
  exit 0
fi

exit 0
