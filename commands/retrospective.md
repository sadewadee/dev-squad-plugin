---
name: retrospective
description: Run a PDCA Act-phase retrospective on completed work. Captures wins to playbook, gaps to fix-it backlog, lessons to memory. Use after features, sprints, post-incidents, or on a recurring cadence.
---

# /dev-squad retrospective

Trigger an explicit Act phase outside of zero-to-ship. Zero-to-ship's Phase 7 LEARN runs this automatically; this command runs the same retrospective on any completed work.

## INSTRUCTIONS: When `/dev-squad retrospective` is invoked

Launch the coordinator with the retrospective workflow:

```
Agent tool with:
- subagent_type: "dev-squad:coordinator"
- description: "Retrospective: <short summary>"
- prompt: |
    You are the coordinator. Run a PDCA Act-phase retrospective.

    ## Scope
    {user input — feature name, sprint date range, incident, or "since last retrospective"}

    ## Step 1: Gather inputs
    - Recent commits and PRs in scope (`git log` + `gh pr list`)
    - All `.dev-squad/gotchas.md` entries from this period
    - Test/build/deploy metrics if available (CI logs, monitoring dashboards)
    - Open issues and recurring user complaints
    - Self-healing loop fires (count + root causes)
    - Time spent per task vs estimated

    ## Step 2: Dispatch reviewer to produce retrospective report

    Reviewer writes `.dev-squad/retrospectives/YYYY-MM-DD-<scope>.md`:

    ```markdown
    # Retrospective: {scope}

    Date: {YYYY-MM-DD}
    Period: {start} → {end}

    ## What worked
    - {pattern that produced clean results}
      - Context: {when this applies}
      - Reusable in: {feature dev | new project | bug fix | infra}

    ## What didn't work
    - {pattern that caused rework}
      - What went wrong: {specific}
      - Next time: {concrete change}
      - Owner: {agent or user}

    ## Metric movement (if measurable)
    | Metric | Previous | Current | Δ | Direction |
    |--------|----------|---------|---|-----------|
    | {test coverage, build time, error rate, etc.} |

    ## Process observations
    - Self-healing loop fired N times — root causes: {list}
    - Two-stage review caught X issues
    - Tasks that ran longer than estimated: {list with reasons}

    ## Decisions to standardize
    - {convention that should now be default — propose CLAUDE.md update}
    ```

    ## Step 3: Update artifacts
    - Append "What worked" entries to `.dev-squad/playbook.md`
    - Append "What didn't work" entries as fix-it tickets in `docs/next-iteration.md`
    - Update project `CLAUDE.md` with new standardized conventions
    - Write key lessons to agent-memory and episodic memory

    ## Step 4: Report to user
    - Link to retrospective file
    - Top 3 wins
    - Top 3 fix-it items (proposed, with owners)
    - Suggest cadence: "Want to /schedule weekly retrospectives?"

    ## Evidence-grounding (mandatory for Check + Plan-next)
    Before writing the retrospective:
    - WebSearch for industry benchmarks if proposing new metric targets ("p95 API latency benchmark for {domain}")
    - context7 for any library/framework where a "what didn't work" item involves outdated API usage
    - grep-github for production patterns matching wins worth standardizing
```

## When to run

- After a feature is merged to main
- After a sprint completes
- After a bug fix is deployed (especially production incidents — post-mortem)
- Weekly cadence for ongoing projects (use `/schedule` to automate)

## Common cadence pattern

```bash
# Weekly retrospective every Monday morning
/schedule "every Monday at 09:00" "/dev-squad retrospective since last retrospective"
```

## Output artifacts

- `.dev-squad/retrospectives/YYYY-MM-DD-<scope>.md` — the retrospective report itself
- `.dev-squad/playbook.md` — accumulating wins (what to repeat)
- `docs/next-iteration.md` — fix-it backlog (what to change)
- Updated `CLAUDE.md` — standardized conventions
- Memory writes — lessons for future projects
