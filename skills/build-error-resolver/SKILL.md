---
name: build-error-resolver
description: Focused build/compile/type error fix protocol for dev-squad agents. Triggers during the self-healing author-retry tier (iterations 1-2) when a build, compile, or type-check command fails. Walks through a 4-step protocol (Capture, Fix, Verify, Escalate) to resolve the error with the smallest possible diff and no architectural side-effects.
---

# Build Error Resolver - Minimal-Diff Fix Protocol for Dev Squad

## INSTRUCTIONS: When this skill is invoked

Work through the four steps below in order. The goal is the smallest diff that makes the build green. Do not refactor, do not silence the compiler, do not introduce new abstractions. If two attempts at the same error have not produced a green build, stop and escalate — do not keep trying variations.

Core rule: **Minimal diff only. If the real fix requires a design change, escalate — never change architecture or silence the compiler to make a build error disappear.**

---

## Step 1: Capture

Goal: obtain the exact error text, file, and line before writing any code.

1. Run the failing build/compile/type-check command verbatim and capture the full output. If the output was already shown (e.g. from the agent's failed build attempt), quote it directly — do not re-run unnecessarily.
2. Identify in the output:
   - The error code or message (e.g. `TS2345`, `cannot find symbol`, `undefined reference to 'X'`).
   - The first file path and line number that belongs to this codebase (not a generated file, not a library frame).
3. If the build output is ambiguous or truncated, use ide diagnostics to get the full diagnostic list for the file identified above.
4. Do not open unrelated files. Read only the file and line the error directly implicates.

Record: error message, file path, and line number.

---

## Step 2: Fix

Goal: apply the smallest change that resolves the stated error at the captured location.

**What is allowed:**

- Correcting a wrong type annotation to match the actual value or interface.
- Adding a missing import or export.
- Removing an unused import that blocks compilation.
- Correcting a function signature mismatch (argument count, type, return type) to match the call site or the callee — whichever is wrong.
- Fixing a misspelled identifier.
- Adding a required field that is missing from a struct, object, or interface literal.
- Narrowing or widening a type where the existing types prove the current annotation is incorrect.

**What is not allowed — escalate instead:**

- Adding `any`, `unknown` casts, or generic widening to suppress a type error.
- Adding `@ts-ignore`, `// eslint-disable`, `# type: ignore`, `//nolint`, or any other suppression annotation — unless that pattern is already used in the surrounding code in this codebase.
- Changing an interface, schema, or data contract that is shared across more than one file (that is a design change, not a fix).
- Introducing a new abstraction (utility function, type alias, base class) that did not exist before this error.
- Refactoring or renaming anything beyond the minimum required to resolve the specific error.
- Touching files other than the one (or two, in the case of a caller/callee mismatch) identified in Step 1.

Apply the fix. Write nothing else.

---

## Step 3: Verify

Goal: confirm the build is green by re-running the exact same command that failed.

1. Re-run the exact build/compile/type-check command from Step 1 — not a shorter variant, not a related command, the same one.
2. Examine the output:
   - **Green (no errors):** The fix was correct. Proceed. No further action in this skill.
   - **Same error persists:** The fix did not address the root cause. Revert the change and record what you learned. Proceed to Step 4.
   - **Different error:** The original error may be resolved and a new one exposed. Evaluate: if the new error is in the same file and is a direct consequence of your fix (e.g. you corrected a type and now an adjacent annotation is inconsistent), you may apply one additional minimal fix and re-run. If the new error is in a different file or is unrelated, treat this as a separate error and note it for the next iteration — do not chain fixes across unrelated errors in a single attempt.

Record: the exact command re-run output.

---

## Step 4: Escalate

**2-attempt cap.** If the same error persists after 2 fix-and-verify cycles, stop immediately.

Do not:
- Try a third variation of the same fix.
- Widen types to silence the error.
- Introduce a suppression annotation.
- Restructure the surrounding code hoping the error goes away.

Do:
- Revert any changes that did not produce a green build.
- Write a short escalation summary (see format below) and hand control back to the self-healing loop's next tier.

The thrashing rule applies here: two failed attempts on the same error is a signal the fix requires judgment at a higher level — either the architect or the user.

---

## Escalation Summary Format

When escalating after the 2-attempt cap, output:

```
## Build Error Escalation

**Command:** <exact build command>
**Error:** <error code and message>
**Location:** <file path>:<line>
**Attempt 1:** <what was changed> — result: <still failing / different error>
**Attempt 2:** <what was changed> — result: <still failing / different error>
**Assessment:** <one sentence on why the fix is not straightforward>
**Recommended next step:** <architect review / design change / user input>
```

Hand this summary to the coordinator. Do not attempt further fixes in the author-retry tier.

---

Self-contained. Does not require any external MCP server or plugin. If ide diagnostics is available, use it in Step 1 to obtain precise file-and-line information before reading code.
