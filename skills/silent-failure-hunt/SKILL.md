---
name: silent-failure-hunt
description: >
  Hunt for failures that never surface — the bugs no test and no error log will
  catch because the code swallows them. Finds empty catch blocks, errors logged
  but not raised, ignored return values, unhandled promise rejections, bare
  excepts, and discarded Go errors. Use during Phase 5 review and in QA failure
  analysis, whenever code touches error paths, or when the user says "silent
  failure", "swallowed error", "why didn't this throw", "it fails quietly", or
  "find hidden bugs".
license: MIT
---

# Silent-failure hunt — the errors that never surface

QA catches what breaks loudly. This catches what breaks quietly: the `catch {}`
that eats an exception, the error written to a log and then ignored, the return
value nobody checks. These do not fail a test or page anyone — they corrupt data
and mislead users in silence. They are the most expensive class of bug because
nothing tells you they happened.

## When this fires

Phase 5 (REVIEW) and QA failure analysis, on the diff first, then on error-path
code. This is a candidate-finder + triage pass, not a pure linter: the grep
surfaces suspects; you judge each.

## Step 1 — surface candidates (deterministic grep)

Run against the changed files (or a path). Skip vendored/build dirs. Adjust the
globs to the project's languages:

```bash
# Swallowed/empty exception handling
rg -n --pcre2 'catch\s*\([^)]*\)\s*\{\s*\}' --type ts --type js          # empty catch
rg -n -B1 -A3 '\bcatch\b' --type ts --type js | rg -n 'console\.(log|warn)'  # catch that only logs
rg -n 'except[^\n]*:\s*\n\s*(pass|\.\.\.|continue)\b' --pcre2 --type py    # bare except: pass
rg -n 'except\s*:' --type py                                              # blanket except

# Discarded results / errors
rg -n '_\s*[,)]?\s*=\s*[a-zA-Z]' --type go | rg -v '// '                   # Go: err assigned to _ (no justifying comment)
rg -n '\bif err != nil\b' -A2 --type go | rg -n '^\s*\}'                   # Go: empty err branch (inspect)
rg -n '\.then\(' --type ts --type js | rg -v '\.catch\('                   # promise without .catch (inspect)
rg -n '\bawait\b' --type ts --type js                                      # await — confirm inside try or has handler

# Shell / CI masking
rg -n '\|\|\s*true|2>/dev/null|set \+e' --type sh                          # failures masked
```

(If `rg` is unavailable, use `grep -rnE`. Confirm regex behavior — `--pcre2` is needed for some.)

## Step 2 — triage each candidate

A hit is a suspect, not a verdict. For each, classify:

- **Real silent failure** — an error path that loses data, skips work, or hides a fault from the caller with no signal. REPORT it.
- **Intentional + justified** — the swallow is deliberate AND a comment says why (e.g. `// simp: best-effort cache warm, safe to drop`, a documented optional cleanup). ACCEPT it; if justified but uncommented, ask for the comment.
- **False positive** — the pattern matched but the error is genuinely handled (rethrown, returned, surfaced to the user, retried). DISMISS it.

Never simplify away real error handling (that is the inverse of `simp` — here you are *adding* the missing surfacing, not removing code).

## Output

```
Silent failures (real):
- <file>:<line> — <what is swallowed> → <consequence>. Fix: <surface it / return / rethrow / alert>.
Unjustified swallows (need a comment or a fix):
- <file>:<line> — <pattern>
Dismissed: <count> candidates (handled correctly)
```

If none survive triage: `No silent failures on <scope>. Error paths surface correctly.`

<!-- Concept adapted from ecc (silent-failure-hunter agent), MIT. Reframed as a review-time skill. -->
