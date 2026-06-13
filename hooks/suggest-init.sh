#!/bin/bash
# dev-squad: SessionStart hook — suggest /dev-squad init for uninitialized projects
# Prints a one-line tip when the project looks like a code repo but hasn't been
# initialized with dev-squad yet. Silently exits once .dev-squad/gotchas.md exists.

GOTCHAS_FILE=".dev-squad/gotchas.md"

# Already initialized — nothing to say
if [ -f "$GOTCHAS_FILE" ]; then
  exit 0
fi

# Detect common project root files that indicate a real code project
if [ -f "package.json" ] || [ -f "go.mod" ] || [ -f "pyproject.toml" ] || \
   [ -f "Cargo.toml" ] || [ -f "pom.xml" ] || [ -f "build.gradle" ]; then
  echo "TIP: Run /dev-squad init to onboard dev-squad to this project (generates architecture docs, tech debt analysis, and .dev-squad/gotchas.md)."
fi

exit 0
