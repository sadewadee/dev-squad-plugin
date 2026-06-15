# dev-squad v5 Improvement Plan

**Source patterns:** ECC (Everything Claude Code) by affaan-m
**Target:** `sadewadee/dev-squad-plugin` v4.9.0 → v5.x
**Author:** minah analisis untuk Sadewa
**Date:** May 2026
**PATH:** /Downloads/Plugin\ Pro/claude-plugins/ecc

---

## TL;DR

dev-squad sekarang adalah **opinionated workflow system yang tightly orchestrated** (Phase 3.5 Design Gate, 3-way Phase 5 review, SaaS intake → ADR chain). Tapi fundamentally **static**—run ke-10 nggak lebih pintar dari run ke-1.

ECC sebaliknya: **self-improving via instinct → skill evolution + observability via state store + cross-harness adapter pattern**, tapi nggak opinionated.

**Goal v5**: Adopt ECC's architectural patterns supaya dev-squad jadi **opinionated + self-improving + observable**. Itu unique combination yang nggak ada di harness lain.

---

## Gap Analysis

| Dimension | dev-squad v4.9 | ECC | Gap |
|---|---|---|---|
| Workflow opinionatedness | ✓✓✓ (9 PDCA phases, blocking gates) | ○ (skills-first, no fixed flow) | ECC weakness, dev-squad strength |
| Cross-project learning | ✗ (project-isolated) | ✓✓ (instincts cluster → skills) | **Critical gap** |
| Observability | △ (markdown files) | ✓✓ (SQLite state store) | **Critical gap** |
| Model routing strategy | △ (mostly opus + sonnet hardcoded) | ✓ (per-task complexity) | Cost gap |
| Context budgeting | ✗ (front-loaded) | ✓ (on-demand retrieval) | Token gap |
| Cross-harness support | ✗ (Claude Code only) | ✓✓ (6+ harnesses) | Distribution gap |
| Selective install | ✗ (monolithic) | ✓ (profile-driven) | Adoption friction |
| Health checks | ✗ | ✓ (doctor + repair) | Reliability gap |
| Adversarial review | △ (static OWASP) | ✓ (AgentShield 3-agent pipeline) | Security depth gap |
| i18n | ✗ (English only) | ✓ (9 languages) | Market gap |

---

## Improvements Ranked by Impact

### Tier 1: Foundational (Must Do)

#### #1 Continuous Learning Layer

**Problem:** Phase 7 LEARN cuma update CLAUDE.md untuk project itu sendiri. Cross-project knowledge = nol.

**Pattern from ECC:** `continuous-learning-v2` — extract instincts from runs → cluster → graduate ke skills.

**Implementation:**

After Phase 7, jalankan instinct extractor yang scan:
- ULTRAPLAN scope decisions
- ADRs yang akhirnya ship-ready vs yang superseded
- Designer Phase 3.5 artifacts yang lolos Visual Gate vs ditolak
- Self-healing retry counts + handoff reasons
- qa-engineer veto reasons + auditor finding patterns
- SaaS intake answers correlated with retrofit phases

**Instinct schema:**
```json
{
  "instinct_id": "uuid",
  "trigger_pattern": "SaaS Block 1 Q1=enterprise AND Q4=annual_billing",
  "action": "ADR-005 audit_log_retention defaults 7 years",
  "evidence": [
    {"project_id": "wacrm", "outcome": "shipped"},
    {"project_id": "proj-x", "outcome": "shipped"},
    {"project_id": "proj-y", "outcome": "shipped"}
  ],
  "confidence": 0.85,
  "last_seen_at": "2026-05-15T10:00:00Z"
}
```

**Graduation criteria:** confidence ≥ 0.8 + evidence dari ≥ 3 distinct projects → cluster + graduate ke `skills/dev-squad-learned/<slug>/SKILL.md`.

**Effort:** Medium. SQLite (dari #3) + Phase 7 hook extension + `/dev-squad evolve` CLI command.

**Why critical:** Without ini, dev-squad always start dari nol. Dengan ini, dev-squad jadi **product yang improve over time**.

---

#### #3 SQLite State Store + Observability

**Problem:** State = `.dev-squad/master-plan.md` + scattered files. Nggak query-able. Nggak time-series. Nggak cross-project.

**Pattern from ECC:** SQLite + query CLI.

**Schema:**
```sql
CREATE TABLE phases (
  project_id TEXT, phase_id REAL, started_at INTEGER, completed_at INTEGER,
  retry_count INTEGER, lead_agent TEXT, blocking_pending TEXT
);

CREATE TABLE agent_invocations (
  project_id TEXT, agent TEXT, phase REAL,
  input_tokens INTEGER, output_tokens INTEGER, duration_ms INTEGER, status TEXT
);

CREATE TABLE hook_firings (
  hook_id TEXT, fired_at INTEGER, exit_code INTEGER,
  project_id TEXT, phase_id REAL, throttle_skipped BOOLEAN
);

CREATE TABLE self_healing (
  bug_id TEXT, iteration INTEGER, owning_agent TEXT,
  fix_attempted TEXT, handed_off_to_qa BOOLEAN
);

CREATE TABLE phase_5_findings (
  project_id TEXT, lane TEXT, -- reviewer|qa|auditor
  severity TEXT, finding_type TEXT, vetoed BOOLEAN
);

CREATE TABLE saas_intakes (
  project_id TEXT, block INTEGER, question_id TEXT,
  answer TEXT, unanswered BOOLEAN
);

CREATE TABLE adrs (
  project_id TEXT, adr_id TEXT, title TEXT,
  decided_at INTEGER, supersedes TEXT
);

CREATE TABLE instincts (
  instinct_id TEXT PRIMARY KEY, trigger_pattern TEXT, action TEXT,
  confidence REAL, evidence_count INTEGER, last_seen_at INTEGER
);
```

**Query CLI examples:**
```bash
/dev-squad query "projects where Phase 3.5 designer rejected ≥2 times"
/dev-squad query "avg self-healing iter-3 handoff rate per language"
/dev-squad query "correlation SaaS Block 3 Q2=SOC2 vs auditor severity"
/dev-squad query "designer Visual Gate failure modes top 10"
```

**Effort:** Medium. SQLite library + hook integration + query CLI.

**Why critical:** Prerequisite untuk #1. Plus debugging. Plus maintainer feedback loop. Plus product analytics.

---

#### #2 Phase-Scoped Context + Smart Model Routing

**Problem:** Coordinator + architect = opus. Mahal. Plus setiap agent baca all prior phases = token bloat.

**Model routing strategy:**

| Task | Model | Reason |
|---|---|---|
| ULTRAPLAN deep-think (Phase 0) | opus | scope/risk identification needs deep reasoning |
| Conflict resolution | opus | multi-perspective synthesis |
| Phase 7 retrospective synthesis | opus | extract structural learnings |
| Investigation Mode (iter-3) | opus | fresh-eyes debugging needs unique reasoning |
| Phase dispatch decisions | sonnet | structured routing |
| ADR/PRD generation | sonnet | structured output |
| Designer Phase 3.5 | sonnet think_harder | (sudah dipakai, keep) |
| Reviewer security analysis | sonnet think_harder | adversarial reasoning |
| Auditor metrics interpretation | sonnet think_harder | pattern recognition |
| Backend/Frontend implementation | sonnet | code generation |
| Hook scripts | n/a | shell/python |

**Context budget contract** (extension to workflow JSON):
```json
{
  "phase": 3.5,
  "lead": "designer",
  "context_budget": {
    "max_tokens": 8000,
    "required": ["brand_vibe", "entity_list", "page_inventory"],
    "on_demand": ["full_prd", "architecture_diagrams", "scaffold_structure"]
  }
}
```

Designer dapat slim context (brand vibe paragraph + entity list + page titles + tech stack one-liner). Tool call retrieval untuk detail kalo butuh.

**Effort:** Medium. Workflow JSON schema extension + agent prompt rewrites + retrieval tool.

**Why critical:** Cost reduction 30-50% estimated. Plus speed. Plus prevents context overflow di long runs.

---

### Tier 2: Growth Multipliers

#### #4 AgentShield-Style Adversarial Phase 5 Reviewer

**Problem:** Phase 5 reviewer = static OWASP + dependency audit. Pattern matching mostly.

**Pattern from ECC:** AgentShield pakai 3 Opus agents (attacker/defender/auditor).

**Implementation:**

Convert reviewer lane jadi mini-pipeline:
```
Phase 5 (parallel 3-way):
├── reviewer lane (NEW: 3-agent sub-pipeline):
│   ├── static-attacker (sonnet think_harder): find exploit chains in diff
│   ├── static-defender (sonnet): evaluate existing protections
│   └── static-synthesizer (sonnet): merged findings + severity ranking
├── qa-engineer lane: runtime + Visual Gate (unchanged)
└── auditor lane: stability + metrics (unchanged)
```

**Constraint:** Run only on diff (not whole codebase). Cost manageable.

**Effort:** Medium. New agent files + reviewer.md rewrite + workflow JSON update.

**Why important:** Static OWASP misses logic bugs, auth bypass chains, race conditions. Adversarial agent finds these.

---

#### #5 Cross-Harness Adapters

**Problem:** Claude Code only. Distribution capped.

**Priority order:**

1. **Codex (CLI + app)** — easiest. AGENTS.md convention. Agent files flatten ke rules + skills. Workflow JSON → Codex task primitives.
2. **OpenCode** — has plugin system mirip Claude Code. 20+ hook event types. dev-squad's `hooks.json` translates ~1:1.
3. **Cursor** — nested `.cursor/agents/` + `.cursor/rules/`. Designer Phase 3.5 artifacts jadi project context.

**Implementation:** `install.sh` + manifest-driven file copy + per-harness adapter layer.

**Effort:** 2-3 weeks per harness, independent.

**Why important:** Distribution multiplier 5-10x. Each harness adds new user pool.

---

#### #9 Skill Evolution Pipeline

**Problem:** Skills handwritten. Nggak ada feedback loop dari real runs.

**Pattern from ECC:** `/evolve` clusters instincts → graduates ke skills.

**Implementation:**

```
/dev-squad evolve

1. Query instincts WHERE confidence >= 0.8 AND evidence_count >= 3
2. Semantic clustering (embeddings) by trigger_pattern similarity
3. Cluster size >= 3 instincts AND distinct projects >= 3 → graduate
4. Auto-generate SKILL.md:
   - Frontmatter: name, description, learned: true, evidence_run_ids
   - Body: combined trigger conditions + action templates + examples from runs
5. Submit ke skills/dev-squad-learned/<slug>/SKILL.md
6. Mark contributing instincts as graduated (don't re-process)
```

**Effort:** Medium-High. Embeddings (local or API) + clustering + SKILL.md template generator.

**Why important:** After 6 bulan running, dev-squad punya **organic skill library yang evolved dari production**. Competitive moat.

---

### Tier 3: Quality of Life

#### #6 Hook Runtime Controls

**Problem:** Hooks fire every event. Heavy projects = spam.

**Implementation:**
- `DEV_SQUAD_HOOK_PROFILE=minimal|standard|strict`
  - **minimal:** dangerous-ops + workflow state only
  - **standard:** + lint, auto-update checks
  - **strict:** + PostToolUse lint, design compliance, OWASP pre-check
- `DEV_SQUAD_DISABLED_HOOKS="post:edit:typecheck,pre:bash:dangerous-ops"`
- Throttling untuk PostToolUse (max N firings per minute)
- Re-entrancy guards untuk SubagentStart/Stop
- Convert shell hooks → Node.js untuk Windows compat (ECC sudah migration ini)

**Effort:** Low-Medium.

---

#### #7 Profile-Driven Selective Install

**Problem:** Monolithic install. Nggak semua user butuh 11 agents.

**Profiles:**

| Profile | Agents | Use Case |
|---|---|---|
| `mvp` | 4 (coordinator, architect, backend, frontend) | Solo indie weekend builder |
| `standard` | 8 (mvp + designer, reviewer, qa-engineer, auditor) | Startup V1 |
| `saas` | 11 (standard + devops, git-ops, writer) | SaaS founder |
| `enterprise` | 11 + AgentShield + audit logs + multi-region | Enterprise |

```bash
claude plugins install dev-squad --profile mvp
```

Skips 7 agent files + 5 skills + 4 hook scripts kalo `mvp`. Faster install, smaller context.

**Effort:** Low. Manifest-driven file copy.

---

#### #8 Doctor + Repair

**Problem:** Plugin complex. Breakage detection manual.

**`/dev-squad doctor` checks:**
- All 11 agent files loadable
- `hooks/hooks.json` valid + scripts executable
- Workflow JSON passes `_schema.json` validation
- Required companions detected (superpowers minimum)
- MCP servers reachable
- `.dev-squad/` writable
- SQLite state store accessible

**`/dev-squad repair` auto-fix:**
- Reinstall missing agent files
- Re-permission hook scripts
- Regenerate workflow JSON dari template
- Suggest companion install commands

**Effort:** Low-Medium.

**Why important:** Claude Code v2.1+ breaking changes (duplicate hooks) already hit ECC. Will hit dev-squad eventually.

---

#### #11 Compaction Lifecycle: Restore Half

**Problem:** `pre-compact-save.sh` (PreCompact hook) saves state ke `.dev-squad/pre-compact-state.md`, tapi recovery-nya prose-only (komentar "agent can read after compaction"). Nggak ada hook yang inject state balik setelah compact — prose fires ~50-80%, critical path harus hook-enforced.

**Verified facts (2026-06-07, official hooks docs):**
- `SessionStart` support matcher `compact` — fires SETELAH auto/manual compact; `additionalContext` documented injects ke post-compact conversation.
- `PreCompact` input punya `trigger_source` (`manual`|`auto`); bisa block via exit 2. Nggak bisa modify compact instructions.
- `PostCompact` hook event ada (observe-only).
- **Programmatic compact trigger / threshold setting: TIDAK ADA.** Nggak ada API/setting/tool untuk memicu compaction lebih awal. "Auto compacting tool" literal nggak bisa dibangun — yang bisa dibangun cuma save→restore di sekitar lifecycle + prevention (#2).

**Implementation:**
1. New hook `post-compact-restore.sh`: `SessionStart` matcher `"compact"` → output isi `pre-compact-state.md` sebagai `additionalContext`. Keep slim — inject state besar habis compact = defeats the purpose.
2. Audit existing SessionStart hooks: sekarang **tanpa matcher**, jadi `auto-update.sh` + `session-gotchas.sh` + `validate-workflow-schema.sh` + `check-companions.sh` ikut fire setiap habis compact. `auto-update.sh` yang `git pull` plugin mid-run setelah compact = latent risk. Scope ke `startup|resume`.
3. (Optional) enrich `pre-compact-save.sh`: full workflow JSON + in-progress task + blocker list, bukan cuma head-50 master plan.

**Open question:** apakah PreCompact fire untuk subagent compaction? Tidak terdokumentasi. Thrashing yang observed (serp-scraper 2026-05-28, "context refilled to limit within 3 turns, 3x in a row") perlu dicek terjadi di main session atau subagent.

**Effort:** Low.

**Why:** Melengkapi save-half yang sudah ada jadi siklus deterministic. Bukan fix untuk thrashing — itu tetap #2 (context budgets). Ini recovery, bukan akar.

---

#### #10 i18n (Bahasa Indonesia)

**Problem:** English only. Indonesian market underserved.

**Scope:**
- README.md → README.id.md
- Command help strings
- Hook error messages
- ADR templates
- SaaS intake question text

**Effort:** Low. Sadewa native speaker.

**Why important:** Quick win, visible payoff, opens local market.

---

## Implementation Roadmap

### Phase 1 — Foundation (v5.0, ~6 weeks)
- [x] #3 SQLite state store (prerequisite for everything)
- [x] #1 Continuous learning extractor (Phase 7 hook)
- [x] #2 Model routing + context budgets (workflow JSON extension)

**Outcome:** dev-squad becomes self-improving + observable. Same UX, smarter internals.

### Phase 2 — Quality (v5.1, ~4 weeks)
- [x] #6 Hook runtime controls
- [x] #7 Profile-driven install
- [x] #8 Doctor + Repair
- [x] #10 i18n Bahasa Indonesia

**Outcome:** Production-grade reliability. Easier adoption. Local market entry.

### Phase 3 — Depth (v5.2, ~6 weeks)
- [x] #4 AgentShield adversarial reviewer
- [x] #9 Skill evolution pipeline (graduate instincts)

**Outcome:** Security depth. Organic skill library start growing.

### Phase 4 — Distribution (v5.3+, ongoing)
- [x] #5 Cross-harness adapters (Codex → OpenCode → Cursor)

**Outcome:** 5-10x user base.

---

## Risk + Tradeoff Analysis

### Risk: Scope Creep
dev-squad's current strength = opinionated workflow. ECC patterns introduce complexity. **Mitigation:** Profile system (#7) keeps `mvp` profile lean. Continuous learning (#1) disabled by default until v5.1.

### Risk: SQLite Adds Dependency
ECC ships SQLite as plugin dependency. **Mitigation:** Use Node.js `better-sqlite3` atau Python `sqlite3` (stdlib). Lightweight.

### Risk: Model Routing Backfire
Changing opus → sonnet untuk certain tasks might degrade quality. **Mitigation:** A/B testing pattern: track Phase 5 finding count + retry count before/after routing change. Rollback gate kalo metrics degrade.

### Risk: Skill Evolution Generates Bad Skills
Auto-generated skills could be wrong. **Mitigation:** Graduation gate (confidence + evidence threshold). Manual review queue before promote to `skills/dev-squad-learned/`. `learned: true` flag distinguishes from handwritten.

### Risk: Cross-Harness Maintenance Burden
Each harness = new adapter to maintain. **Mitigation:** Codex first (low effort, high signal). If adoption low, skip OpenCode/Cursor. Don't commit ke 6+ harnesses upfront kayak ECC.

---

## Success Metrics (Post v5.0)

| Metric | Baseline (v4.9) | Target (v5.0) | Target (v5.2) |
|---|---|---|---|
| Avg token cost per zero-to-ship run | ~unknown | -30% | -40% |
| Phase 5 finding precision | ~unknown | tracked | +20% |
| Self-healing iter-3 handoff rate | ~unknown | tracked | -25% (better instincts) |
| Cross-project pattern reuse | 0 | tracked | ≥5 graduated skills |
| Designer Visual Gate first-pass rate | ~unknown | tracked | +15% |
| Time from `build` → ship-ready PR | ~unknown | tracked | -20% |

**Implication:** v4.9 has nggak measure anything. v5.0 SQLite store = first observable version. Real improvements measurable mulai v5.1+.

---

## The Bigger Picture

dev-squad v4.9 wins **opinionatedness battle** against ECC. Tapi loses **learning battle**.

ECC v5+ direction: more skills, more harnesses, deeper memory management. But ECC still won't add opinionated workflow.

**dev-squad v5 unique position:**
- Opinionated (only one with strict Phase 3.5 Design Gate + SaaS intake)
- Self-improving (graduated skills from real runs)
- Observable (SQLite metrics)
- Adoptable (profile-driven install)

Itu combination yang **nggak ECC, nggak SuperClaude, nggak agent harness lain punya**.

---

## Next Steps

1. **Validate priorities dengan Sadewa** — confirm Tier 1 ordering matches roadmap
2. **Prototype #3 SQLite store first** — unblocks #1 dan jadi observable baseline
3. **Run baseline metrics on 3-5 current dev-squad projects** — establish v4.9 numbers before changes
4. **Spec doc per improvement** — convert each section dari summary jadi implementation spec
5. **Branch strategy:** `v5-foundation` branch for Tier 1, merge to main only after baseline metrics show no regression

---

*Doc generated by minah berdasarkan deep analysis dev-squad v4.9.0 README + ECC architecture patterns. Validate dengan Sadewa sebelum execute.*
