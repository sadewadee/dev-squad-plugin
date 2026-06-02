---
name: debugging
description: Self-contained structured debugging protocol for dev-squad agents. Triggers on any bug, test failure, or unexpected behavior — BEFORE proposing or applying a fix. Walks through a 4-phase loop (Reproduce, Locate, Hypothesize, Fix+Verify) to identify and eliminate the root cause with evidence at every step.
---

# Debugging - Root-Cause Protocol for Dev Squad

## INSTRUCTIONS: When this skill is invoked

Work through the five phases below in order before writing any fix. **Phase 0 (recall) is mandatory and comes first** — never treat a bug as new before searching past sessions and known traps. Do not propose a solution until you have completed Phase 1 (you can reproduce the failure) and Phase 3 (you have a single, stated hypothesis about the root cause). If a fix does not eliminate the failure, revert it and start Phase 3 again — do not stack speculative changes on top of each other.

Core rules:
- **Fix root cause, not symptom.** A symptom fix hides the bug; a root-cause fix removes it.
- **One change at a time.** Multiple simultaneous changes make it impossible to know which one (if any) worked.
- **Evidence before claims.** Never assert the fix worked — re-run the exact failing command and show the output.

---

## Phase 0: Recall (before anything else)

Goal: do not re-debug a solved problem or re-try an approach already rejected in a past session.

1. Dispatch the `search-conversations` agent (episodic-memory) for this bug's symptom, the verbatim error text, and the component/file involved. If agent dispatch is unavailable, call the episodic-memory `search` MCP tool directly, then `read` the top 2-5 hits.
2. Read `.dev-squad/gotchas.md` (also injected at session start by the SubagentStart hook) — this exact trap may already be logged.
3. If recall surfaces a prior root cause or a rejected fix: state it explicitly and start from there. Do not silently re-derive it.
4. If recall returns nothing relevant, say so in one line and proceed. Recall is not optional — only its result is.

Record: what past sessions / gotchas said about this symptom (or "no prior record").

---

## Phase 1: Reproduce

Goal: confirm you can trigger the failure on demand before forming any theory.

1. Identify the exact command or sequence that produces the failure (test command, curl call, script invocation, etc.).
2. Run it. Capture the full output — error message, stack trace, or unexpected result — verbatim.
3. If you cannot reproduce it, stop here. State that the failure is not reproducible in the current environment and ask the user for more context (environment, inputs, steps). Do not guess.

Record: the exact command and its full output. This is your baseline.

---

## Phase 2: Locate

Goal: narrow the failure to a specific file and line before reading broadly.

1. Read the error message carefully. Identify the first file and line number mentioned in the stack trace or compiler output that is part of this codebase (not a library or runtime frame).
2. Read that file — the function that contains the failing line and its immediate callers.
3. If the error message does not point to a specific line, use the error text to identify the most likely module or function, then read that code.
4. Do not read the entire codebase. Read only what the error directly implicates, then expand only if Phase 3 requires it.

Record: the file path, line number, and the relevant code snippet.

---

## Phase 3: Hypothesize

Goal: state one falsifiable root-cause hypothesis before writing any code.

1. Based on what you read in Phase 2, form a single hypothesis: "The failure is caused by X." X must be a specific condition in the code — not "something is wrong with the logic."
2. State what you expect to be true if this hypothesis is correct. For example: "If this is the cause, then changing Y should make the test pass" or "If this is the cause, then reading variable Z at line N should show value W."
3. Do not form multiple hypotheses simultaneously and try them all at once. Pick the most likely one. If it is wrong after Phase 4, you will return here with the new evidence and form the next hypothesis.

Record: the hypothesis in one sentence and what outcome would confirm or refute it.

---

## Phase 4: Fix and Verify

Goal: apply the minimal change that targets your hypothesis, then confirm it with the original failing command.

1. Make the smallest possible change that addresses the root cause stated in Phase 3. Touch only what the hypothesis requires. Do not clean up adjacent code, refactor, or add features in the same change.
2. Re-run the exact command captured in Phase 1 — not a different test, not a related command, the exact same one.
3. Examine the output:
   - **Green (failure gone):** The hypothesis was correct. Record what the fix was and why it worked. Proceed to commit.
   - **Still failing (same error):** The hypothesis was wrong or incomplete. Revert the change (restore the file to its Phase 3 state). Return to Phase 3 with the new information you have. Do not leave the speculative change in place.
   - **Different error:** The original bug may be fixed but a new one was exposed, or the change introduced a regression. Evaluate which case it is, then either treat the new error as a fresh debugging session or revert and re-examine Phase 2.
4. After a green result, verify that no other tests regressed:

**Node.js / TypeScript / JavaScript:**
```
npm test
```

**Go:**
```
go test ./...
```

**Python:**
```
pytest
```

**Rust:**
```
cargo test
```

Record: the fix, the re-run output, and the regression-check result.

---

## Iteration Rule

If you have cycled through Phase 3 and Phase 4 three times without a green result, stop and summarize:
- What you have tried.
- What each attempt revealed.
- What you believe the next avenue of investigation is.

Report this to the coordinator or user before continuing. Three failed hypotheses is a signal the problem scope is larger than initially understood.

---

## Output Format

After Phase 4 produces a green result, output a short debugging summary:

```
## Debugging Summary

**Failing command:** <exact command>
**Root cause:** <one sentence>
**Fix:** <file path, what changed, and why>
**Verified by:** re-running the failing command — output: [PASS / test count]
**Regression check:** [PASS / SKIPPED — reason]
```

Do not write this summary until Phase 4 is complete and green.

---

Self-contained — no external dependency. If `superpowers:systematic-debugging` is installed, it can be used as an additional technique, but this skill does not require it.
