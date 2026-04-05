---
description: Agent orchestration rules for the dev-squad swarm
globs: "*"
---

# Agent Orchestration

## Available Agents

| Agent | Role | Use When |
|-------|------|----------|
| **coordinator** | Orchestrates workflow, delegates tasks | Starting any multi-step project or feature |
| **architect** | System design, tech stack decisions | New projects, major refactors, design reviews |
| **backend** | API, database, server-side logic | Building endpoints, data models, business logic |
| **frontend** | UI components, styling, client logic | Building interfaces, forms, interactivity |
| **reviewer** | Code review, quality enforcement | Before merging, after implementation complete |
| **devops** | CI/CD, deployment, infrastructure | Setting up pipelines, Docker, cloud config |
| **git-ops** | Git workflow, branching, commits | Branch management, release tagging, merge conflicts |

## Parallel Execution Rules

- Dispatch agents in parallel when tasks have **no shared state**
- Backend and frontend agents CAN run in parallel after architect defines contracts
- Reviewer MUST run after implementation agents complete
- Git-ops runs last, after reviewer approves
- Coordinator monitors all agents and resolves conflicts

## Multi-Perspective Analysis

When facing architectural decisions:

1. **Architect** proposes the design
2. **Backend** validates feasibility from server perspective
3. **Frontend** validates feasibility from client perspective
4. **Reviewer** checks for anti-patterns and risks
5. **Coordinator** synthesizes and makes final call

## Delegation Rules

- Never skip the planning phase -- always start with coordinator or architect
- Each agent owns its domain; do not have backend write UI code
- If an agent encounters work outside its domain, it reports back to coordinator
- Agents must document assumptions and decisions for downstream agents
