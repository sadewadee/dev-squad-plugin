---
name: verification
description: Self-contained pre-done verification protocol for dev-squad agents. Triggers before any agent claims a task or feature complete (before commit, before reporting done). Runs build, typecheck, lint, tests, secrets scan, and diff self-review, then produces a PASS/FAIL report card. Language-agnostic; detects project type automatically.
---

# Verification - Before-Done Protocol for Dev Squad

## INSTRUCTIONS: When this skill is invoked

Run every step below in order before claiming any task or feature is complete. Do not report "done", commit, or signal completion to the coordinator until this protocol produces a PASS verdict. If any step fails, fix the issue and re-run that step before continuing.

Core rule: **Evidence before claims — run the commands fresh, never assert success from memory.**

---

## Step 1: Detect Project Type

Identify the project type by checking for these files in the current working directory:

| File present | Project type |
|---|---|
| `package.json` or `tsconfig.json` | Node.js / TypeScript / JavaScript |
| `go.mod` | Go |
| `pyproject.toml` or `setup.py` | Python |
| `Cargo.toml` | Rust |
| Multiple matches | Run checks for each matching type |

If no recognized project file is found, skip Steps 2-5 and proceed to Step 6 (diff self-review).

---

## Step 2: Build / Compile

Verify the project compiles with no errors.

**Node.js / TypeScript:**
```
npx tsc --noEmit
```
If `tsconfig.json` does not exist, run:
```
npm run build
```

**Go:**
```
go build ./...
```

**Python:**
No explicit compile step. Proceed to Step 3.

**Rust:**
```
cargo build
```

Record result: PASS if exit code 0, FAIL otherwise. Capture the error count or first error line.

---

## Step 3: Typecheck

Run the language's static type checker.

**TypeScript:**
```
npx tsc --noEmit
```
(Same command as build — if already run in Step 2 and passed, record PASS without re-running.)

**Go:**
```
go vet ./...
```

**Python:**
```
mypy .
```
(Skip if mypy is not installed; note the skip in the report card.)

**Rust:**
Covered by `cargo build`. Record the same result.

---

## Step 4: Lint

Run the project's linter to catch style violations and common errors.

**TypeScript / JavaScript:**
```
npx eslint . --quiet
```
(Skip if ESLint is not installed in `node_modules`; note the skip.)

**Go (preferred, if installed):**
```
golangci-lint run ./...
```
Fallback if golangci-lint is not installed:
```
go vet ./...
```
(If go vet was already run in Step 3, record that result here too.)

**Python:**
```
ruff check .
```
(Skip if ruff is not installed; note the skip.)

**Rust:**
```
cargo clippy -- -D warnings
```

Record result: PASS if exit code 0 (or skipped with note), FAIL with error count if non-zero.

---

## Step 5: Tests

Run the full test suite. Do not run a subset unless the project has no way to run all tests at once.

**Node.js / TypeScript / JavaScript:**
```
npm test
```
(If no `test` script in `package.json`, note it and skip.)

**Go:**
```
go test ./...
```

**Python:**
```
pytest
```
(Skip if pytest is not installed; note the skip.)

**Rust:**
```
cargo test
```

Record result: PASS if all tests pass, FAIL with the failing test names or count.

---

## Step 6: Secrets Scan

Scan the staged diff (or recent changes) for hardcoded secret patterns before any commit.

Run this grep against the staged diff or the files you changed:

```
git diff --staged | grep -iE \
  '(api[_-]?key|secret|password|token|private[_-]?key|aws_access|stripe_secret|-----BEGIN)\s*[=:]\s*["'"'"'][^"'"'"']{8,}'
```

Also check that `.env` files (if present) are listed in `.gitignore`:
```
grep -l '\.env' .gitignore 2>/dev/null || echo ".env not in .gitignore — verify manually"
```

Record result: PASS if grep returns no matches, FAIL and list the matched lines if any are found. A secrets hit is a hard blocker — do not commit until the secret is removed and the history is clean.

---

## Step 7: Diff Self-Review

Read the full diff of your changes and answer these questions before reporting done:

1. **Scope** — Does the diff match the task description exactly? Are there any unrelated changes?
2. **Stubs / placeholders** — Does the diff contain any `TODO`, `FIXME`, `HACK`, `placeholder`, `stub`, or `not implemented` comments that were not there before?
3. **Leftover debug output** — Any `console.log`, `fmt.Println`, `print()`, or similar debug statements that should not be in production code?
4. **Skipped logic** — Any function that returns early, panics, or throws "not implemented" that the task required to be finished?
5. **File hygiene** — Any accidentally committed build artifacts, lock file conflicts, or `.DS_Store` / `__pycache__` entries?

Run:
```
git diff HEAD
```
or, if changes are staged:
```
git diff --staged
```

Record result: PASS if all five answers are clean, FAIL and list the specific issue for each that is not clean.

---

## Report Card

After running all steps, output a report card in this format:

```
## Verification Report Card

| Step | Status | Notes |
|---|---|---|
| 1. Project type detected | [type detected] | |
| 2. Build / compile | PASS / FAIL | [error count or first error] |
| 3. Typecheck | PASS / FAIL / SKIPPED | [detail] |
| 4. Lint | PASS / FAIL / SKIPPED | [error count] |
| 5. Tests | PASS / FAIL / SKIPPED | [failing tests or count] |
| 6. Secrets scan | PASS / FAIL | [matched lines if FAIL] |
| 7. Diff self-review | PASS / FAIL | [issues found] |

**Overall: PASS / FAIL**
```

**PASS** requires every step to be PASS (or SKIPPED with a documented reason). Any FAIL means the work is not done. Fix the failures and re-run the affected steps before reporting complete.

Do not emit "Overall: PASS" if any step is FAIL. Do not proceed with commit or completion report until the overall verdict is PASS.

---

## Relation to stop-verify.sh

The `hooks/stop-verify.sh` hook runs a subset of this protocol automatically on agent Stop events (build, typecheck, lint, tests — for TS/Go/Python). This skill covers those same checks plus secrets scan (Step 6) and diff self-review (Step 7), and runs them proactively before the agent reaches Stop rather than as a gate after.

The two are aligned and complementary: this skill catches problems early (before commit), and the hook catches any that slip through (before claiming done to the coordinator).

---

This is dev-squad's self-contained verification. If `superpowers:verification-before-completion` is also installed, it can be used as an additional pass — but this skill does not depend on it.
