# Changelog

All notable changes to the dev-squad plugin are documented here. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this plugin adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [4.15.0] — Phase 0 Step 2.5b SaaS Intake (10-question kick-start gate) — SaaS scope marked BETA

**Why:** Empirical audit of `wacrm` (multi-tenant CRM SaaS built using v4.14 dev-squad) revealed the v4.14 Phase 0 SaaS detection was severely under-scoped. Phase 0 Step 2.5 asked only **"Enable SaaS yes/no"** — leaving 50+ implementation decisions made silently. The post-implement readiness audit then surfaced gaps that should have been planned at kick-start. Concrete retrofit cost on wacrm: 8 post-implement phases (`saas_readiness_audit`, `multi_tenant_gap_audit`, `phase_6a_billing_replatform` through `phase_6h_customer_success`) covering billing replatform (PayPal+Xendit+Manual after assuming Stripe), 3-tier admin hierarchy retrofit (`PlatformRole` enum + `/(platform-admin)` routes + impersonation + `PlatformAuditLog`), password reset + 2FA + account lockout + refresh token rotation + GDPR endpoints, Faktur Pajak + NPWP + invoice PDF, trial cron + annual + coupons + downgrade, customer API keys + webhooks + OpenAPI, cookie consent + sub-processor + DPA, backup + Sentry + Prometheus + status page + CI/CD + PII redaction, welcome email + onboarding drip + help center.

The user (operator of plugin + wacrm) explicitly identified the 3-tier identity hierarchy gap (Platform owner / Tenant admin / User-within-tenant + impersonation + audit log split) as the single most critical kick-start miss.

This release rewrites Phase 0 to capture 10 SaaS dimensions upfront via structured AskUserQuestion intake.

### Added — `commands/build.md` Phase 0 Step 2.5b SaaS Scope Intake

New step runs ONLY when Step 2.5 locked `SaaS Mode: enabled` (skipped entirely for standard apps — non-SaaS unchanged).

3 AskUserQuestion blocks in sequence (10 questions total):

**Block 1: Foundation (4 Q)** — Target Market (Indonesia/EU/US/Multi-region — drives currency, payment provider, tax regime, legal); 3-tier Admin Hierarchy (Platform+Tenant+User vs Tenant-only — drives PlatformRole enum + impersonation + audit log split); Per-Tenant Role Model (Owner-only / Owner+Member / Owner+Admin+Editor+Viewer / Custom RBAC); Trial + Plan Model (no trial / freemium / time-limited / freemium+trial-of-higher).

**Block 2: Customer-facing features (4 Q)** — Self-Service Auth Flows multiselect (password-reset, password-change, email-change, account-deletion, 2FA, lockout); Customer-Facing API Surface (None / API-keys / +webhooks / +OpenAPI); Email Lifecycle multiselect (verify, welcome, trial-warn, trial-expired, payment-failed-dunning, re-engagement, win-back); Invoice Surface (Stripe-portal / in-app+PDF / +resend-notes).

**Block 3: Operational + Compliance (2 Q)** — Operational Readiness Baseline multiselect (backup-cron, CI-CD-gate, Sentry, status-page, PII-redact, rate-limit); Compliance Jurisdiction multiselect (GDPR, PDP UU 27/2022, CCPA, LGPD, SOC2 Type 1, EU AI Act 2026, none).

**Cancellation handling**: any block cancelled mid-way locks answers obtained so far + marks remaining dimensions `UNANSWERED — REQUIRE Phase 1 clarification`. Architect's Phase 1 brainstorming must close them before PRD generation.

### Changed — `master-plan.md` template (in `commands/build.md` Step 3)

Extended template to include `## SaaS Mode` (enabled/disabled) + `## SaaS Intake` section (only when enabled) capturing all 10 dimension answers. Architect, backend, frontend, devops, writer READ this section at their respective phases. Master-plan locked once written — multi-tenancy/identity/payment retrofits require explicit ADR.

Entities/Tech Stack/Auth Model sections now reference SaaS Intake answers explicitly:
- Entities: if Q2 = 3-tier → must include `Platform.{Admin,Support}` + `Organization` + `User(with platformRole?, role)` + `PlatformAuditLog` + `TenantAuditLog`
- Tech Stack: payment provider derived from Q1 (Indonesia → Xendit+manual; EU/US → Stripe; Multi-region → abstraction)
- Auth Model: self-service flows derived from Q5

### Changed — ADR scope expansion (referenced from Step 2.5 → Phase 2)

Architect now produces **ADR-001..006** (was 001..005). ADR-006 NEW = identity hierarchy (3-tier Platform/Tenant/User-in-tenant model per Q2/Q3). Existing ADRs informed by Intake: ADR-002 billing (by Q1 + Q4), ADR-004 admin scope (by Q2), ADR-005 compliance (by Q10).

### Changed — `README.md`

"Safety: SaaS scope is opt-in only" → "SaaS scope (BETA — opt-in only)". Added **Beta notice** at top citing wacrm empirical baseline. New "What happens when you opt in" subsection documents the 3-block intake user-facing.

### Changed — `plugin.json`, `marketplace.json`

Descriptions updated to mention BETA SaaS scope + 10-question intake. Version 4.14.4 → 4.15.0 (minor: new feature, additive — non-SaaS workflow unchanged).

### Migration

None for non-SaaS projects (intake is skipped). Existing SaaS projects with `master-plan.md` already locked at v4.14 or earlier: intake does NOT re-run on session resume. To benefit from intake, run `/dev-squad build` on a fresh project OR manually add `## SaaS Intake` section to existing master-plan.md and re-dispatch architect with `--re-read-master-plan` instruction.

**Trade-off accepted**: SaaS-mode kick-start now requires up to 3 AskUserQuestion blocks (10 questions). This is intentional friction — the alternative is 50+ silent decisions surfacing as P0/P1 gaps weeks later (wacrm baseline). Users who want minimal-question kick-start can decline SaaS mode and use standard-app path.

## [4.14.4] — SaaS auto-trigger safety hardening (default-deny multi-tenancy / billing / RLS)

**Why:** Audit revealed dangerous documentation-reality drift. `skills/dev-squad/config.json` listed `dev-squad:saas-patterns` and `dev-squad:saas-readiness` in `auto_skills` arrays for 9 of 11 agents — implying auto-load — while agent YAML frontmatter (the actual loader) did NOT include them. Documentation lied. Risk: if any downstream tool parsed `auto_skills`, OR if an agent saw the config field and reached for SaaS patterns by judgment, a standard (non-SaaS) project could accidentally get multi-tenancy, RLS, `tenant_id` columns, billing modules, and audit logs injected — modifying user's data model and business logic against their intent. Phase 0 Step 2.5 SaaS detection had a 2-keyword threshold (false-positive risk) and ambiguous default behavior on user dismissal. `/dev-squad start` (feature-development workflow) relied on coordinator's heuristic with no explicit default-deny fallback.

This release enforces default-deny across all layers.

### Changed — `skills/dev-squad/config.json`

Removed `dev-squad:saas-patterns` and `dev-squad:saas-readiness` from `auto_skills` for all 9 agents (coordinator, architect, backend, frontend, designer, auditor, writer, reviewer, devops). Added new `conditional_skills` array per agent with explicit `load_when` conditions. Each condition cites the trigger sources (`.dev-squad/master-plan.md`, `.dev-squad/scope-tier.json`, `--saas` flag) and states "NEVER for standard apps" explicitly.

### Changed — agent prompts (7 files)

Added `### SaaS Scope Safety Default (BLOCKING)` section to: `coordinator.md`, `architect.md`, `backend.md`, `frontend.md`, `designer.md`, `devops.md`, `writer.md`. Each section enforces:

- **DEFAULT MODE: NON-SAAS.** Do NOT load saas-patterns or saas-readiness, do NOT apply multi-tenancy / RLS / billing / audit-log / plan-management / drill-down patterns, UNLESS one of 4 explicit triggers fires.
- **Four triggers** (any one suffices): master-plan.md has `SaaS Mode: enabled`, scope-tier.json has `saas_touch: true`, `--saas` flag passed, or existing project file structure shows SaaS subsystems already present.
- **When uncertain**: stop and ASK via coordinator. Default-deny is safer than default-allow.

Role-specific wording: architect's clause emphasizes "do NOT produce ADR-001..005"; backend's emphasizes "do NOT write `tenant_id` columns / RLS / billing module"; frontend's emphasizes "do NOT build admin dashboards / drill-down"; devops's emphasizes "do NOT scaffold 8 SaaS modules"; designer's emphasizes "do NOT produce `drill-down-spec.md`"; writer's email lifecycle section now blocks on same triggers.

### Changed — `commands/build.md` Phase 0 Step 2.5

- Threshold raised: **3+ keywords** (was 2+) before confirmation question is shown — reduces false-positives.
- If fewer than 3 keywords AND no `--saas` flag: skip confirmation entirely, lock SaaS Mode: disabled, proceed. No user friction for clearly non-SaaS scope.
- AskUserQuestion wording rewritten: **"No, build a standard app" is now the first/default/recommended option.** Body text explains the heavy patterns (multi-tenancy, billing, RLS, 8 modules) so user has informed choice.
- **Explicit default-deny on dismiss/cancel**: if user dismisses or cancels the question, plugin locks `SaaS Mode: disabled`. Never silently applies SaaS patterns.
- master-plan.md records explicit value (`enabled` or `disabled`) so downstream agents have unambiguous source-of-truth.

### Added — `README.md` "Safety: SaaS scope is opt-in only" section

New section between "When NOT to use" and "Team Composition" documents the safety guarantee user-facing:
- How `/dev-squad build` opts in (Phase 0 Step 2.5 default-no)
- How `/dev-squad start` detects (Diff-Scope Heuristic with explicit `saas_touch` flag)
- How existing-project detection works (file structure check, never retrofits)
- Once locked, decision persists for project lifetime
- Every SaaS-capable agent carries BLOCKING safety clause; default-deny, never default-allow

### Migration

None. Docs + config edits auto-pull on next session start. New behavior applies to all future Phase 0 Step 2.5 runs and all agent dispatches.

**Backwards compatibility note:** projects whose `master-plan.md` already has `SaaS Mode: enabled` continue to load saas-patterns/saas-readiness as before — the safety default only blocks NEW non-SaaS projects from accidentally entering SaaS mode.

## [4.14.3] — Developer-facing positioning (marketplace card + README intro)

**Why:** Plugin was capable but packaging for the evaluating developer was weak. Marketplace description was a 60-word kitchen-sink sentence with internal jargon ("6-A→6-H sprint decomposition", "provider abstraction"). README led with feature lists instead of "who is this for / what does this do for me". Required-vs-recommended companion list contradicted "graceful-degrade" language elsewhere. Risk: developer skims marketplace, bounces off, installs lighter alternatives despite dev-squad's deeper capabilities.

This release is docs-only — no agent or workflow behavior changes.

### Changed — `.claude-plugin/marketplace.json`

Description compressed from 60-word jargon block to outcome-focused single sentence (~35 words). Surfaces what the plugin DOES (ship full-stack projects), what's unique (anti-AI-slop gate, 3-way review, SaaS readiness, pre-seeded `.claude/` docs), without internal phase numbering or skill-name dumps.

### Changed — `.claude-plugin/plugin.json`

Description rewritten: lists agents by role, names the unique capabilities (Phase 3.5 design gate, 3-way review, Phase 5 iteration loop, security hook, SaaS readiness), drops version-history changelog text. Same length-class, much higher signal density.

### Changed — `README.md` intro

Replaced single intro paragraph with structured top:

1. **One-line hook** stating outcome + key differentiators
2. **"Who is this for?"** persona table (5 segments: solo indie, startup founder, SaaS founder, agency, engineer at existing project) — each row says what dev-squad gives them specifically
3. **Quickstart** — 3-step install + first build command, ~5 min to first dispatch
4. **"What makes dev-squad different"** — 5 specific differentiators (design gate, 3-way review, fresh-eyes debugger, SaaS scope, self-documenting output) — concrete, not generic
5. **"When NOT to use dev-squad"** — 4 honest cases (one-line fixes, research, no-git projects, you already have your own swarm) — honest framing builds trust

### Changed — README required vs recommended companions

Removed contradiction. Previously listed `superpowers` + `episodic-memory` + `context7` as "Required" while text elsewhere said companions "degrade gracefully". Now: only `superpowers` is Required (workflow skills are direct dependencies); `episodic-memory` + `context7` moved to a new "Strongly Recommended" tier; rest remain under "Recommended Plugins". Quickstart matches: "Install the one truly required companion".

### Migration

None. Docs-only changes auto-pull on next session start.

## [4.14.2] — 12-rule CLAUDE.md base template (pre-seed standard for generated apps + plugin self-application)

**Why:** Phase 6 SHIP pre-seeds `CLAUDE.md` in user's project but content was ad-hoc — overview + tech stack + how-to-run + where-things-live. Missing: universal engineering discipline rules that future Claude sessions on that project should follow. User shared a 12-rule template (think before coding / simplicity / surgical changes / goal-driven / model-for-judgment / token budgets / surface conflicts / read before write / tests verify intent / checkpoint / match conventions / fail loud) — 10 universal + 2 opinionated (Rule 5 model-only-for-judgment, Rule 6 token budget specifics).

This release codifies the template as the canonical base for every pre-seeded CLAUDE.md.

### Added — `docs/templates/claude-md-base.md`

Canonical 12-rule template + integration instructions for writer agent. Writer uses this as the FIRST section of every generated `CLAUDE.md` during Phase 6 SHIP pre-seed. Phase 7 LEARN preserves rules unchanged and appends project-specific sections BELOW.

Project-specific tuning allowed:
- Rule 5 (model for judgment) — if AI-native app legitimately uses model for routing, writer adds note BELOW Rule 5 (don't modify Rule 5 itself)
- Rule 6 (token budgets) — default 4k/task, 30k/session; architect can override in `.claude/conventions.md` per project scale

Validation rule: if generated `CLAUDE.md` doesn't contain "Rule 1 — Think Before Coding" verbatim, pre-seed step failed → re-dispatch writer.

### Changed — `agents/dev-squad/writer.md` `.claude/` Pre-Seed section

CLAUDE.md spec updated: START with 12-rule base template verbatim (from docs/templates/claude-md-base.md), THEN append project-specific. Total cap ~200 LOC project-specific (12 rules = ~70 LOC fixed). Explicit "do NOT modify the 12 rules — only append below".

### Changed — `commands/build.md`

- Phase 6 SHIP `.claude/` pre-seed step: `CLAUDE.md` description now references 12-rule base template
- Phase 7 LEARN CLAUDE.md update step: "preserve the 12 rules at top unchanged — append new conventions as 'Project Conventions Discovered During Build' section BELOW"

### Changed — `.claude-plugin/workflows/zero-to-ship.json` Phase 6

`CLAUDE.md` artifact description encodes 12-rule template requirement.

### Changed — `CLAUDE.md` (dev-squad-plugin self-application)

The plugin's own `CLAUDE.md` now starts with the 12-rule base template. Two plugin-specific notes added:
- Rule 5 note: "coordinator uses model for agent dispatch (routing via judgment) — agent SDK pattern; outside coordinator dispatch, rule applies normally"
- Rule 6 note: "SaaS-class build sessions may exceed default budget; coordinator may negotiate higher budget at workflow start"

Rest of CLAUDE.md (Repository Type, Architecture, Common Tasks, etc.) preserved unchanged BELOW the 12 rules.

### Changed — `docs/saas-build-checklist.md`

Phase 6 `.claude/` pre-seed section updated: CLAUDE.md checklist item now mentions the 12-rule base template requirement.

### Migration

None. Auto-update on next session start. New behavior applies to future Phase 6 SHIP runs. Existing projects' CLAUDE.md not retroactively modified — users can manually prepend the 12 rules if desired.

## [4.14.1] — Canonical SaaS build checklist doc + 2026 compliance updates

**Why:** SaaS-relevant content was scattered across saas-patterns + saas-readiness + workflow JSONs + agent prompts + commands/build.md. No single document gave "here's the canonical end-to-end SaaS build checklist + minimum requirements". Plus user's WebSearch suggestion surfaced 2026 EU regulations (AI Act, CRA, DORA) and 2026 industry baselines (OAuth 2.1 PKCE, AES-256/TLS 1.2+, SOC 2 Type 1 vs Type 2 distinction, JIT provisioning) not yet covered.

This release adds a consolidated reference doc and updates saas-readiness with verified 2026 items.

### Added — `docs/saas-build-checklist.md` (single canonical reference)

Single end-to-end SaaS build checklist mapping every SaaS-class requirement to:
- Which dev-squad phase covers it (0 ULTRAPLAN → 7 LEARN)
- Which agent owns it
- Which skill section has the pattern (saas-patterns or saas-readiness)

Sections:
- "What is SaaS-class?" — 4 properties test (multi-tenancy / subscription billing / plan-based access / self-service onboarding)
- Phase Map — table mapping checklist items to dev-squad phases
- Phase 0 SaaS mode detection
- Phase 1 PRD with SaaS specifics (target market, B2B/B2C, plan tiers, trial policy, usage metering, compliance scope, LTV/CAC + payback targets)
- Phase 2 ADRs 001-005 (+ 006 provider abstraction if multi-region)
- Phase 3 backend module scaffold (12 standard SaaS modules)
- Phase 3.5 design tokens + drill-down spec
- Phase 4 implementation per module (cross-references saas-patterns Sections)
- Phase 5 3-way review
- Phase 6 pre-launch readiness gate (P0/P1/P2 categorized)
- Product-surface 10 domains (A-J) — completeness audit
- 2026 compliance updates section (NEW): EU AI Act + CRA + DORA + SOC 2 Type 1/2 + OAuth 2.1 PKCE + encryption baseline
- Region-specific addendum (Indonesia / EU / US / LATAM / India / China / Africa)
- Phase 7 retrospective + playbook
- Sources & references — 11 cited 2026 industry sources (WorkOS, Storylane, Peiko, TechExactly, Voxturr, Scytale, Zylo, IOMETE, VinciWorks, European CRA guide, AI Act Tools)

### Changed — `skills/saas-readiness/SKILL.md` (2026 compliance items)

Section 1.1 P0 Security checklist:
- Added: OAuth 2.1 with PKCE (no static client secrets) — 2026 baseline if exposing API to customer apps
- Added: AES-256 encryption at rest + TLS 1.2+ in transit (TLS 1.3 preferred; older SSL disabled)

Section 1.2 P1 Business checklist:
- Added: LTV/CAC ratio > 3:1 + payback < 12 months target (sustainable growth metric)

Section 4 Compliance Lifecycle table extended:
- Added: EU AI Act (Aug 2026 enforceable, extraterritorial, 7% global turnover penalty)
- Added: EU CRA Cyber Resilience Act (Sep 11 2026 vuln reporting / Dec 11 2027 full; €15M or 2.5% turnover; pure SaaS exempt but installable components in scope)
- Added: DORA (Jan 2026, EU financial sector, severe ICT incident reporting + threat-led pen-test + third-party risk mgmt)

Section 11 (User Mgmt Part 3 product-surface):
- SSO row updated: SAML/OIDC + OAuth 2.1 PKCE baseline
- New row: JIT (Just-in-Time) provisioning — sign-in via IdP first time → provision account + role per IdP claim
- SCIM row clarified: centralized lifecycle (provision/update/deprovision via IdP)

Section 20 (Compliance/Legal Part 3 product-surface):
- SOC 2 split: Type 1 (snapshot, weeks) vs Type 2 (proof over 3-12 months, $10k+/mo enterprise blocker)
- Added rows: DORA incident reporting, EU AI Act conformity, CRA SBOM + vuln reporting

### Changed — `CLAUDE.md`

Skills section restructured to highlight:
- SaaS sibling-pair (saas-patterns vs saas-readiness with distinct load contexts)
- Pattern reference skills list
- Canonical SaaS reference: `docs/saas-build-checklist.md`

### Sources cited

WebSearch ground evidence (May 2026):
- WorkOS — 10 enterprise features every B2B SaaS needs (2026)
- Storylane — 2026 SaaS product launch checklist
- Peiko — SaaS Security Checklist Before Launch (2026)
- TechExactly — Designing Multi-Tenant SaaS Applications (2026)
- Voxturr — Go-to-Market Checklist B2B SaaS (2026)
- Scytale — Ultimate SOC 2 Checklist for SaaS Companies
- Zylo — Essential SaaS Compliance Checklist for 2026
- IOMETE — Data Sovereignty Compliance 2026 (DORA, AI Act)
- VinciWorks — 2026 Digital Compliance Playbook
- European Cyber Resilience Act guide
- AI Act Compliance for SaaS Companies (AI Act Tools)

### Migration

None. Auto-update on next session start. New doc is reference-only — agents continue to use saas-patterns + saas-readiness skills directly. Users can read `docs/saas-build-checklist.md` before invoking `/dev-squad build` to evaluate scope + minimum requirements.

## [4.14.0] — Split saas-patterns Part 3 → new sibling skill saas-readiness + new workflow saas-readiness-sprint

**Why:** Continued observation of wacrm SaaS project surfaced patterns beyond what saas-patterns Part 3 (added v4.13.0) captured. Wacrm extracted 27 readiness items across 10 product-surface domains and decomposed Phase 6 into 8 sub-phases (6-A through 6-H). User suggested splitting SaaS into separate skill or plugin. After deep-think (per `feedback_premise_challenge` memory): split into sibling skill is justified — Part 1+2 architectural patterns (load during Phase 4 IMPLEMENT, code-write context) and Part 3 readiness/execution discipline (load during Phase 5+ audit, Phase 6 SHIP gate, pre-existing project extension) have **distinct load contexts**. Plugin-level split rejected as premature (N=1 wacrm data).

This release splits saas-patterns Part 3 into a sibling skill, adds new content extracted from wacrm pivot, and introduces a new workflow JSON for the 6-A→6-H sprint pattern.

### Added — `skills/saas-readiness/SKILL.md` (new sibling skill, 1342 LOC)

4 parts:

- **Part 1 (sections 1–8):** Pre-launch readiness checklist + operational discipline. Migrated from saas-patterns Part 3 sections 27–34 (renumbered 1–8). Covers P0/P1/P2 categorized checklist, backup + DR, CI/CD requirements, GDPR/PDP/CCPA compliance lifecycle (data export + erasure + cookie + DPA), customer onboarding email lifecycle, status page + incident, payment compliance, pre-existing project audit pattern.
- **Part 2 (sections 9–10):** Sprint execution. NEW content. 6-A→6-H domain decomposition pattern (8 sub-phases parallelizable when independent, sequenced when dependent) + per-sub-phase execution templates with agents/artifacts/exit criteria for each (6-A billing replatform, 6-B user mgmt, 6-C invoicing+tax, 6-D plan mgmt, 6-E API+integrations, 6-F compliance, 6-G operational, 6-H customer success). Pattern extracted from wacrm Indonesia-first pivot.
- **Part 3 (sections 11–20):** Product-surface gap audit (10 domains A-J). NEW content. Completeness checklist beyond architectural readiness: A. User Mgmt, B. Plan Mgmt, C. Payment, D. Invoicing, E. API + Integrations, F. Customization + White-label, G. Notifications + Comms, H. Customer-facing Analytics, I. Workspace + Sub-tenancy, J. Compliance + Legal. Each domain enumerates Core/P0/P1/P2/Enterprise features with notes.
- **Part 4 (sections 21–24):** Real-world patterns. NEW content. Provider abstraction pattern (interface + registry + per-org selection + cross-provider conformance tests, derived from wacrm WaProvider + PaymentProvider applications), regional considerations (Indonesia + EU + US specifics: Faktur Pajak, NPWP, QRIS, manual bank transfer + admin verify pattern; GDPR + ePrivacy; state sales tax + CCPA), re-platform discipline (graceful provider deprecation, legacy directory pattern, schema migration), case study (wacrm Indonesia-first pivot with extracted lessons).

### Changed — `skills/saas-patterns/SKILL.md`

- Removed Part 3 (sections 27–34) — content moved to saas-readiness
- Removed Operational/Compliance/Lifecycle anti-patterns subsection (covered in saas-readiness anti-patterns)
- Frontmatter `description` updated: 3 parts → 2 parts; emphasizes "code-write patterns" + cross-references saas-readiness for ship/harden discipline
- Intro updated: distinct load contexts explained
- Companion skills + Bootstrap Context updated to reference saas-readiness as sibling
- Total size: 2402 → 1777 LOC

### Added — `.claude-plugin/workflows/saas-readiness-sprint.json` (new workflow, 10 phases)

Canonical contract for Phase 6-A→6-H sprint decomposition. Trigger: `/dev-squad readiness`. Phases:

- **0 audit** — coordinator dispatches reviewer + auditor + architect parallel for 3 readiness reports → architect synthesizes master report
- **6-A billing replatform** — backend + writer + frontend; provider abstraction
- **6-B user management hardening** — backend + frontend + writer + designer
- **6-C invoicing + tax** — backend + writer; depends on 6-A
- **6-D plan management** — backend + frontend; depends on 6-A
- **6-E API + integrations** — backend + writer; parallel-independent
- **6-F compliance lifecycle** — backend + frontend + writer
- **6-G operational hardening** — devops + auditor; depends on all 6-A..6-F
- **6-H customer success** — writer + backend + frontend; depends on 6-A + 6-B
- **7 ship** — devops + git-ops; PR + 180s auto-reviewer wait + final readiness verdict

JSON validates strict-mode against `_schema.json`.

### Changed — agent prompts + commands + workflow JSONs

- **`agents/dev-squad/coordinator.md`** — Skill Selection Matrix split: saas-patterns (architecture/code-write, Phase 4) + saas-readiness (audit/sprint, Phase 5+ + Phase 6 SHIP + pre-existing extension)
- **`agents/dev-squad/architect.md`** — saas-patterns row references ADR-001..005; new saas-readiness row covers Section 8 audit synthesis + Section 9 sprint decomposition decision + Section 21 provider abstraction + Section 22 regional context
- **`agents/dev-squad/backend.md`** — saas-readiness row added covering Sections 10.1–10.6 sub-phase execution templates + Section 21 provider abstraction + Section 22 regional patterns
- **`agents/dev-squad/devops.md`** — Part 3 ownership row updated: saas-readiness Sections 2 (backup), 3 (CI/CD), 6 (status page), 10.7 (6-G sub-phase) — DevOps blocks Phase 6 SHIP if any P0 ops item unresolved
- **`agents/dev-squad/writer.md`** — new section "Customer Onboarding Email Lifecycle (saas-readiness Section 5 / Phase 6-H)" with 7-stage lifecycle (verify → welcome → activation → trial-warn → trial-expired → re-engagement → win-back) + each-template rules
- **`commands/build.md`** Phase 6 SHIP — readiness gate references saas-readiness Sections 1 + 8; if 10+ items across 4+ domains, recommend `/dev-squad readiness` workflow (6-A→6-H decomposition); checklist references updated to saas-readiness Sections 2/3/6
- **`.claude-plugin/workflows/zero-to-ship.json`** — Phase 6 readiness master report description references saas-readiness Section 1 + 8 + 9 + recommends saas-readiness-sprint workflow for large scope
- **`skills/dev-squad/SKILL.md`** — skills table extended with saas-readiness row alongside saas-patterns (distinct load contexts explained)
- **`skills/dev-squad/config.json`** — saas-readiness added to auto_skills for 9 of 11 agents (coordinator/architect/backend/frontend/designer/devops/auditor/writer/reviewer); new `workflows.saas_readiness_sprint` entry; existing `workflows.saas_readiness_audit` updated to reference saas-readiness Section 8

### Reference architecture credit

Section 9 sprint decomposition + Sections 21–24 patterns extracted from wacrm Indonesia-first pivot (multi-tenant SaaS CRM with PayPal + Xendit + Manual triple-provider billing per ADR-006 + ADR-006a). Provider abstraction pattern proven across two domains (WhatsApp dual-provider per ADR-004; payment triple-provider per ADR-006). Regional Indonesia patterns (Faktur Pajak, NPWP, manual bank transfer + admin verify) are wacrm-specific but represent broader Asian B2B SaaS reality.

### Migration

None. Auto-update on next session start. saas-patterns existing references (Sections 27–34) automatically migrate to saas-readiness Sections 1–8 — content preserved, just relocated. Agents that referenced saas-patterns will continue to load it for Part 1+2 (architecture); agents that need Part 3 content load saas-readiness instead.

For users with existing dev-squad-built SaaS projects: invoke `/dev-squad readiness` to run Section 8 audit + Section 9 sprint decomposition recommendation.

## [4.13.1] — Drift consistency audit round 2 (config.json + 3 workflow JSONs)

**Why:** v4.12.1 audit only synced `zero-to-ship.json` and `skills/dev-squad/SKILL.md`. The other 3 workflow JSONs (`feature-development`, `bug-fix`, `refactoring`) and `skills/dev-squad/config.json` (agent declarative manifest) were still vintage v4.9.0. Worse: `config.json` was missing 4 of 11 agents entirely (designer, qa-engineer, auditor, writer) — they exist as agent prompt files but had no declarative entry.

This release closes those gaps. **No new features. No new files. Pure consistency.**

### Changed — `skills/dev-squad/config.json` (agent manifest, major sync)

- **Added 4 missing members:**
  - `designer` (Phase 3.5 anti-AI-slop gate, sonnet think_harder, priority 3) with frontend-design + ui-ux-pro-max + brainstorming + saas-patterns auto-skills
  - `qa-engineer` (Phase 5.5 functional verification + Investigation Mode, sonnet) with playwright + chrome + tdd-workflow auto-skills
  - `auditor` (Phase 5.6 stability + Phase 5.7 quality metrics, sonnet) with postgres-patterns + golang-patterns + golang-testing + backend-patterns + security-review + saas-patterns auto-skills
  - `writer` (page copy + microcopy + legal + .claude/ pre-seed, sonnet) with claude-md-management + verification auto-skills
- **`reviewer` role updated:** "Code Reviewer/QA" → "Security Lead + Code Reviewer + Phase 5 Synthesizer"; capabilities expanded with threat_modeling + owasp_top_10_enforcement + phase5_metrics_synthesis + saas_readiness_security_audit; auto_skills extended with brainstorming + security-review + postgres-patterns + saas-patterns
- **`saas-patterns` added to auto_skills** for: coordinator, architect, backend, frontend, designer, devops (Part 3 ownership). Loaded conditionally when SaaS mode active.
- **`requesting-code-review` added to git-ops auto_skills** (was added to git-ops.md frontmatter in v4.10.0 but not config.json)
- **`mermaid-mcp` + `ide diagnostics` added to relevant auto_mcp lists** matching v4.10.0 MCP utilization expansion (writer, frontend, designer, reviewer, devops)
- **`workflows.zero_to_ship` updated 6 → 9 phases** describing Phase 0 ULTRAPLAN + Step 2.5 SaaS detection + Phase 3.5 designer + Phase 7 LEARN; mentions iteration loop + readiness gate + .claude/ pre-seed + 180s auto-reviewer wait
- **`workflows.feature_development` updated** to mention designer Phase 3.5 + Section 34 readiness audit for existing SaaS + iteration loop + security hook + 180s auto-reviewer wait
- **`workflows.bug_fix` updated** to mention qa-engineer Investigation Mode + iteration loop with rollback + security hook awareness
- **`workflows.refactoring` updated** to mention auditor before/after metrics + qa-engineer per-batch smoke + atomic rollback + security hook
- **New workflow added: `workflows.saas_readiness_audit`** (parallel reviewer/auditor/architect → architect synthesis → BLOCK if P0 > 0)

### Changed — `.claude-plugin/workflows/feature-development.json`

- Bumped `version` 4.9.0 → 4.13.0
- `description` updated to mention security hook (auto-blocks 9 dangerous patterns) + Phase 4 iteration loop + Section 34 readiness audit trigger for SaaS-touch features
- Phase 1 scope_assessment output extended with `SaaS-touch flag` (true if scope touches multi-tenancy/billing/webhooks/audit/api-keys/admin)
- Phase 3 implement: `dev-squad:saas-patterns` added to external_skills (load when scope touches SaaS); description mentions PreToolUse hook
- Phase 4 review: new `iteration-log.md` artifact + iteration loop semantics in description
- Phase 5 deploy: 180s auto-reviewer wait encoded in artifact description

### Changed — `.claude-plugin/workflows/bug-fix.json`

- Bumped `version` 4.9.0 → 4.13.0
- `description` updated to mention security hook + Phase 4 iteration loop with rollback
- Phase 3 fix: `saas-patterns` added (load for SaaS-subsystem bugs: cross-tenant leak, billing webhook idempotency, API key revocation race) + security hook awareness in artifact description
- Phase 4 verify: iteration loop semantics encoded in artifact description

### Changed — `.claude-plugin/workflows/refactoring.json`

- Bumped `version` 4.9.0 → 4.13.0
- `description` updated to mention security hook + per-batch atomic rollback discipline
- Phase 3 incremental_refactor: `saas-patterns` added (preserve cross-tenant isolation/idempotency/audit integrity if refactoring SaaS code) + security hook awareness
- Phase 4 smoke_verify: atomic rollback per batch encoded in artifact description

### Changed — `.claude-plugin/workflows/zero-to-ship.json`

- Bumped `version` 4.12.0 → 4.13.0 (was already updated in v4.13.0 with Phase 6 readiness gate; version field now matches)

All 4 workflow JSONs validate strict-mode (additionalProperties: false) against `_schema.json`.

### Migration

None. Auto-update via `auto-update.sh` on next session start. The drift fix is internal — no new behavior to opt in/out of, just makes existing v4.10-13 features reach coordinator's dispatch reliably for ALL workflows (not just zero-to-ship).

## [4.13.0] — saas-patterns Part 3: Operational & Compliance Discipline (close ship-readiness blind spot)

**Why:** Audit of an existing dev-squad-built SaaS (wacrm) revealed 9 P0 ship-blockers + 18 P1 launch-risks. Despite solid architecture (multi-tenancy verified, Stripe sig + bcrypt + CSP hardened), the project couldn't ship because of operational and compliance gaps: no backup automation, no CI/CD pipeline, `LOG_LEVEL=debug` PII leak, Stripe Tax not enabled, welcome email never sent, no GDPR data export/erasure, no status page, no trial expiry cron, etc.

These weren't wacrm-specific bugs — they were patterns dev-squad's `saas-patterns` skill didn't cover. Part 1 (15 sections) and Part 2 (11 sections) gave a working architecture. **Neither stopped you from shipping it broken.**

This release adds Part 3: 8 sections covering operational + compliance + lifecycle discipline. Patterns derived from real-world readiness audits.

### Added — `skills/saas-patterns/SKILL.md` Part 3 (sections 27–34, ~630 LOC)

- **Section 27. Pre-Launch Readiness Checklist** — P0 (ship-blocker) / P1 (launch-risk) / P2 (post-launch backlog) categorized matrix covering Security, Operational, Business. Phase 6 SHIP gate: BLOCK if P0 count > 0.
- **Section 28. Backup & Disaster Recovery** — Postgres pg-backup service + S3 lifecycle, Redis AOF, ClickHouse coverage, mandatory quarterly restore drill (backups you've never restored ARE NOT BACKUPS).
- **Section 29. CI/CD Pipeline Requirements for SaaS** — Min: tsc/test/lint/build/security-scan blocking PRs. Migration safety gate (NOT NULL + DROP COLUMN + non-CONCURRENTLY index detection). Deploy gates (green CI + tagged + staging-verified + manual approval on breaking changes).
- **Section 30. Compliance Lifecycle (Data Subject Rights)** — GDPR / PDP / CCPA / LGPD obligations matrix. Data export endpoint (async via queue, JSON/NDJSON, 30-day SLA). Data erasure endpoint (anonymize PII, retain financial 7y). Cookie consent banner (don't load analytics until consent="all"). DPA template guidance.
- **Section 31. Customer Onboarding Email Lifecycle** — Day 0 verify → welcome → activation milestone (only when first key action) → trial-warning -3d → trial-expired → re-engagement drip 30/60/90d. Implementation pattern with BullMQ queue + daily cron. Anti-pattern list (silence after verify, generic re-engagement, mixing transactional+marketing on same domain).
- **Section 32. Status Page & Incident Communication** — Tooling matrix (BetterStack / Atlassian / Cachet / static). Sev 0-3 classification with response SLA. Postmortem template (timeline, root cause, what went well/poorly, action items).
- **Section 33. Payment Compliance & Pricing Tiers** — Stripe Tax mandatory (`automatic_tax: true` + dashboard config). Tax invoice / kwitansi generation (Indonesia e-Faktur PPN, EU VAT, US sales tax). Annual + monthly pricing (15-20% discount = 30-50% ARR uplift). Failed payment dunning (Stripe smart retries + tenant status updates). Refund policy.
- **Section 34. Pre-Existing Project Audit Pattern** — When extending existing SaaS: dispatch reviewer + auditor + architect in parallel for 3 readiness reports → architect synthesizes master report → BLOCK feature work until P0 cleared. Audit categories per agent. Synthesize report template.

Plus updates:
- **Anti-patterns table** extended with 15 new ops/compliance/lifecycle anti-patterns (backup never restored, LOG_LEVEL=debug PII leak, Stripe Tax false, missing welcome email, silent trial expiry, hot-deploy without CI, hardcoded plan IDs, manual GDPR export, cookie banner that loads analytics on dismiss, drip without unsubscribe, mixing transactional+marketing on same domain, no status page, adding features over unresolved P0, refund without revoking entitlements, erasure that deletes financial records).
- **Bootstrap Context** extended: ADR-005 compliance scope mandate; readiness checklist mandate before Phase 6; Section 34 mandate for pre-existing project work; section ownership matrix (devops/architect/backend/writer).
- **Frontmatter description** rewritten to reflect 3 parts.

Total saas-patterns size: 1771 → 2402 LOC.

### Changed — agent prompts + commands

- **`agents/dev-squad/devops.md`** — saas-patterns row updated to call out Part 3 ownership (Sections 28 backup, 29 CI/CD, 32 status page). DevOps blocks Phase 6 SHIP if any P0 ops item unresolved.
- **`agents/dev-squad/architect.md`** — saas-patterns row updated: ADR-001..**005** (added compliance scope) + Section 34 audit synthesis ownership.
- **`commands/build.md`** — Phase 6 SHIP now has explicit BLOCKING readiness gate when SaaS mode active. Coordinator dispatches reviewer + auditor + architect in parallel for 3 readiness reports, architect synthesizes master report, BLOCK ship if P0 > 0 (override via `.dev-squad/ship-exceptions.md`). DevOps checklist extended with backup automation + CI/CD + status page verification when SaaS. Phase 0 Step 2.5 mention extended to ADR-005.
- **`.claude-plugin/workflows/zero-to-ship.json`** — Phase 6 outputs adds `docs/saas-readiness-master-report.md` blocking artifact (SaaS only). blocking_gate.check encodes P0 = 0 OR documented exception. Phase 0 + Phase 2 mentions updated to ADR-001..005.

### Reference architecture credit

Section 27, 30, 31, 32, 33 patterns derived from real audit findings of dev-squad-built SaaS (wacrm — multi-tenant CRM with Stripe + dual-provider WhatsApp). Patterns are general SaaS, not wacrm-specific. See `docs/saas-readiness-master-report.md` template (Section 34.3) for synthesis format.

### Migration

None. Auto-update on next session start. Existing SaaS projects benefit retroactively — coordinator can dispatch readiness audit (Section 34 pattern) on existing project before Phase 6 SHIP.

To opt out of readiness gate (not recommended): explicit user override per ship attempt via `.dev-squad/ship-exceptions.md`.

## [4.12.1] — Drift consistency audit (workflow JSON sync + agent prompt sync)

**Why:** v4.10.0 → v4.12.0 added many features (MCP utilization, SaaS scope, security hook, .claude/ pre-seed, Phase 5 iteration, auto-reviewer wait) but the canonical contract (`.claude-plugin/workflows/zero-to-ship.json`) and the skill description (`skills/dev-squad/SKILL.md`) drifted from the implementation. Coordinator reads the JSON at workflow start as dispatch source-of-truth — if JSON was stale, dispatch would not reflect new behavior. Agent prompts (devops, writer) didn't know about their new responsibilities (SaaS scaffold, `.claude/` pre-seed) — they only had implicit references via Skill Selection Matrix.

This release closes those gaps. **No new features. No new files. Pure consistency.**

### Changed — `.claude-plugin/workflows/zero-to-ship.json` (canonical contract)

Bumped workflow `version` 4.9.0 → 4.12.0 (matches plugin version that introduced the changes). Updates per phase:

- **Phase 0 (ULTRAPLAN)** — output description now mentions Step 2.5 SaaS Mode auto-detect + AskUserQuestion confirmation. blocking_gate.check requires SaaS Mode section locked. external_skills adds `dev-squad:saas-patterns` (graceful_degrade: false) when SaaS detected.
- **Phase 2 (DESIGN Architecture)** — external_skills adds `dev-squad:saas-patterns` for ADR-001..004 mandate when SaaS active.
- **Phase 3 (SCAFFOLD)** — outputs adds `apps/backend/src/{tenants,plans,billing,webhooks,api-keys,audit-log,notifications,admin}/` (conditional on SaaS mode). external_skills adds `dev-squad:saas-patterns` (devops invokes for module contracts).
- **Phase 3.5 (UI/UX DESIGN)** — outputs adds `.dev-squad/design/drill-down-spec.md` (conditional on SaaS+dashboard). skip_conditions adds rule for non-SaaS-non-dashboard projects. external_skills adds `dev-squad:saas-patterns` (Part 2 §26 = drill-down-spec template).
- **Phase 4 (IMPLEMENT)** — external_skills adds `dev-squad:saas-patterns` (backend Part 1 + frontend Part 2 when SaaS active).
- **Phase 5 (REVIEW)** — outputs adds `.dev-squad/iteration-log.md` describing formal iteration loop semantics (max 5 iter, anti-thrashing, rollback on regression, escalate on exhaustion). blocking_gate.check encodes iteration loop discipline.
- **Phase 6 (SHIP)** — outputs adds 4 `.claude/` pre-seed artifacts (CLAUDE.md, .claude/architecture.md, .claude/conventions.md, .claude/gotchas.md) all blocking. PR description encodes 180s auto-reviewer wait. blocking_gate.check verifies pre-seed + auto-reviewer wait completion.

JSON validates against `_schema.json` (additionalProperties: false strict mode).

### Changed — `skills/dev-squad/SKILL.md` (skill discovery / routing)

- Frontmatter `description` rewritten to mention SaaS-mode detection, saas-patterns Part 1+2, Phase 5 iteration loop, Phase 6 .claude/ pre-seed, security hook.
- Workflow diagram updated end-to-end:
  - Phase 0 now shows Step 2.5 SaaS detection + locked decision in master-plan.md
  - Phase 2 shows ADR-001..004 mandate when SaaS
  - Phase 3 shows SaaS module scaffold conditional
  - Phase 3.5 shows drill-down-spec.md conditional
  - Phase 4 shows Backend Part 1 + Frontend Part 2 when SaaS + PreToolUse security hook coverage
  - Phase 5 shows formal iteration loop with rollback + anti-thrashing + escalation
  - Phase 6 shows .claude/ pre-seed (Writer + Architect collaboration) + 180s auto-reviewer wait
  - **Phase 7 LEARN added** (was missing entirely from SKILL.md though present in JSON + build.md)
- "Only one user checkpoint" → "up to 2 — Phase 0 Step 2.5 SaaS confirmation (if triggered) + Phase 1 PRD approval"
- Skills table extended: `dev-squad:saas-patterns` row + 5 other dev-squad pattern skills (backend-patterns / frontend-patterns / postgres-patterns / golang-patterns / golang-testing / tdd-workflow / security-review) explicitly cataloged

### Changed — `agents/dev-squad/devops.md` + `agents/dev-squad/writer.md`

- **devops.md** — added `dev-squad:saas-patterns` row to Skill Selection Matrix (was missing — only 5 of 11 agents had it; devops scaffolds the SaaS modules, must reference Part 1 contracts)
- **writer.md** — added new section "**`.claude/` Pre-Seed (Phase 6 SHIP — Mandatory for Generated Apps)**" with 4 artifact specs + rules (cap ~200 LOC each, link to source for details, mermaid for flows, terse tone for Claude-as-future-reader)

### Migration

None. Auto-update via `auto-update.sh` on next session start. The drift fix is internal — no new behavior to opt in/out of, just makes existing v4.12.0 features reach coordinator's dispatch reliably.

## [4.12.0] — Production discipline hardening (security hook + .claude/ pre-seed + Phase 5 iteration + auto-reviewer wait)

**Why:** Analysis of `security-guidance`, `audit-project`, `ship`, and `memberstack` plugins identified 4 production-shipping disciplines dev-squad lacked. Each addresses a real friction or risk in shipping production code from generated builds. Zero new MCP/plugin installs.

### Added — Security pattern PreToolUse hook (`hooks/guard-unsafe-code.py`)

Ports + adapts pattern detection from Composio's `security-guidance` plugin. Blocks/warns 9 dangerous code patterns being written to user files via Edit/Write/MultiEdit:

- `eval(` / `new Function(` — JS code injection
- `child_process.exec(` / `execSync(` — Node shell injection
- `dangerouslySetInnerHTML` / `.innerHTML=` / `document.write(` — React/DOM XSS
- `pickle.load` / `pickle.loads` — Python deserialization RCE
- `os.system(` — Python shell injection
- GitHub Actions YAML `${{ github.event.* }}` in `run:` blocks — CI injection

**Modes:**
- Default: advisory — warn once per session per (file × pattern), log to `.dev-squad/security-warnings.log` in user's project, allow tool to proceed
- Strict: set `DEV_SQUAD_STRICT_SECURITY=1` → exit 2 (block edit)
- Disable: set `DEV_SQUAD_DISABLE_UNSAFE_CODE_GUARD=1`

**Allow-list:** test files (`.test.`, `.spec.`, `__tests__/`, `tests/fixtures/`) and dev-squad-plugin's own files are exempt (test code legit uses `eval()` for assertion harnesses; plugin docs reference dangerous patterns to teach about them).

Registered in `hooks/hooks.json` as new `PreToolUse` matcher for `Write|Edit|MultiEdit` (separate from existing Bash matcher for `guard-dangerous-ops.sh`).

### Added — `.claude/` pre-seed in generated apps (Phase 6 SHIP step)

Pattern adopted from memberstack-claude-boilerplate: every dev-squad-built project now ships with self-documenting context for future Claude sessions:

- `CLAUDE.md` (project root, auto-loaded) — project overview, tech stack, how-to-run, where things live, references to detail docs
- `.claude/architecture.md` — entities + relationships, modules, data flow, auth flow (with mermaid)
- `.claude/conventions.md` — naming, file org, error handling, validation, testing, commits
- `.claude/gotchas.md` — known issues, footguns (filtered from `.dev-squad/gotchas.md` to project-relevant only)

**Compound benefit:** every future Claude session on the project loads CLAUDE.md automatically and discovers detail docs in `.claude/`. No re-discovery on each session. Each doc kept under 200 LOC — context, not exhaustive reference.

Writer + architect collaborate during Phase 6 SHIP to produce these. Tightly integrated with existing Phase 7 LEARN's CLAUDE.md update step.

### Changed — `agents/dev-squad/coordinator.md` Phase 5 formal iteration loop

Phase 5 review previously had implicit "ALL P0-P1 must be fixed; re-review after fixes". Now formalized with explicit loop logic:

```
iter = 1
while findings_p0_or_p1 exists AND iter <= 5:
  - Group findings by responsible agent (backend/frontend/devops/writer)
  - Dispatch agent with file:line + severity + fix instructions
  - After agent reports done, run verification (reviewer/qa/auditor re-checks the lane that flagged)
  - If verification PASSES → mark resolved
    If verification FAILS or test/build breaks → git restore + log iteration + retry
  - iter++
If iter > 5 unresolved → escalate to user with: findings, attempts, blast radius, recommendation
```

**Rollback rule:** if a fix attempt breaks an existing passing test, treat as regression — `git restore` immediately. Don't accumulate broken fixes.

**Anti-thrashing:** if iter N produces verbatim same failure as iter N-1, skip to next escalation tier.

Pattern adopted from Composio's `audit-project` plugin Phase 4-6 iteration loop.

### Changed — `agents/dev-squad/git-ops.md` Auto-Reviewer Wait

Adopted from `ship` plugin Phase 4 mandatory wait. After PR creation, git-ops MUST wait 180s before checking comment threads — auto-reviewers (Gemini, Copilot, CodeRabbit, dependabot) need time to analyze and post.

**Mandatory pattern in git-ops body:**
- 180s sleep after `gh pr create`
- Then check `comments` count + unresolved review threads via GraphQL
- If unresolved threads exist → address before merge
- Override allowed only on explicit user "skip auto-review wait, this is hotfix P0"

Forbidden: `sleep 0`, removing wait, treating "no comments yet" at t+10s as "ready to merge".

### Reference architecture credit

- Composio `security-guidance` — pattern detection logic + warning state per session
- Composio `audit-project` — iteration loop with verification rollback
- Composio `ship` — auto-reviewer wait pattern (3 minutes is empirical, not arbitrary)
- memberstack-claude-boilerplate — `.claude/` directory convention as compound productivity gain

### Migration

None required. Auto-update on next session start. New hook is advisory by default — no existing flow blocked. Existing projects without `.claude/` directory simply don't get pre-seed (only newly-built projects via `/dev-squad build` get it).

To opt out of security hook entirely: `export DEV_SQUAD_DISABLE_UNSAFE_CODE_GUARD=1` in shell. To enable strict (block) mode: `export DEV_SQUAD_STRICT_SECURITY=1`.

## [4.11.1] — Consolidate drill-down-patterns into saas-patterns (structural fix)

**Why:** v4.11.0 split SaaS coverage into two skills (`saas-patterns` for backend + `drill-down-patterns` for frontend admin dashboard). User correctly flagged this as poor structure: drill-down only triggers in SaaS mode + dashboard scope — there's no other invocation path in dev-squad's flow. Two skills that always co-load are one skill with internal structure. The split added maintenance cost (2 files to keep in sync, 5 agent files to reference both, 2 changelog entries) without giving users a meaningful choice — you can't load drill-down without saas-patterns making sense.

This release consolidates them. The drill-down content becomes Part 2 of saas-patterns. No content lost.

### Changed

- **`skills/saas-patterns/SKILL.md`** — restructured as two parts. Part 1 (sections 1–15, unchanged): backend patterns. Part 2 (sections 16–26, merged from drill-down-patterns): frontend admin dashboard. Total: 1771 LOC. Anti-patterns table now has backend + frontend subsections. Frontmatter description updated to reflect full-stack coverage.
- **`agents/dev-squad/coordinator.md`** — collapsed two skill rows into one (`saas-patterns` referenced once, mentions Part 1 + Part 2)
- **`agents/dev-squad/frontend.md`** — drill-down row points to `saas-patterns (Part 2)` instead of separate skill
- **`agents/dev-squad/designer.md`** — drill-down spec row points to `saas-patterns (Part 2 §26)` for the spec template
- **`commands/build.md`** Phase 3.5 — references Part 2 Section 26 for drill-down-spec.md template

### Removed

- **`skills/drill-down-patterns/SKILL.md`** — content moved to saas-patterns Part 2
- `skills/drill-down-patterns/` directory

### Lesson saved to memory

Saved feedback `Challenge user's premise before executing literally` — when user picks an option from AskUserQuestion, do one more deep-thinking pass before executing. If the option has structural problems (coupling, redundancy), push back with rationale instead of literal compliance. This release was a corrective application of that lesson.

### Migration

None. Auto-update via `auto-update.sh` on next session start. Anyone who already loaded the old `drill-down-patterns` skill will see "skill not found" — coordinator falls back to `saas-patterns` (Part 2 has the same content).

## [4.11.0] — SaaS-class scope: multi-tenancy, billing, drill-down dashboards

**Why:** dev-squad's zero-to-ship workflow produced solid MVP web apps but lacked the patterns needed for SaaS-class applications: multi-tenancy, subscription billing, plan-based access control, API key management, outbound webhooks, audit logs, admin dashboards with drill-down. The user's target shifted to "selain zero-to-ship juga bisa membuat SaaS yang lengkap termasuk drill down" — and analysis of a production SaaS reference (lastsaas — 22 API handlers, 15 validated collections covering tenants/users/plans/billing/webhooks/audit) confirmed 18 SaaS subsystems were not covered by existing skills.

This release fills that gap with 2 substantial new skills + Phase 0 SaaS mode detection. Multi-tenancy is an architectural decision that must be locked early — retrofit later = cross-tenant data leak (P0 security incident). The mode is auto-detected from PRD keywords with explicit user confirmation.

### Added — `skills/saas-patterns/SKILL.md`

15 sections covering production-class SaaS backend:

1. **Multi-tenancy** — 4 tenancy strategies (shared DB / schema-per-tenant / DB-per-tenant / hybrid), tenant model, RLS policies, tenant context middleware, mandatory cross-tenant isolation test suite
2. **Subscription billing (Stripe)** — full lifecycle, webhook handler with idempotency, plan change with proration, promo codes
3. **Plan-based access / entitlements** — entitlement check pattern, middleware-based gating, seat counting
4. **API key management** — secure creation (full key shown once), SHA-256 hashing, scope-based authorization, revocation
5. **Outbound webhooks** — signed delivery (HMAC-SHA256 + timestamp), retry with exponential backoff (8 attempts over 7 days), DLQ + auto-disable, customer verification snippet
6. **Audit logs** — separate from system log, immutable, hot/cold tier strategy, PII redaction
7. **In-app notifications & messages** — multi-channel delivery (realtime + email + push), per-user preferences
8. **Transactional email** — template registry, provider abstraction (Resend/SendGrid/SES swappable)
9. **Hybrid validation** — two-layer defense (app-level Zod/struct tags + DB-level CHECK constraints / JSON Schema). Sync test pattern from lastsaas
10. **Admin scope** — root-tenant API key OR dedicated admin_users; separate `/admin/api/v1/*` namespace
11. **Usage events / metering** — for usage-based billing or quota enforcement; aggregation strategy
12. **Runtime config / feature flags** — per-user > per-tenant > global resolution, cache invalidation via pub/sub
13. **SSO / multi-IdP** — ssoConnections model, domain-routed login, enforcement flag
14. **White-label / tenant branding** — custom CSS sandboxing, custom domain support
15. **Admin drill-down endpoints** — REST hierarchy pattern, time-series response shape, cursor pagination

Plus comprehensive anti-pattern table (10 SaaS anti-patterns + correct alternatives).

### Added — `skills/drill-down-patterns/SKILL.md`

11 sections covering drill-down dashboard frontend:

1. **Five drill levels** — KPI cards → time-series → segment table → entity detail → event detail. Concrete example with deep-linkable URLs at each level
2. **URL state architecture** — Zod-typed search params hook (`useDashboardSearch`), shareability rules
3. **Breadcrumb with state preservation** — every step carries relevant filters
4. **Time-series with brush + zoom** — recharts/visx pattern with debounced URL update, granularity auto-selection table
5. **Virtualized tables** — TanStack Virtual + TanStack Table pattern, cursor-based infinite scroll for 10k+ rows
6. **Cross-filter coordination** — Zustand store + URL bridge (subscribeWithSelector), composable filter composition
7. **Empty/loading/error states per drill level** — skeleton matching layout, error class-specific recovery, empty with action
8. **Permission-aware drill items** — PermissionGate component, locked-state visibility for discoverability
9. **Real-time updates** — polling vs SSE vs WebSocket decision matrix, "last updated" indicator pattern
10. **Performance considerations** — bundle splitting per level, memoization rules, React Query stale time per level type, Suspense boundary strategy, optimistic UI for mutations
11. **Designer's drill-down spec** — Phase 3.5 artifact template (mermaid hierarchy + per-level spec + filter model + anti-patterns)

### Added — Phase 0 Step 2.5: SaaS Mode Detection (`commands/build.md`)

Auto-detect SaaS scope from PRD/description keywords (subscription/tenant/billing/plans/multi-tenant/team workspace/admin panel/drill down/analytics dashboard/white-label) — if 2+ match OR `--saas` flag → coordinator runs explicit confirmation via AskUserQuestion (full SaaS / SaaS-without-drill-down / standard app). Decision recorded in `.dev-squad/master-plan.md` and locked. If active, architect MUST produce ADR-001 to ADR-004 (tenancy, billing, plan structure, admin scope) before backend codes.

### Changed — Phase 3 SCAFFOLD + Phase 3.5 DESIGN extensions (`commands/build.md`)

- Phase 3 SCAFFOLD: when SaaS mode active, devops scaffolds additional backend modules (`tenants/plans/billing/webhooks/api-keys/audit-log/notifications/admin`) referencing saas-patterns
- Phase 3.5 DESIGN: when SaaS + dashboard/analytics scope, designer ALSO produces `drill-down-spec.md` artifact (5th artifact alongside the existing 4)

### Changed — agent prompts (5 files, conditional skill loading)

- **coordinator.md** — added `dev-squad:saas-patterns` and `dev-squad:drill-down-patterns` to Skills Selection Matrix (conditional load on SaaS mode)
- **architect.md** — added `dev-squad:saas-patterns` (load when producing ADR-001 to ADR-004)
- **backend.md** — added `dev-squad:saas-patterns` (load for SaaS-class backend implementation)
- **frontend.md** — added `dev-squad:drill-down-patterns` (load for drill-down dashboards)
- **designer.md** — added `dev-squad:drill-down-patterns` (load to produce drill-down-spec.md artifact)

Skills are NOT in frontmatter `skills:` (would auto-load every dispatch and bloat context). They're in body Skill Selection Matrix — invoked on demand when SaaS mode is active.

### Reference architecture credit

Patterns inspired by analysis of:
- **lastsaas** (Jon Radoff) — production SaaS Go reference: 22 API handlers, 15 validated collections, hybrid validation pattern (Go struct tags + MongoDB JSON Schema sync)
- **memberstack-claude-boilerplate** — Next.js auth middleware + plan-based access pattern
- **Composio audit-project** — multi-agent review iteration loop pattern
- **Anthropic frontend-design plugin** — visual design quality discipline

Zero new MCP/plugin installs required.

### Migration

None. Auto-update via `auto-update.sh` on next session start. Existing zero-to-ship workflow unchanged for non-SaaS projects (Phase 0 Step 2.5 simply doesn't trigger if no SaaS keywords detected).

## [4.10.0] — Expanded MCP utilization across all 11 agents (zero new installs)

**Why:** A baseline audit of all 11 agent prompts revealed under-utilization of MCPs that were already recommended in CLAUDE.md but not actually triggered by agent prompts. `mermaid-mcp` was only invoked by 3 agents (architect, coordinator, designer-via-body). `episodic-memory` was missing from auditor and qa-engineer where past findings are gold. `ide diagnostics` was scattered. The writer agent was the thinnest of all — only `context7` and `sequential-thinking` mentioned. The `WebSearch` fallback pattern (when `context7` returns no entry) was explicit only in architect.

This release fixes that — pure prompt-level boost, **zero new MCP/plugin installs required**.

### Changed — agent prompts (9 files)

- **`agents/dev-squad/writer.md`** — Major rewrite of MCP ENFORCEMENT. Added: `grep-github` (find production README/microcopy patterns), `mermaid-mcp` (system overview, user journey, auth flow diagrams in docs), `episodic-memory` (brand voice consistency across sessions), `WebSearch` (legal/compliance verification, citation/fact-checking, fallback for stale context7), `claude-md-management` (persist project conventions). Was thinnest agent in MCP utilization — now matches peers.
- **`agents/dev-squad/auditor.md`** — Added `episodic-memory` (recurring stability patterns, false-positive history, quality metric trends) and `ide diagnostics` (compile-time issues that correlate with runtime instability). Added WebSearch fallback rule.
- **`agents/dev-squad/qa-engineer.md`** — Added `episodic-memory` (regression patterns, prior Investigation Mode root causes, project-specific quirks) and `ide diagnostics` (pre-runtime sanity check). Added WebSearch fallback rule.
- **`agents/dev-squad/devops.md`** — Added `mermaid-mcp` (infra topology, CI/CD pipeline, multi-env promotion, failover diagrams) and `ide diagnostics` (YAML/Dockerfile/Terraform/K8s manifest lint). Added WebSearch fallback rule. Updated MCP table.
- **`agents/dev-squad/reviewer.md`** — Added `superpowers:brainstorming` to skills frontmatter (threat modeling needed exploratory thinking, was referenced in body but not loaded). Added `mermaid-mcp` (threat-surface diagrams, auth flow, privilege graphs). Added WebSearch fallback rule + CVE corroboration via web. Updated MCP table.
- **`agents/dev-squad/backend.md`** — Added `mermaid-mcp` (API request lifecycle, auth sequence, transaction saga, job pipelines). Added WebSearch fallback rule. Updated MCP table.
- **`agents/dev-squad/frontend.md`** — Added `mermaid-mcp` (component hierarchy, state flow, data-fetching sequence, interaction state machines) and `ide diagnostics` (TypeScript drift, lint warnings before commit). Added WebSearch fallback rule. Updated MCP table.
- **`agents/dev-squad/designer.md`** — Promoted `mermaid-mcp` to MCP ENFORCEMENT (was only used in body for wireframes; now explicit for component state diagrams, user flow, IA map). Added `episodic-memory` (token consistency across sessions, anti-pattern recall, prior brand-vibe approvals).
- **`agents/dev-squad/git-ops.md`** — Added `superpowers:requesting-code-review` to skills frontmatter (git-ops orchestrates PR review handoff but didn't auto-load the skill).

### Why this matters

- **No install bloat.** All MCPs referenced were already recommended in CLAUDE.md — graceful-degrade rule still applies (agents no-op if MCP not installed).
- **Better diagram production.** mermaid-mcp now wired into 6 more agents — backend produces sequence diagrams, devops produces topology, reviewer visualizes attack surface, etc. Each agent owns a distinct diagram class to avoid overlap.
- **Better cross-session consistency.** episodic-memory in writer (tone), designer (tokens), auditor (recurring findings), qa-engineer (regression patterns) means the swarm builds project-specific knowledge that survives across runs.
- **Anti-stale-knowledge discipline.** Explicit WebSearch fallback in 7 agents prevents agents from silently relying on training-data when context7 has no entry.

### Migration

None. Auto-update via `auto-update.sh` on next session start.

## [4.9.0] — Workflow mapping schema + companion plugin auto-install

**Why:** Knowledge of "which agent runs in which phase, which artifacts gate next phase, which companion skill should be invoked when" was scattered across 5+ files (coordinator.md, build.md, SKILL.md, individual agents). This caused drift and made it hard for users to install the right companion ecosystem. v4.9.0 introduces a **machine-readable runtime contract** + **declarative companion manifest** + **auto-install bootstrap**.

### Added — Workflow JSON schema (runtime contract)

`.claude-plugin/workflows/` now contains canonical workflow definitions:
- `_schema.json` — JSON Schema Draft 7 validator
- `zero-to-ship.json` — full 9-phase build workflow
- `feature-development.json` — daily feature workflow with diff-scope tier dispatch
- `bug-fix.json` — reproduce → fix → verify
- `refactoring.json` — with before/after metrics proof

Each phase declares: lead agent, parallel agents, inputs/outputs (with blocking flag), skip conditions (`--mvp-mode`, no-UI, etc.), verification command, rate-limit tier, and `external_skills.preferred[]` (companion skills to invoke when available).

**Coordinator now reads workflow JSON at workflow start** as dispatch source-of-truth (with fallback to implicit prompt knowledge if JSON missing).

`hooks/validate-workflow-schema.sh` (SessionStart, dev-only) detects drift between JSON and agent prompt files.

### Added — Companion plugin manifest + auto-install

`.claude-plugin/companions.json` declares all recommended companion plugins + MCP servers with install commands, tier (required/recommended), purpose, and which dev-squad agents use each.

**Companions wired:**
- **ui-ux-pro-max** (recommended) — invoked by designer in Phase 3.5. Translates ui-ux-pro-max design system output into 4 dev-squad artifacts. Without it, designer falls back to manual flow.
- **gsd** (get-shit-done, recommended) — 10 skills wired across 5 agents:
  - `gsd-new-project`, `gsd-execute-phase` → coordinator
  - `gsd-plan-phase`, `gsd-plan-checker` → architect
  - `gsd-verify-work`, `gsd-audit-milestone` → auditor
  - `gsd-secure-phase` → reviewer
  - `gsd-pr-branch`, `gsd-ship` → git-ops
- **superpowers** (required) — already wired

**Auto-install via `/dev-squad bootstrap`:**
- Reads manifest, detects missing
- MCPs auto-installed via `claude mcp add` (per-item user confirm)
- Plugins: outputs batch `/plugin marketplace add` + `/plugin install` commands for user copy-paste (Claude Code design: plugin install is slash-only)
- Plugins MCPs covered: context7, sequential-thinking, mermaid-mcp, grep-github

`hooks/check-companions.sh` (SessionStart) detects missing companions and emits non-blocking warning every session.

### Added — Documentation

- `docs/workflow-mapping.md` — human-readable mapping (master tables + mermaid diagrams + skip-condition decision tree)
- `docs/companion-plugins.md` — full companion plugin guide
- `.claude-plugin/workflows/README.md` — schema docs + drift policy

### Modified

- All 6 agents (coordinator, architect, designer, auditor, reviewer, git-ops): added companion skills to `skills:` frontmatter
- coordinator.md: new "Companion Skills (Optional, On-Demand)" section + workflow JSON bootstrap
- designer.md: Phase 3.5 step 0 (ui-ux-pro-max companion check + invocation + output translation table)
- skills/dev-squad/SKILL.md: added `/dev-squad bootstrap` command with full logic
- commands/build.md: header note pointing to canonical workflow JSON
- README.md: new "Workflow Mapping" + "Companion Plugins" sections
- hooks/hooks.json: registered validate-workflow-schema + check-companions

### Behavior expectations

- **Backward compatible**: v4.8.0 workflows continue to work without companions; agents fall back to native methodology
- **No required new installs**: superpowers was already required in v4.8.0; companion plugins are all recommended
- **Coordinator dispatches more accurately**: workflow JSON eliminates "did coordinator forget to dispatch designer?" failure mode
- **User trust**: missing companions surfaced at session start (not silently degraded)

### Migration notes

- Existing dev-squad users: no action required. Existing workflows will keep running.
- For maximum capability: run `/dev-squad bootstrap` once after upgrade.
- Plugin install commands for missing companions are surfaced; users decide what to install.

## [4.8.0] — Designer agent + Phase 3.5 anti-AI-slop gate

User reported persistent failure mode: zero-to-ship UI output looks generic — default shadcn slate palette, AI-cliché purple-to-blue gradients, emoji used as icons, responsive skipped, no motion, "modern minimal" boilerplate. Diagnosis: no agent exists to **reject** AI-slop; frontend agent is an implementer, not a designer. v4.8.0 adds the missing role.

### Added — `agents/dev-squad/designer.md` (11th agent — sonnet, `think_harder`)
Owns Phase 3.5 DESIGN. Anti-AI-slop authority. Produces 4 BLOCKING artifacts in `.dev-squad/design/` before frontend can write any UI code:

1. **`design-tokens.md`** — concrete color palette, typography ladder, spacing scale, radius, motion timings + easings, shadow tokens. No TBD placeholders allowed.
2. **`visual-spec.md`** — ≥3 reference URLs with playwright-captured screenshots in `.dev-squad/design/refs/`, brand vibe (concrete adjectives, not "modern minimal"), project-specific anti-pattern list (emoji-as-icon, default shadcn slate, AI-cliché gradients, missing responsive, missing motion).
3. **`component-inventory.md`** — every component × variants × states (loading / error / empty / focus / hover / active / disabled).
4. **`responsive-spec.md`** — mermaid wireframes per page × mobile / tablet / desktop breakpoints.

Designer uses WebSearch + grep-github + playwright (screenshots references) + chrome-devtools (study computed styles of refs) — designing from imagination = AI slop, blocked.

### Added — Phase 3.5 DESIGN in zero-to-ship workflow (`commands/build.md`, `coordinator.md`)
Sits between Phase 3 SCAFFOLD and Phase 4 IMPLEMENT. BLOCKING gate — frontend cannot start UI work until all 4 designer artifacts exist. `--mvp-mode` flag exists for rapid prototyping (slim deliverable: tokens + slim visual-spec only). Workflow tracking JSON now includes `ui_design` phase.

### Added — Visual Gate in `qa-engineer.md` Phase 5.5
qa-engineer's Phase 5.5 functional verification now runs designer's anti-pattern list against shipped UI:
- **Emoji-as-icon detection** (P0): regex `[\u{1F300}-\u{1F9FF}]` in `.tsx`/`.jsx`
- **Inline arbitrary value detection** (P1): grep for Tailwind `[#hex]`, `[Npx]` patterns
- **Responsive presence check** (P0): playwright at 375 / 768 / 1280 viewports + screenshot per page; identical layout at all = P0
- **Motion presence check** (P1): observe DOM transitions on speced-animated states
- **Default shadcn palette check** (P1): computed `backgroundColor` of primary button vs design-tokens.md
- **Anti-pattern list scan** (P1-P2): targeted detection per row in `visual-spec.md`

Visual Gate findings auto-CC'd to designer via direct message.

### Added — Pass 5: DESIGN COMPLIANCE in `reviewer.md` static lane
reviewer's multi-angle review now has a fifth pass: design token discipline lint. Greps for inline arbitrary values, emoji codepoints in JSX, missing responsive classes on layout components, missing motion classes on speced-animated components. Cross-checks component usage against `component-inventory.md`. Hands runtime visual concerns to qa-engineer Visual Gate; reviewer's lane is static lint only.

### Added — Designer in 5 daily-routine workflows (`coordinator.md`)
- **Feature Development** — designer dispatched if feature has UI (skipped if backend-only or `--mvp-mode`)
- **Refactoring** — designer dispatched if visual change in scope (updated tokens / inventory / responsive for affected components only)
- **New Project Setup** — designer mandatory after architect (skipped only if `--mvp-mode`)
- Per-task review (Diff-Scope Heuristic) — added "New UI surface from scratch" row → reviewer + qa-engineer + designer (light pass: tokens used, anti-pattern compliance)

### Added — Dispatch Decision Log includes designer
`.dev-squad/dispatch-log.md` entries now include `designer: {yes|no}` row + designer findings count per dispatch.

### Changed — `frontend.md` reads designer artifacts (no more ad-hoc design)
Replaced "DESIGN REFERENCE WORKFLOW" (frontend improvising design) with **DESIGN ARTIFACTS WORKFLOW**:
1. Read all 4 designer artifacts (BLOCKING — STOP if missing)
2. Translate `design-tokens.md` to code (no inline arbitrary values allowed)
3. Implement components per `component-inventory.md` — every variant + state
4. Wire motion per token system + reduced-motion fallback
5. Implement responsive per `responsive-spec.md` mermaid wireframes
6. SVG icons only — emoji-as-icon is P0 violation
Frontend Bootstrap Context now includes mandatory step: read all 4 design artifacts before any UI code.

### Changed — Cross-agent communication tables (5 agents)
- `architect.md` — added Designer row (handoff page list + component boundaries to Phase 3.5)
- `frontend.md` — added Designer row (escalate spec ambiguity, request new variant)
- `qa-engineer.md` — added Designer row (Visual Gate findings CC)
- `reviewer.md` — added Designer row (token violation found in static lane)
- `architect.md` "To Designer" handoff section added between architect-to-frontend handoff

### Changed — `skills/dev-squad/SKILL.md`
- Description: 10 → 11 agents
- Team Members table updated
- Designer Extended Responsibilities section added
- Agent Communication Matrix expanded 10×10 → 11×11 (designer row + column)
- Common Cross-Agent Scenarios table — 17 new designer-related rows (Phase 3.5 dispatch, artifact handoff, visual gate findings, anti-pattern detection, MVP-mode escape)
- v3.0 Orchestration Patterns — added "Phase 3.5 DESIGN gate" row
- Agent-Specific Tool Matrix — Designer section added (frontend-design, brainstorming, WebSearch, grep-github, playwright, chrome-devtools, context7, mermaid-mcp, episodic-memory)

### Changed — `commands/build.md`
- Workflow renamed: 8 phases → 9 phases (added Phase 3.5)
- Team table 10 → 11 agents
- Phase 4 IMPLEMENT updated: frontend MUST read all 4 design artifacts before UI work; design tokens enforced; SVG icons only; responsive per spec; motion wired
- Phase 5 Lane 2 (qa-engineer) updated to include Visual Gate execution

### Changed — `README.md`
- Agent count 10 → 11
- Designer row in team composition table
- Frontend description updated (implements designer's spec)
- New "Phase 3.5 DESIGN Gate (Anti-AI-Slop)" feature section
- Zero-to-ship phase listing updated to 9 phases including Phase 3.5
- Directory tree updated with `designer.md`

### Behavior expectations
- **Backward compatible**: existing v4.7.1 zero-to-ship runs continue to work; if user explicitly sets `--mvp-mode`, behavior matches old flow (frontend designs ad-hoc).
- **No opus quota impact**: designer is sonnet (with `think_harder` for design judgment). No new opus-tier dispatches added.
- **Rate limit impact**: +1 dispatch per zero-to-ship build. Mitigated by designer being skip-able in workflows where it doesn't apply (backend-only feature, pure code refactor, hotfix, bug fix).

### Migration notes for existing projects
- Existing projects continue without change. Designer artifacts in `.dev-squad/design/` are produced on first re-build or when running `/dev-squad start` on a feature with UI.
- Frontend agent will fail-soft if designer artifacts are missing in a non-zero-to-ship context (escalates to coordinator instead of improvising).

## [4.7.1] — Wire qa-engineer + auditor into all daily-routine workflows

Patch release. v4.7.0 introduced qa-engineer + auditor agents and 3-way Phase 5 review for zero-to-ship, but only Bug Fix and Performance Optimization daily workflows actually dispatched the new agents. Other daily workflows (Feature Development, Refactoring, Security Audit, Data Migration, New Project Setup) and per-task two-stage review still routed exclusively to reviewer — meaning the new agents only fired during the heaviest workflow (zero-to-ship). User reported this gap; v4.7.1 closes it.

This release also wires cross-agent communication so other agents know **when** to escalate to qa-engineer or auditor (previously they could only contact reviewer for QA/perf concerns). And adds a **Diff-Scope Dispatch Heuristic** so coordinator picks the right combo of agents per task — not always 3-way (waste) and not always reviewer-only (gap).

### Added — Diff-Scope Dispatch Heuristic (`coordinator.md`)
Decision table coordinator applies BEFORE every review dispatch. Picks reviewer / qa-engineer / auditor combo based on diff scope:
- Trivial / tiny → reviewer only (or skip)
- New endpoint → reviewer + auditor (Bucket C hammer)
- New interactive UI → reviewer + qa-engineer (verify wired)
- DB schema/queries/migrations → reviewer + auditor (Bucket B safety + perf)
- Auth/payment/data flow → full 3-way
- Refactor ≥200 LOC → reviewer + auditor (before/after metrics) + qa-engineer (no behavior drift)
- Bug fix <50 LOC → reviewer + qa-engineer (verify bug gone in runtime)
- Performance fix → auditor (prove improvement) + reviewer (no security regression)
- Pre-merge final gate → full 3-way
- Hotfix to production → reviewer + qa-engineer (skip auditor for speed)

Default for ambiguous: lean MORE coverage, not less. Cost of missed bug > cost of extra dispatch.

### Added — Dispatch Decision Log (`coordinator.md`)
Coordinator writes append-only entries to `.dev-squad/dispatch-log.md` per dispatch decision: diff stats, areas touched, heuristic row matched, agents dispatched + why, outcome (P0/P1/P2 counts per agent), time to complete. Phase 7 LEARN reads the log + assesses heuristic accuracy ("was the dispatch right?"). Updates heuristic table based on miss patterns. Rolls over per build; weekly archive for long-running projects.

### Changed — 5 daily workflows updated (`coordinator.md`)
- **Feature Development** — pre-merge review now applies Diff-Scope Heuristic; reviewer always + qa-engineer for new endpoints/UI + auditor for DB/large diff
- **Refactoring** — auditor BEFORE baseline metrics + AFTER metrics (prove improvement) + qa-engineer (no behavior drift) + reviewer (intent preserved)
- **Security Audit** — reviewer (static OWASP) + auditor (Bucket C endpoint hammer + Bucket D failure injection + Bucket A config drift) + qa-engineer (auth flow live test)
- **Data Migration** — auditor migration safety scan (Bucket B): NOT NULL on big tables, missing CONCURRENTLY, ACCESS EXCLUSIVE locks; qa-engineer runs migration on staging + hits endpoints during; auditor post-migration regression check
- **New Project Setup** — auditor post-scaffold audit (Bucket A: config drift, env validator, docker compose parse, /health, CORS, TLS) + qa-engineer smoke test scaffold

### Changed — Two-Stage Review Protocol (`coordinator.md`, `commands/build.md`)
- Spec compliance pass: qa-engineer for new endpoint/UI (functional verification = ground truth); reviewer for static spec match
- Code quality pass: auditor for DB/perf/large diff (real metrics); reviewer for security/patterns
- Per-task review uses heuristic; not always reviewer-only

### Added — cross-agent communication tables now know about qa-engineer + auditor
- `architect.md` "Who You Talk To" — added qa-engineer (vague acceptance criteria) + auditor (architecture-level perf concern from audit)
- `backend.md` "Who You Talk To" — added qa-engineer (functional verification request, runtime trace) + auditor (DB perf, migration safety)
- `frontend.md` "Who You Talk To" — added qa-engineer (browser-state bug) + auditor (bundle size, dead exports, type-escape)
- `devops.md` "Who You Talk To" — added qa-engineer (staging ready) + auditor (config drift, pool/max_connections mismatch)
- `git-ops.md` "Who You Talk To" — added qa-engineer (PR touches new endpoint/UI per heuristic) + auditor (PR touches DB/migration per heuristic)

### Changed — `skills/dev-squad/SKILL.md` cross-references
- **Agent Communication Matrix** updated 7×7 → 10×10 (added qa-engineer, auditor, writer rows/columns)
- **Common Cross-Agent Scenarios** table — added 17 new scenarios involving qa-engineer/auditor (500 leak detection, hydration mismatch, button without onClick, slow query, missing index, pool sanity, config drift, complexity threshold, Investigation Mode handoff, PR-ready dispatches per heuristic)
- **v3.0 Orchestration Patterns** table — added "3-Way Phase 5 Review" and "Diff-Scope Dispatch Heuristic" rows; clarified Multi-Angle Review is reviewer's static lane within Phase 5
- **Schema Design workflow diagram** — auditor migration safety scan + reviewer security check (was reviewer doing both)
- **Migration workflow diagram** — auditor migration safety pre-deploy + qa-engineer staging runtime verification + auditor post-migration regression check

### Why this patch
v4.7.0 audit (commissioned by user before release) revealed 18 findings across 5 P0 (workflow gaps), 9 P1 (cross-agent communication gaps), 3 P2 (SKILL.md diagram drift), 1 P3 (pattern table). Without this patch, daily routine usage of dev-squad effectively bypassed the new agents — they only ran during full zero-to-ship builds, which is the rarest workflow. v4.7.1 closes all 18 findings.

### Backward compatibility
No breaking changes. Existing zero-to-ship Phase 5 dispatch unchanged. Bug Fix and Performance Optimization workflows unchanged (already wired in v4.7.0). Other workflows now dispatch additional agents per heuristic — slight runtime increase per workflow (+sonnet calls), but each lane is bounded and parallelizable. No opus impact.

## [4.7.0] — Agent split: qa-engineer + auditor; multi-language metrics; DB perf execution

This release splits execution responsibilities out of `reviewer` into two new agents and extends Phase 5 to a 3-way parallel review (static + runtime + automated). Closes the v4.6 reviewer overload (~770 lines, 9 distinct roles) and adds polyglot support (Go + Python in addition to JS/TS), database performance execution (slow query log + connection leak + migration safety + pool sanity), and API pattern compliance enforcement (REST/GraphQL/gRPC anti-patterns).

### Added — two new agents

- **`qa-engineer`** (sonnet, maxTurns 35) — runtime QA. Owns Phase 5.5 FUNCTIONAL VERIFICATION (boot app, drive golden path via playwright, audit interactive elements, smoke-test API endpoints, browser console gate) and Investigation Mode (fresh-eyes debugger when self-healing iter 3 triggers). Skills: `playwright-skill`, `superpowers-chrome:browsing`, `superpowers:systematic-debugging`, `superpowers:verification-before-completion`, `dev-squad:tdd-workflow`. Veto on P0 functional findings + P1 in golden path.
- **`auditor`** (sonnet, maxTurns 30) — automated stability + quality metrics. Owns Phase 5.6 STABILITY EXECUTION (5 buckets: config drift, DB perf, endpoint hammer, failure injection, API pattern compliance) and Phase 5.7 CODE QUALITY METRICS (multi-language tool runner). Skills: `superpowers:verification-before-completion`, `superpowers:systematic-debugging`, `dev-squad:postgres-patterns`, `dev-squad:golang-patterns`, `dev-squad:golang-testing`, `dev-squad:backend-patterns`, `dev-squad:security-review`. Installs missing analyzer tools on demand.

### Changed — reviewer slimmed to original mandate

- `reviewer.md` removed Phase 5.5 FUNCTIONAL VERIFICATION (moved to qa-engineer) and Investigation Mode (moved to qa-engineer). Reviewer is now **static analysis only** — security review, code review on diff, multi-angle review (security/perf/spec/architecture passes), and **Phase 5 Metrics Report synthesis** (combines its own findings + qa-engineer's functional report + auditor's stability and quality reports into single PDCA Check artifact).
- `reviewer.md` `maxTurns` 35 → 25 (back closer to original 21, reflects narrower scope).
- `reviewer.md` skills removed: `playwright-skill`, `superpowers-chrome:browsing` (those moved to qa-engineer).
- File size impact: reviewer was ~770 lines after v4.6; back to ~580 lines.

### Changed — Phase 5 is now 3-way parallel

- Coordinator dispatches **reviewer + qa-engineer + auditor** in parallel during Phase 5. Each owns a distinct lane and is not interchangeable. After all three return, reviewer synthesizes the single Phase 5 Metrics Report.
- All three have veto in their domain: reviewer (security), qa-engineer (functional), auditor (stability/quality).
- Self-healing loop iteration 3 (fresh-eyes investigation) now hands off to **qa-engineer**, not reviewer — qa-engineer has playwright + chrome-devtools for browser-state inspection that reviewer lacks.
- Self-healing iteration log's `Tier:` field now uses `qa-engineer-investigation` (was `reviewer-investigation`).
- Bug Fix workflow updated: dispatch qa-engineer first for reproduce + root cause; reviewer for static regression check.
- Performance Optimization workflow updated: dispatch auditor for profiling + DB perf bucket + benchmark validation (was reviewer).

### Added — multi-language code quality metrics (Phase 5.7)

`auditor` detects project language(s) at audit start by scanning for `package.json`, `tsconfig.json`, `go.mod`, `pyproject.toml`, `requirements.txt`, `Cargo.toml`. Tool set per language:

| Concern | JS/TS | Go | Python |
|---|---|---|---|
| Cyclomatic complexity | `eslint --max-complexity=10` | `gocyclo -over 10` | `radon cc -n B` |
| Duplication | `jscpd --threshold 5` | `dupl -t 50` | `jscpd` |
| Dead code | `ts-prune`, `unimported` | `staticcheck U1000`, `deadcode` | `vulture` |
| Circular deps | `madge --circular` | n/a (compile-time) | `pylint cyclic-import` |
| Type escape | grep `\bany\b`, `@ts-ignore` | grep `interface{}`, `\bany\b` | grep `: Any\b`, `# type: ignore` |
| Outdated deps | `npm-check-updates` | `go list -u -m all` | `pip list --outdated` |
| Linter aggregator | `eslint --max-warnings 0` | `golangci-lint run` | `ruff check` |

Go-specific gates: `go vet`, `staticcheck`, `errcheck`, `go mod tidy -diff`, `go test -race`. JS/TS-specific gates: `tsc --noEmit`, unjustified `@ts-ignore` detection.

For polyglot projects (e.g., Go backend + TS frontend), auditor runs the appropriate tool set per language directory and merges findings.

### Added — Phase 5.6 STABILITY EXECUTION (focuses on 500-class + DB perf)

Five buckets in `auditor`:

- **Bucket A: Config Drift** — diff `.env.example` vs env vars actually consumed in code; validator coverage; `docker compose config` parse; boot health; CORS/TLS/port sanity.
- **Bucket B: Database Stability** — pool size vs `max_connections`; slow query capture via `pg_stat_statements`; index coverage cross-reference; idle-in-transaction connection leak detection; migration safety scan (NOT NULL on large tables, missing CONCURRENTLY, ACCESS EXCLUSIVE locks); N+1 detection from query log.
- **Bucket C: Endpoint Hammering** — every endpoint tested with valid/invalid/malformed/oversized payload + missing-auth + expired-token + SQL-injection-shaped string. Any 500 response = P0 (unhandled exception leak). Stack trace in error body = P0 (info disclosure).
- **Bucket D: Failure Injection** — DB unavailability, network drop, config key delete, worker SIGTERM. Hard guard: refuses to run without `.dev-squad/staging-env` flag (prevents accidental prod-like data loss).
- **Bucket E: API Pattern Compliance** — REST (pagination, idempotency keys, versioning, Retry-After), GraphQL (depth limit, complexity limit, DataLoader, introspection-disabled-in-prod), gRPC (deadlines, error code mapping, streaming pattern correctness).

### Added — failure injection hard guard

`.dev-squad/staging-env` flag file required before auditor runs Bucket D failure injection. Without it, auditor refuses (prints error, exits). Mitigates risk of running chaos tests against shared/prod environments.

### Why these changes
- User feedback during v4.7 design: "jika agent terlalu besar sebaiknya pecah jadi beberapa agent baru" — reviewer was at ~770 lines / 9 distinct roles after v4.6. Splitting respects single responsibility, reduces prompt bloat per dispatch, enables Phase 5 parallel execution.
- "performance and stability improvement" + "code quality improvement" + "support golang tidak hanya js" + "include database performance, merge, maxconnections, sampe pemilihan cara penggunaan api" — direct asks. Stability + DB perf go to auditor Phase 5.6; code quality goes to auditor Phase 5.7 with multi-language tool matrix; API pattern compliance is Bucket E.
- Performance load testing (k6 / lighthouse) deliberately deferred per user direction — "untuk k6 dan lighthouse kurasa belum saatnya, atau bisa dibuatkan skill terpisah". Future release as separate plugin/skill.

### Documentation
- README updated: team table 8 → 10, agent count corrected, new agents documented.
- `commands/build.md` Phase 5 section rewritten for 3-way parallel dispatch with detailed lane responsibilities.
- `skills/dev-squad/SKILL.md` Team Members table updated; Database/Query Optimization workflow diagrams updated to use auditor for DB perf work.
- No opus quota impact — both new agents are sonnet.

## [4.6.0] — QA hardening: functional verification, LOOKUP enforcement, fresh-eyes debugging

This release closes three quality gaps observed in earlier versions: (1) reviewer never executed the app — bugs caught only at user manual test, (2) MCP lookup was prompt-only and skipped under turn pressure during debug, (3) authors debugged their own code with no fresh-eyes intervention for complex multi-service / browser / multi-module bugs.

### Added — Phase 5.5 FUNCTIONAL VERIFICATION (reviewer)
- **Reviewer must EXECUTE the app, not just read diff.** New mandatory phase between Multi-Angle Review (5) and Metrics Report. Boots backend + frontend, drives golden path via `playwright`, audits every interactive element (no-action buttons, dead links, dead forms = findings), smoke-tests every API endpoint against contract, captures browser console + network logs, traces full data round-trip.
- Output: `.dev-squad/functional-verification.md` with golden-path table, interactive-element audit, API smoke results, console findings, severity verdict.
- **Veto extended**: P0 functional findings (runtime crash, missing endpoint, broken auth, button without onClick) and P1 in golden path now block APPROVE — matching the existing P0/P1 security veto.
- Graceful degrade: if `playwright` / `superpowers-chrome` MCP not installed, document degraded status and fall back to `curl` + `Bash` artifact checks. Coordinator decides ship/no-ship.
- `reviewer.md` `maxTurns` raised 21 → 35 to accommodate execution overhead. Skills added: `playwright-skill:playwright-skill`, `superpowers-chrome:browsing`.

### Added — LOOKUP enforcement via output format (backend, frontend, coordinator)
- **Required output format for ANY debug response** in `backend.md` and `frontend.md`: `## LOOKUP / ## HYPOTHESES / ## DIAGNOSIS / ## FIX / ## VERIFICATION` blocks. LOOKUP must contain verbatim quotes from WebSearch + context7 + grep-github. Frontend version adds mandatory browser inspection (playwright/chrome-devtools console + network + DOM snapshot) when bug is browser-reproducible.
- **HYPOTHESES block via sequential-thinking MCP** is mandatory for complex bugs (multi-service, multi-module, race condition, hydration, intermittent). Authors must generate ≥3 ranked hypotheses before fixing.
- **Coordinator validates LOOKUP block on receipt** (`coordinator.md` self-healing loop). New "LOOKUP Validation Rules" table — coordinator auto-rejects responses with empty LOOKUP, placeholder text in verbatim quotes, all-three-no-result without justification, missing HYPOTHESES on complex bug, DIAGNOSIS not citing LOOKUP findings, or VERIFICATION without verbatim output. Three rejections in a row on same iteration = advance to next tier.

### Added — Fresh-eyes investigation tier (coordinator + reviewer)
- **Self-healing loop is now 3-tiered**: iterations 1-2 = author retries (with LOOKUP enforcement), iteration 3 = reviewer in **Investigation Mode** (fresh eyes, NOT fix), iterations 4-5 = architect re-design.
- **Trigger conditions for fresh-eyes handoff**: same error persists across 2 iterations (author thrashing), error crosses service/module/browser boundary, browser-runtime state involved, or author's iteration-2 LOOKUP returned all "no relevant result".
- **Investigation Mode produces an Investigation Report**, not a fix: re-done LOOKUP, minimal repro, cross-boundary trace, browser-state inspection (playwright/chrome), git-history analysis, ≥3 hypotheses via sequential-thinking, root cause + recommended fix. Author then applies the fix in their context (separation of diagnosis from ownership).
- Investigation Mode escalation paths: `UNABLE TO REPRODUCE` → ask coordinator for environment/data state; `NEEDS ARCHITECT` → jump to iteration 4.
- New section in `reviewer.md`: "Investigation Mode (Fresh-Eyes Debugger)" with full investigation steps, output format, escalation triggers.

### Added — self-healing iteration log
- Coordinator maintains `.dev-squad/self-healing-log.md` per build. Each iteration writes: tier (author / reviewer-investigation / architect), agent dispatched, LOOKUP audit (verbatim queries + URLs), hypothesis tested, result. Feeds Phase 7 LEARN — recurring iteration patterns reveal which bug classes need preventive fix.

### Added — anti-thrashing rule (iterations must show progress)
- **Iteration count is not progress.** Coordinator now compares each iteration's error output against the previous iteration's. Same error verbatim, same root cause with moved symptom, or same hypothesis re-tried = THRASHING detected → skip remaining retries at this tier and advance immediately (fresh-eyes if at iter 2, architect if at iter 4).
- **Required: each iteration produces a Progress Marker.** Author response must include `## Progress Since Last Iteration` block: what changed in code, what changed in error, what was definitively learned. Missing or empty Progress Marker = reject and advance tier.
- **Hard stop at 3 thrashing detections per build** → escalate to user immediately regardless of iteration counter. Three thrashes = systemic issue (tooling, environment, fundamentally wrong approach), more iterations cannot fix.

### Added — current-info enforcement at project start (not just debug)
- **Phase 0 ULTRAPLAN (coordinator)** now mandates a CURRENT-INFO LOOKUP step before any tech-stack pre-decision. WebSearch with current-year filter ("{tech} latest version {year}", "{framework} known issues {year}", "{tool} deprecated") + context7 for current API surface. master-plan.md must include an "Evidence" section with ≥3 verified lookups. Pre-deciding from training data alone is now blocked — coordinator's recall of "the standard library for X" may already be deprecated.
- **Architect DISCOVER phase** strengthened: explicit current-year WebSearch queries, currency cross-check ("{library} GitHub releases" / "{library} npm latest" for every recommended library to confirm not superseded), context7 fallback to WebSearch when docs are >6 months old for fast-moving libraries.
- **Architect Tech Stack Recommendation template** Evidence section now requires WebSearch row covering recency check + post-mortem/outage research, in addition to context7 + grep-github + benchmarks.

### Why these additions
User feedback during v4.6.0 development:
- "pastikan iteration benar benar menyelesaikan masalah tidak hanya perulangan sia sia" — without anti-thrashing, the new 5-iteration self-healing tier could burn iterations on the same bad fix.
- "gunakan tooling websearch atau semacamnya saat proses information gathering... untuk debugging atau starting project untuk memastikan informasi terupdate" — v4.5 mandated WebSearch for debug; v4.6 extends it to project start (Phase 0 + DISCOVER) since training data lags reality by months and pre-decisions from memory introduce silent risk.

### Why these changes
Observed symptoms in v4.5 builds:
- Bugs ketangkap di manual test atau bahkan bikin app error — reviewer pure static analysis, never boots app. Logic errors at backend level and silent button-without-onClick at frontend lolos review.
- `context7` and `sequential-thinking` MCP **never called during debugging**, only during early phases. Prompt instruction in v4.5 was insufficient — agents rationalize-skipped under maxTurns pressure.
- Complex bugs (multi-service, browser, multi-module) failed self-healing because author = bug-introducer = blind to own pattern.

### Documentation
- README directory tree updated.
- v4.6.0 changes are reviewer-side and orchestrator-side; no opus-tier dispatch added (reviewer remains sonnet). User's weekly opus quota is not impacted by this release.

## [4.5.0] — PDCA cycle, evidence-grounding, MCP cleanup

This release adds a full PDCA (Plan-Do-Check-Act) cycle to the swarm, mandates evidence-grounded research/review/debugging, and cleans up MCP tool references throughout.

### Added — PDCA cycle
- **Phase 7 LEARN** added to zero-to-ship workflow. After SHIP, coordinator runs a retrospective: gathers PRD success metrics, Phase 5 metrics report, gotchas, rework counts. Reviewer produces `.dev-squad/retrospective.md`. Wins append to new `.dev-squad/playbook.md`. Gaps go to `docs/next-iteration.md`. Lessons write to agent-memory + episodic memory.
- **`/dev-squad retrospective [scope]`** — new command. Triggers an explicit Act phase outside zero-to-ship (after a feature, sprint, or post-incident). Recommended cadence: weekly via `/schedule`.
- **PRD "Evidence Sources" table — mandatory.** PRDs now require ≥3 documented external lookups (WebSearch, context7, grep-github) before they ship. Empty Evidence Sources = PRD rejected by reviewer.
- **PRD "Goals & Success Criteria" — numeric targets mandatory.** `fast` and `secure` are no longer accepted; every metric requires a number + measurement source. These targets feed Phase 5 Check.
- **Phase 5 Metrics Report** — reviewer now produces a quantitative artifact (target vs actual + Δ + measurement source per metric) alongside the findings list. The metrics report feeds Phase 7 LEARN.

### Added — evidence-grounding
- **CVE Audit (reviewer)** — local tooling alone (`npm audit`, `govulncheck`, `pip-audit`) is no longer sufficient. Reviewer must WebSearch GitHub Security Advisories + NVD for every dependency on auth/data/API changes. Local tools lag new CVEs by days/weeks.
- **Self-healing loop step 1.5: LOOKUP** — coordinator's self-healing loop now mandates WebSearch + context7 + grep-github BEFORE diagnosing. "Most bugs are 5min if Googled, 30min if guessed."
- **Debugging Phase 0: EXTERNAL LOOKUP** — backend and frontend agents must WebSearch the exact error message + context7 the failing library + grep-github the pattern as the FIRST debugging action. Phase 1 (root cause investigation) now starts only after Phase 0.
- **Architect DISCOVER phase** — WebSearch added as mandatory market/post-mortem research (in addition to grep-github + context7) and as a fallback when context7 has no docs for a library.

### Changed
- **Removed `tools:` whitelist from all 8 agent frontmatters.** Earlier versions whitelisted `Bash, Read, Write, Edit, Grep, Glob, Skill` but did NOT include MCP tools, so agents technically could not call MCPs even when the prompt instructed them to. Removing the whitelist makes agents inherit all available tools (including whatever MCP servers the user has installed).
- **MCP references in prompts/docs use short natural names** (e.g. `context7`, `mermaid-mcp`, `episodic-memory`) instead of full tool identifiers (`mcp__context7__query-docs`, `mcp__plugin_episodic-memory_episodic-memory__search`, etc.). Applied across all 8 agent prompts, `skills/dev-squad/SKILL.md`, and `skills/dev-squad/config.json`. Reasons: hardcoded long names rot when upstream MCPs rename tools (mermaid-mcp tools recently disconnected as proof), and short names degrade gracefully when the MCP isn't installed on the user's machine.
- **Zero-to-ship is now 8 phases**, not 7. Phase 0 ULTRAPLAN through Phase 7 LEARN. Phases 0-2 = Plan, Phases 3-4-6 = Do, Phase 5 = Check, Phase 7 = Act.
- `hooks/check-workflow.sh` phase list updated to include `learn`.

### Added — repo hygiene
- `CLAUDE.md` at the repo root — guidance for future Claude Code instances working on this plugin (architecture, hook event matrix, version sync rules, MCP naming convention).
- `CHANGELOG.md` — this file.

### Documentation
- README updated: corrected version reference (was stuck on `v2.0`), team composition now lists all 8 agents (writer was missing), directory tree updated to reflect actual layout.

## [4.4.1] — Earlier release

### Added
- Enforce MCP usage (context7 + sequential-thinking) in agent prompts across all 8 agents.

## [4.4.0]

### Added
- **Writer agent** — eighth team member. Produces production-ready page copy, microcopy, legal pages, SEO metadata, and documentation. Frontend agent now uses writer's content constants instead of hardcoding text.
- Design taste overhaul for the frontend agent — anti-slop rules, design token workflow before coding, reference-driven aesthetics.
- Auto-install skills hook — coordinator can install approved skills at workflow start.

## [4.3.0]

### Added
- External skill integration — agents can load skills from approved marketplaces (anthropics/, supabase/, vercel-labs/, obra/superpowers, softaworks/, muratcankoylan/, ehmo/).
- Supporting hooks & rules.

## [4.2.x]

### Added
- `maxTurns` per agent (`coordinator: 50`, `architect/backend/frontend/writer: 30`, `devops/reviewer: 21`, `git-ops: 15`) to prevent premature stop.
- Expanded max parallel agents from 12 to 21.
- **Phase 0 ULTRAPLAN** — coordinator thinks deeply (scope, entities, tech stack, risks) and writes `.dev-squad/master-plan.md` BEFORE dispatching any agent.

### Fixed
- `check-workflow.sh` removed from `Stop` event (conflicted with ralph-loop/double-shot-latte plugins).
- `check-workflow.sh` made non-blocking to prevent infinite stop loops.
- Stop hook only blocks once per session.
- `stop-verify.sh` skips silently when no project or workflow is active.

## [4.1.x]

### Added
- Continuous learning protocol — every agent must write learnings to agent-memory and append mistakes to `.dev-squad/gotchas.md` before reporting done.
- Stop verification gate.
- Truncation detection hook.
- Self-correction log (`gotchas.md` pattern).

## [4.0.0]

### Added
- 7 skills + 20 rules adopted from ECC patterns.
- Memory bootstrap and completion definitions for all agents (carried over from v3.4).

## [3.x]

### Added
- v3.4: memory bootstrap + explicit "you are NOT done until..." completion definitions for every agent.
- v3.3: cross-plugin skill access + MCP server access.
- v3.2: advanced hooks system (9 hooks total).
- v3.1: smart model routing (opus for critical/integration, sonnet for standard, haiku for gates) + self-healing loop (max 5 retries).
- v3.0: native orchestration upgrade with dual-mode Agent Teams (TeamCreate when `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`, subagent fan-out as fallback).

### Fixed
- Hardcoded `.mcp.json` removed — MCP installation is the user's responsibility.
- Agent naming format corrected to `dev-squad:{name}` (not the doubled `dev-squad:dev-squad:{name}`).

## [2.x]

### Added
- v2.1: monorepo standard structure (apps/ + packages/ + infra/) and production-grade checklists.
- v2.0: **Zero-to-Ship** workflow — build a full project from one sentence through 6 automated phases.
- Auto-update via SessionStart hook.

## [1.0.0]

Initial release. Core agent swarm with coordinator, architect, backend, frontend, reviewer, devops, git-ops.
