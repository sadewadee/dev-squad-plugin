---
description: Git workflow, conventional commits, and PR standards
globs: "*"
---

# Git Workflow

## Conventional Commit Format

Every commit message MUST follow this format:

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

### Commit Types

| Type | When to Use |
|------|-------------|
| `feat` | New feature or capability |
| `fix` | Bug fix |
| `refactor` | Code change that neither fixes a bug nor adds a feature |
| `docs` | Documentation only changes |
| `test` | Adding or updating tests |
| `chore` | Build process, tooling, dependency updates |
| `perf` | Performance improvement |
| `ci` | CI/CD pipeline changes |

### Rules

- Type is **required**, scope is recommended
- Description is imperative mood, lowercase, no period: "add user auth" not "Added user auth."
- Body wraps at 72 characters, explains **why** not **what**
- Footer references issues: `Closes #123`

## Pull Request Workflow

1. **Analyze the full commit history** from branch point to HEAD -- not just the latest commit
2. **Write a comprehensive summary** covering all changes in the PR
3. **Include a test plan** with specific steps to verify the changes

### PR Template

```markdown
## Summary
- <bullet points covering all changes>

## Test Plan
- [ ] <specific verification steps>
```

### PR Rules

- Keep PRs focused on a single concern
- PRs over 400 lines should be split
- Always target the correct base branch
- Delete the branch after merge

## Branch Strategy

| Branch | Purpose |
|--------|---------|
| `main` | Production-ready code, protected |
| `develop` | Integration branch for features |
| `feat/<name>` | New feature work |
| `fix/<name>` | Bug fix work |
| `release/<version>` | Release preparation |
| `hotfix/<name>` | Urgent production fix |

### Branch Rules

- Branch from `develop` for features and fixes
- Branch from `main` for hotfixes
- Never commit directly to `main` or `develop`
- Keep branches short-lived (merge within days, not weeks)
