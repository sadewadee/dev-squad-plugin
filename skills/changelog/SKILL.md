---
name: changelog
description: >
  Turn git history into user-facing release notes — the missing step between
  "PRs merged" and "release exists". Reads commits since the last tag, groups
  them by impact, translates conventional-commit subjects into language a user
  (not a committer) understands, and drops internal noise. Use at Phase 6/7 SHIP
  before tagging a release, and whenever the user says "changelog", "release
  notes", "what changed", "what's in this release", or "generate the CHANGELOG".
license: MIT
---

# Changelog — git history to release notes

A raw `git log` is a committer's diary, not a release note. This turns the
history since the last release into something a user reads: what they can now
do, what changed under them, what got fixed, what to watch out for. It runs at
the SHIP gate so a release never ships without notes.

## When this fires

Phase 6/7 (SHIP), before tagging a version — or on demand. After the release's
PRs are merged to the release branch.

## Inputs

```bash
git describe --tags --abbrev=0 2>/dev/null   # last release tag (may be empty on first release)
git log <last-tag>..HEAD --no-merges --pretty='%s%n%b%x1e'   # commits since it (or full history if no tag)
date +%Y-%m-%d                                # release date (agents cannot guess the date — read it)
```

## Method

1. **Group by impact**, not by commit order. Use Keep-a-Changelog sections, dropping any that are empty:
   - **Added** (new features — `feat:`)
   - **Changed** (behavior/UX changes, including breaking — `feat!`/`refactor` with user impact)
   - **Fixed** (`fix:`)
   - **Security** (security-relevant fixes)
   - **Removed** (deprecations/removals)
2. **Translate to the user's vocabulary.** `feat: add cursor pagination to /users` → "User lists now page through large result sets without timing out." Describe the capability, not the code.
3. **Merge related commits** into one line (three commits building one feature = one entry).
4. **Drop internal noise** unless user-visible: `chore`, `ci`, `test`, `style`, pure refactors, dependency bumps with no behavior change. (If a refactor changed behavior, it belongs in Changed.)
5. **Surface breaking changes first**, clearly marked `**BREAKING:**`, with the migration step.

## Output

A CHANGELOG.md entry in Keep a Changelog format (prepend to the file's top, under any `## [Unreleased]`):

```markdown
## [<version>] - <YYYY-MM-DD>

### Added
- <user-facing capability>.

### Fixed
- <what no longer breaks, in user terms>.
```

If nothing user-visible shipped (only chores/refactors): say so — `No user-facing changes since <tag>; internal only.` — do not manufacture entries.

## Scope guard

Summarize, do not transcribe. A 40-commit release is not 40 bullets — it is the
handful of things a user would notice. Padding the changelog to look busy is the
inverse of the job.

<!-- Concept adapted from claude-code-plugins-plus-skills (mattyp-changelog), MIT. -->
