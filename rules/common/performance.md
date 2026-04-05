---
description: Performance rules including model selection and context management
globs: "*"
---

# Performance Rules

## Model Selection

Choose the right model for the task:

| Model | Use For | Share of Work |
|-------|---------|---------------|
| **Haiku** | Simple lookups, formatting, boilerplate generation, quick answers | ~10% |
| **Sonnet** | Daily coding, bug fixes, feature implementation, test writing | ~80% |
| **Opus** | Architecture decisions, complex debugging, multi-file refactors, security review | ~10% |

### Guidelines

- Default to Sonnet for most development tasks
- Escalate to Opus only for tasks requiring deep reasoning across many files
- Use Haiku for repetitive, well-defined subtasks to save cost and time
- When dispatching parallel agents, use Sonnet unless the subtask specifically needs Opus

## Context Window Management

- Keep prompts focused -- include only relevant code and context
- Summarize long files instead of including them whole
- Use file paths and line ranges instead of pasting entire files
- Break large tasks into subtasks to avoid context overflow
- When context is running low, summarize progress and start a fresh conversation

## Extended Thinking

Use extended thinking (Opus) for:

- Architectural decisions with multiple tradeoffs
- Complex debugging where the root cause is unclear
- Security analysis requiring threat modeling
- Multi-step refactors that must maintain correctness

Do NOT use extended thinking for:

- Simple CRUD operations
- Boilerplate generation
- Formatting or style fixes
- Well-understood bug fixes

## Debugging with Build Error Resolver

When encountering build or compilation errors:

1. Read the **full error output** -- do not truncate
2. Identify the **root cause**, not just the symptom
3. Check for **common causes** first: missing imports, typos, version mismatches
4. Fix the root cause, then verify the fix resolves all related errors
5. If the error persists after two attempts, escalate to Opus for deeper analysis

## Caching and Reuse

- Cache expensive computations and API responses where appropriate
- Reuse database connections via connection pooling
- Avoid N+1 queries -- use batch loading or joins
- Profile before optimizing -- measure, don't guess
