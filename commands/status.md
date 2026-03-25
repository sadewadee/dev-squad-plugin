---
name: status
description: Show current dev-squad swarm progress including active agents, completed phases, and blockers.
---

# /dev-squad status

## INSTRUCTIONS: When `/dev-squad status` is invoked

Check the current state of any active dev-squad workflow and report progress.

### Steps

1. **Check for active workflow**:
   - Look for `.dev-squad/workflow-active` in the current project directory
   - If found, read and parse the workflow status

2. **Check for running agents**:
   - Report which agents are currently active
   - Report what phase/task each agent is working on

3. **Report format**:

```
[Dev Squad Status]
==================================================
Workflow: {workflow type or "No active workflow"}
Project: {description from workflow file}
Started: {timestamp}

Phase Progress:
  [x] DISCOVER  -- {status}
  [x] DESIGN    -- {status}
  [ ] SCAFFOLD  -- {status}
  [ ] IMPLEMENT -- {status}
  [ ] REVIEW    -- {status}
  [ ] SHIP      -- {status}

Active Agents:
  - {agent}: {current task}
  - {agent}: {current task}

Completed Deliverables:
  - {deliverable 1}
  - {deliverable 2}

Blockers:
  - {blocker or "None"}

Risk Level: {low|medium|high}
==================================================
```

4. **If no workflow is active**:
   - Check git status for any dev-squad related branches
   - Report recent dev-squad activity if any
   - Suggest starting a new workflow

### Implementation

```
1. Read .dev-squad/workflow-active (if exists)
2. Parse phase statuses
3. Check for any active Task agents
4. Compile and display status report
5. If no workflow file exists, report "No active workflow"
```
