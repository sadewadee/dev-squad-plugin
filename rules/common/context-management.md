# Context Management

## Context Degradation Patterns

Watch for these 5 failure modes — detect and mitigate immediately:

### 1. Lost-in-Middle
**Signal**: Agent ignores information from middle of long conversations
**Detection**: Agent makes decisions contradicting earlier context
**Fix**: Repeat critical info at the end of prompts, or write to file and re-read

### 2. Context Poisoning
**Signal**: Incorrect information early in conversation propagates to all later decisions
**Detection**: Multiple wrong outputs sharing same root assumption
**Fix**: Challenge assumptions explicitly, verify against source files

### 3. Context Distraction
**Signal**: Agent focuses on irrelevant details, ignores important ones
**Detection**: Response addresses tangential concern while missing primary task
**Fix**: Frontload the most important instruction, minimize noise

### 4. Context Confusion
**Signal**: Agent conflates two different concepts or files
**Detection**: Agent applies pattern from file A while editing file B
**Fix**: Be explicit about which file/context you're working in

### 5. Context Clash
**Signal**: Contradictory instructions cause inconsistent behavior
**Detection**: Agent oscillates between two approaches
**Fix**: Resolve contradictions explicitly before proceeding

## Compression Strategies

When context grows large:

1. **Write before compact** — save key decisions to files BEFORE context compaction
2. **Compact at boundaries** — after research/before implementation, after planning/before coding
3. **Never compact mid-implementation** — variable names and partial state will be lost
4. **Use sub-agents for research** — keeps research tokens out of main context
5. **Summarize, don't accumulate** — replace long tool outputs with key findings

## Context Budget

Treat context as a finite attention budget:
- **First 20%**: Highest attention — put critical instructions here
- **Middle 60%**: Reduced attention — put reference material here
- **Last 20%**: Moderate attention — put reminders and checklists here
