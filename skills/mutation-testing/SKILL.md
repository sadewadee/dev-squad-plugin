---
name: mutation-testing
description: >
  Verify test QUALITY, not just coverage — the operational form of "tests
  encode intent" (dev-squad Rule 9). Mutates the code under test and measures
  how many mutants the suite kills; a surviving mutant is a regression the tests
  cannot catch. Use during Phase 5 review/verification on non-trivial logic
  (money, security, auth, parsers, state machines, branching), whenever a PR
  adds tests, or when the user says "mutation test", "are these tests any good",
  "test quality", "coverage lies", or doubts whether tests would catch a
  regression.
license: MIT
---

# Mutation testing — does the suite actually catch regressions?

Line coverage lies. A test can execute a line and assert nothing meaningful —
100% coverage, zero protection. Mutation testing is the measurement that does
not lie: change the code (flip `>` to `>=`, `&&` to `||`, delete a line, swap a
return) and see whether a test turns red. A mutant that survives is a concrete
regression your suite would let through.

This is dev-squad Rule 9 made executable: "a test that cannot fail when business
logic regresses is not a test."

## When this fires

Phase 5 (REVIEW / verification), AFTER the suite is green — never before. Target
the **changed logic in the diff**, not the whole repo (mutation testing is
expensive; a full-repo run is the over-build `simp` warns against). Reserve it
for non-trivial logic: money/billing math, auth/permission checks, parsers,
validators, state machines, anything with branches. Skip trivial glue, DTOs, and
generated code — YAGNI applies to mutation testing too.

## Tool per language

Run the tool that matches the stack; confirm the exact current invocation via
`context7` before running (flags drift between versions).

| Language | Tool | Typical invocation (scope to changed files) |
|----------|------|----------------------------------------------|
| JS / TS | **Stryker** | `npx stryker run --mutate "src/<changed-path>/**/*.ts"` |
| Python | **mutmut** (or cosmic-ray) | `mutmut run --paths-to-mutate <changed-path>` then `mutmut results` |
| Go | **go-mutesting** (or gremlins) | `gremlins unleash --tags "" ./<changed-pkg>/...` |
| Rust | **cargo-mutants** | `cargo mutants --file <changed-file>` |

If the tool is not installed and the project has no mutation-testing setup, do
NOT silently skip — report "no mutation tooling; recommend adding <tool>" and
fall back to manually inspecting the highest-risk function: hand-mutate one
branch and confirm a test fails.

## Workflow

1. Confirm the suite is green first (a red suite makes mutation results meaningless).
2. Run the tool scoped to the diff's logic.
3. Read the **surviving mutants**. Each survivor = a behavior change no test noticed.
4. For each survivor on real logic: write the smallest test that kills it (asserts the behavior the mutant broke). This is the deliverable — killing survivors is how test quality actually improves.
5. Set a sane bar: aim for a high mutation score on critical paths (≈80%+), not 100% everywhere. Equivalent mutants (semantically identical) are expected survivors — note them, do not chase them.

## Output

```
Mutation score: <killed>/<total> (<pct>%) on <scope>
Surviving mutants (real, not equivalent):
- <file>:<line> — <mutation> survived. Kill with: <one-line test description>.
Equivalent/ignored: <count> (<reason>)
Verdict: <PASS ≥ bar | tests insufficient — N survivors need killing tests>
```

If every meaningful mutant dies: `Suite kills all non-equivalent mutants on <scope>. Test quality verified.`

<!-- Concept adapted from claude-code-plugins-plus-skills (mutation-test-runner), MIT. Built on standard OSS mutation tools. -->
