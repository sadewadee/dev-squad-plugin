# Companion Plugins for Dev-Squad

Dev-squad agents are designed to work standalone but reach **maximum capability** when companion plugins + MCP servers are installed. Companions are invoked **on-demand via the `Skill` tool**, never always-loaded. All companions are **graceful-degrade** — if not installed, agents fall back to native methodology.

## Quick start

```
/dev-squad bootstrap
```

This command:
- Reads `.claude-plugin/companions.json` manifest
- Detects what's installed vs missing
- Auto-installs missing **MCPs** via `claude mcp add` (per-item user confirmation)
- Outputs **plugin install commands** for user copy-paste (plugin install is slash-command-only by Claude Code design)

---

## Tier 1: Required

### superpowers (REQUIRED)

Methodology skills used across all phases: brainstorming, writing-plans, test-driven-development, systematic-debugging, verification-before-completion, dispatching-parallel-agents, finishing-a-development-branch, using-git-worktrees, executing-plans, subagent-driven-development.

**Install:**
```
/plugin marketplace add obra/superpowers-marketplace
/plugin install superpowers@superpowers-marketplace
```

If not installed: agents will fail at most Phase 1+ checkpoints. Install before first use.

---

## Tier 2: Recommended

### ui-ux-pro-max (Anti-AI-slop design intelligence)

**Used by:** `designer` agent in **Phase 3.5 UI DESIGN** only.

**What it provides:**
- 161 product-type-aware design systems
- 161 color palettes with reasoning
- 99 UX guidelines
- 57 font pairings
- 50+ UI styles
- 25 chart types
- 10 stacks (React, Next.js, Vue, Svelte, SwiftUI, React Native, Flutter, Tailwind, shadcn/ui, HTML/CSS)

**Why it matters:**
Designer agent translates ui-ux-pro-max output into 4 dev-squad artifacts (`design-tokens.md`, `visual-spec.md`, `component-inventory.md`, `responsive-spec.md`). Without it, designer designs from scratch — output quality is significantly lower.

**Install:**
```
/plugin marketplace add nextlevelbuilder/ui-ux-pro-max-skill
/plugin install ui-ux-pro-max@ui-ux-pro-max-skill
```

**Fallback if not installed:** designer uses `frontend-design` skill + manual WebSearch references.

**Suppression rule:** designer agent only invokes ui-ux-pro-max during Phase 3.5. Auto-activation outside that phase is suppressed (designer prompt explicitly forbids it). This avoids conflict with controlled phase dispatch.

---

### gsd (Get Shit Done) — Spec-driven discipline

**Used by:** `coordinator`, `architect`, `auditor`, `reviewer`, `git-ops`.

**Skill mapping:**

| Skill | Invoked by | Phase | What it does |
|---|---|---|---|
| `gsd-new-project` | coordinator | 0 ULTRAPLAN | Bootstraps PROJECT.md / REQUIREMENTS.md / ROADMAP.md / STATE.md |
| `gsd-discuss-phase` | architect | 1 DISCOVER | Spec-driven discussion before plan |
| `gsd-plan-phase` | architect | 2 ARCHITECT | Spec-driven planning |
| `gsd-plan-checker` | architect | 2 ARCHITECT | Plan review loop (until verified) |
| `gsd-execute-phase` | coordinator | 4 IMPLEMENT | Wave model + atomic commit per task |
| `gsd-verify-work` | auditor | 5 VERIFY | Scope drift detection (vs REQUIREMENTS.md) |
| `gsd-audit-milestone` | auditor | 5 VERIFY | Milestone-level audit |
| `gsd-secure-phase` | reviewer | 5 REVIEW | Security gate spec-driven |
| `gsd-pr-branch` | git-ops | 6 SHIP | PR pattern |
| `gsd-ship` | git-ops | 6 SHIP | Atomic ship pattern |

**Why it matters:**
- **Schema drift detection** — flags ORM changes missing migrations
- **Scope drift detection** — prevents planner from silently dropping requirements
- **Atomic commit per task** — verifiable per-task vs whole-feature commits

**Install:**
```
npx get-shit-done-cc@latest
```

Or via plugin marketplace (verify exact ID):
```
/plugin marketplace add gsd-build/get-shit-done
/plugin install gsd-build-get-shit-done
```

**Fallback if not installed:** native methodology in agent prompts (less rigorous).

---

### frontend-design (Anthropic skill)

**Used by:** `designer`, `frontend`.

**What it provides:** Distinctive, production-grade frontend interfaces. Avoids generic AI aesthetics.

**Install:** typically bundled with default Claude Code skills. Check `Skill list` for `frontend-design:frontend-design`.

---

### code-review

**Used by:** `reviewer`.

**What it provides:** Structured PR review skill.

---

### playwright-skill

**Used by:** `qa-engineer` (Phase 5.5 functional verification + Visual Gate), `designer` (reference screenshots).

**What it provides:** Browser automation, golden-path testing, visual regression.

---

### superpowers-chrome

**Used by:** `qa-engineer`, `designer`.

**What it provides:** Direct Chrome DevTools Protocol — inspect cached browser content, DOM, console, network. Used for runtime debugging + reference site analysis.

---

### episodic-memory

**Used by:** `coordinator` (Phase 7 LEARN), all agents (bootstrap context).

**What it provides:** Cross-session memory — recover decisions/solutions from past conversations.

---

### claude-md-management

**Used by:** `coordinator` (Phase 7 LEARN).

**What it provides:** Audit + improve CLAUDE.md files; update with project learnings.

---

## Tier 3: MCP Servers (Recommended)

### context7

```
claude mcp add context7 -- npx -y @upstash/context7-mcp
```

**Used by:** all agents.
**What:** Library/framework documentation lookup. Verify any framework claim before advising.

### sequential-thinking

```
claude mcp add sequential-thinking -- npx -y @modelcontextprotocol/server-sequential-thinking
```

**Used by:** coordinator, architect.
**What:** Multi-step structured reasoning for complex decisions.

### mermaid-mcp

```
claude mcp add mermaid-mcp -- npx -y @rtuin/mcp-mermaid
```
*Note: package name may vary. Check current marketplace.*

**Used by:** architect.
**What:** Architecture C4 diagrams.

### grep-github

For cross-repo code search (GitHub). Reference: see https://grep.app or alternative.

**Used by:** all agents (Phase 1 DISCOVER, debugging).
**What:** Find production patterns in real OSS repos.

---

## Invocation pattern

Companion skills are invoked via `Skill` tool in agent code:

```
# Inside an agent's flow:
Skill("ui-ux-pro-max", args="<feature description>")  # Phase 3.5
Skill("gsd-plan-phase", args="<input>")                # Phase 2
Skill("superpowers:brainstorming")                     # Anywhere
```

If the skill is not installed, the call returns an error — agent treats this as fallback signal and continues with native methodology.

**Do NOT** wrap in availability check. Try-catch pattern (try invocation; fallback on error) avoids state-cache mismatches.

---

## Companion install summary

```
# Required
/plugin marketplace add obra/superpowers-marketplace
/plugin install superpowers@superpowers-marketplace

# Recommended plugins
/plugin marketplace add nextlevelbuilder/ui-ux-pro-max-skill
/plugin install ui-ux-pro-max@ui-ux-pro-max-skill

npx get-shit-done-cc@latest

# Recommended MCPs (auto-installed by /dev-squad bootstrap)
claude mcp add context7 -- npx -y @upstash/context7-mcp
claude mcp add sequential-thinking -- npx -y @modelcontextprotocol/server-sequential-thinking
```

---

## Why companion vs full-takeover

GSD has its own workflow (`/gsd-new-project`, etc.) — we cherry-pick its skills rather than ceding orchestration. This way:
- **You can run dev-squad standalone** (no companion install required for basics).
- **You can layer GSD on top** (run `/gsd-execute-phase` and use dev-squad swarm inside it).
- **You can pick-and-choose** — install ui-ux-pro-max but skip GSD if you don't need spec-driven planning.

UI-UX Pro Max similarly: it auto-activates on UI keywords by default. Designer agent suppresses that default and invokes it only in Phase 3.5 — controlled dispatch.

---

## Rate-limit budget impact

All companion skills run at **sonnet tier** (no opus quota impact):
- `ui-ux-pro-max` — sonnet
- `gsd-*` — sonnet
- `superpowers:*` — varies (skill-internal logic)
- `code-review`, `playwright`, etc. — sonnet

Opus quota remains untouched by companion invocation. Designer (sonnet think_harder) calls ui-ux-pro-max (sonnet) = single sonnet budget tier.

---

## See also

- `.claude-plugin/workflows/` — canonical workflow JSONs that reference companion skills
- `docs/workflow-mapping.md` — phase-by-phase mapping with skill columns
- `agents/coordinator.md` — companion-skill bootstrap context
