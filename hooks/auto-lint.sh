#!/bin/bash
# dev-squad: PostToolUse hook (async)
# Auto-lint/format files after Write/Edit operations
# Runs async so it doesn't block the agent

# Get the file path from hook input (stdin JSON)
FILE_PATH=$(cat - 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('file_path',''))" 2>/dev/null)

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Get file extension
EXT="${FILE_PATH##*.}"

case "$EXT" in
  ts|tsx|js|jsx|json|css|scss|html|md)
    # Try prettier first (most common formatter)
    if command -v npx &>/dev/null && [ -f "node_modules/.bin/prettier" ]; then
      npx prettier --write "$FILE_PATH" 2>/dev/null
    fi
    # Then eslint fix for JS/TS
    if [[ "$EXT" =~ ^(ts|tsx|js|jsx)$ ]] && [ -f "node_modules/.bin/eslint" ]; then
      npx eslint --fix "$FILE_PATH" 2>/dev/null
    fi
    ;;
  go)
    if command -v gofmt &>/dev/null; then
      gofmt -w "$FILE_PATH" 2>/dev/null
    fi
    ;;
  py)
    if command -v black &>/dev/null; then
      black --quiet "$FILE_PATH" 2>/dev/null
    elif command -v ruff &>/dev/null; then
      ruff format "$FILE_PATH" 2>/dev/null
    fi
    ;;
  rs)
    if command -v rustfmt &>/dev/null; then
      rustfmt "$FILE_PATH" 2>/dev/null
    fi
    ;;
esac

exit 0
