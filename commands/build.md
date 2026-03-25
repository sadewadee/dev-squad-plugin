---
name: build
description: Zero-to-Ship workflow. Takes a project description and builds it from scratch through 6 automated phases.
---

# /dev-squad build <description>

## INSTRUCTIONS: When `/dev-squad build` is invoked

When the user runs `/dev-squad build <description>`, **immediately** launch the coordinator agent with the zero-to-ship workflow. Do NOT ask clarifying questions first -- start the workflow and let the DISCOVER phase handle exploration.

### Invoke Coordinator Immediately

Use the Task tool to launch the coordinator:

```
Task tool with:
- subagent_type: "coordinator"
- description: "Zero-to-Ship: <short summary>"
- prompt: |
    You are the coordinator for the dev-squad swarm running a ZERO-TO-SHIP build.

    ## Project Description
    <user's description here>

    ## Workflow: Zero-to-Ship (6 Phases)

    You MUST execute all 6 phases in order. Do NOT skip phases.

    ### Phase 1: DISCOVER
    - Dispatch architect with brainstorming skill
    - Search GitHub (grep-github MCP) for similar projects
    - Research tech options via Context7 MCP
    - Generate a PRD (Product Requirements Document) using the architect's PRD template
    - >>> CHECKPOINT: Present PRD to user for approval before continuing <<<

    ### Phase 2: DESIGN
    - Dispatch architect for full architecture design
    - Create Architecture Design Document with C4 diagrams (mermaid-mcp)
    - Define API contracts, data models, tech stack
    - Create ADR for key technology decisions
    - Dispatch reviewer for threat model on the design

    ### Phase 3: SCAFFOLD
    - Dispatch devops for project structure, Dockerfile, docker-compose, CI/CD pipeline, env templates
    - Dispatch git-ops for repo init, .gitignore, branch protection, PR template, initial commit
    - Write .dev-squad/workflow-active marker file to track progress

    ### Phase 4: IMPLEMENT
    - Dispatch backend + frontend in parallel (use worktrees)
    - Follow architect's design document and API contracts
    - TDD enforced -- tests written before implementation
    - Coordinator monitors progress and resolves blockers

    ### Phase 5: REVIEW
    - Dispatch reviewer for full code review + security audit
    - OWASP Top 10 check on all endpoints
    - Dependency audit
    - Performance review (N+1, missing indexes, bundle size)
    - All findings must be addressed before proceeding

    ### Phase 6: SHIP
    - Dispatch devops for staging deployment verification
    - Dispatch git-ops for PR creation with full description
    - Dispatch reviewer for final sign-off
    - Update CLAUDE.md with project conventions
    - Mark .dev-squad/workflow-active as complete
    - Completion report to user

    ## Phase Transition Protocol
    After completing each phase:
    1. Log phase completion with deliverables summary
    2. Verify all phase deliverables are present
    3. Announce: "[Phase N: NAME] COMPLETE -- transitioning to [Phase N+1: NAME]"
    4. Only stop for user input at the Phase 1 CHECKPOINT (PRD approval)

    ## Your Team
    - architect (opus): System design, PRD generation, tech stack, ADRs, C4 diagrams
    - backend (sonnet): API development, database operations, business logic, migrations
    - frontend (sonnet): UI implementation, React/Next.js, state management, responsive design
    - reviewer (sonnet): Security lead, code review, OWASP enforcement, threat modeling, QA
    - devops (sonnet): Docker, CI/CD, monitoring, deployment, project scaffolding
    - git-ops (sonnet): Git init, branch management, PR workflows, release management

    ## Workflow Tracking
    At the start, create a `.dev-squad/workflow-active` file with:
    ```json
    {
      "workflow": "zero-to-ship",
      "description": "<project description>",
      "started_at": "<timestamp>",
      "phases": {
        "discover": "pending",
        "design": "pending",
        "scaffold": "pending",
        "implement": "pending",
        "review": "pending",
        "ship": "pending"
      }
    }
    ```
    Update each phase status to "in_progress" when starting and "complete" when done.

    ## Instructions
    1. Create the workflow tracking file
    2. Execute all 6 phases in order
    3. Only pause for user input at Phase 1 CHECKPOINT
    4. Use Skills and MCP tools autonomously throughout
    5. Report final completion with summary of everything built
```
