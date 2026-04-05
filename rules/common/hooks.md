---
description: Hook rules for PreToolUse, PostToolUse, and Stop events
globs: "*"
---

# Hook Rules

## PreToolUse Hooks

PreToolUse hooks run **before** a tool executes. Use them for validation and gatekeeping.

### Common PreToolUse Patterns

- **File write validation**: Check that the target path is within the project directory
- **Destructive command guard**: Block `rm -rf`, `git reset --hard`, `DROP TABLE` unless explicitly confirmed
- **Secret detection**: Scan content being written for API keys, tokens, or passwords
- **Size check**: Warn if a file being written exceeds 800 lines

## PostToolUse Hooks

PostToolUse hooks run **after** a tool completes. Use them for auto-formatting and verification.

### Common PostToolUse Patterns

- **Auto-format on save**: Run the language formatter (Prettier, gofmt, black) after file writes
- **Lint check**: Run the linter after code changes and report issues immediately
- **Test runner**: Run affected tests after implementation changes
- **Import organizer**: Sort and clean imports after file modifications

## Stop Hooks

Stop hooks run **before the agent completes** its response. Use them for final verification.

### Common Stop Patterns

- **Completeness check**: Verify all TODO items from the plan are addressed
- **Test verification**: Confirm all tests pass before declaring work done
- **Security audit**: Run a final scan for secrets or vulnerabilities
- **Console.log audit**: Check that no debug logging remains in production code

## TodoWrite Best Practices

- Break work into small, specific items (one action per TODO)
- Mark items complete as they are finished -- do not batch
- Use priority levels to order work: HIGH items first
- Include enough context in each item that it can be understood independently

## Auto-Accept Permission Guidance

Configure auto-accept for safe, read-only operations:

- File reads and searches: safe to auto-accept
- Git status and log: safe to auto-accept
- File writes within project directory: safe with PostToolUse formatting hook
- External network calls: require explicit approval
- Destructive operations: never auto-accept
