---
name: vela-plan-review
description: Use right after interpreting a user story and before scaffolding, when the plan needs pressure-testing before any code is written.
compatibility: "vela CLI >= 0.27.0 (Vela.Plugins >= 0.39.0); dotnet SDK."
---

# Review the plan (self-grilling)

> Paths like `references/<file>.md` in this skill are relative to **this skill's folder** (the
> directory containing this `SKILL.md`), not to the project you are working in.

Interrogate your own plan until every branch resolves. This front gate catches a mis-interpreted story
before a wasted build. It is **advisory**: flag unresolved assumptions and continue; do not block.

## When to use

- Right after Intake (story → interpreted spec), before `vela-scaffold`.

## Process

Announce: `Using vela-plan-review to grill the plan`.

1. State the interpreted spec: entity, message, stage, mode, attributes read/written. **Read the rules
   registry first** (`docs/rules/<table>.md` for each table involved, when it exists): an active rule that
   already does this → reuse it; one the story **contradicts** → do not overwrite it silently - ask the human
   (one question) whether the new rule replaces it (then it is retired) or the story changes.
2. **Grill it** (unanswered → assumption or open question). Decisions and legal matrix:
   `references/registration-rules.md`; traps: `references/dataverse-gotchas.md`.
   - **Step or Custom API?** Reaction to a table event → plugin step. An operation someone *calls* with
     inputs/outputs → `vela-custom-api`.
   - **Message/stage/mode:** "set or changed" can cover **Create** too - decide both, or ask (`vela-grill`).
     Changing a column of the same record → **PreOperation** on `ctx.Request.Target`. PostOperation only for
     the new id, other records, or the saved result (Sync PostOperation is still in the transaction; only
     Async runs after commit). PostOperation + `Update` of the same record needs a written reason.
   - **Recursion:** does a write re-trigger this or another plugin? Fix it in the design;
     `SkipWhenDepthAbove(n)` / `ctx.Depth` is not a fix (recursion gotcha).
   - **Approach - Sync vs Async:** default Sync; justify Async.
   - **Approach - reuse vs new:** no class → `vela add plugin`; table already has a plugin → prefer
     `vela add step`. Reuse, never duplicate, never hand-create a class.
   - **Structure - service?** Thin handler; real/reusable logic → `vela add service`; none for a
     one-liner; one plugin → private helper, across plugins → service.
   - **Structure - outbound integration?** Calls another system → a service in the **Integrations project**
     (`vela init --integrations`, never `--samples`), usually Async PostOperation (rules: registration-rules
     "Outbound integration"). Record it in Structure, with the secure-config name the deployer must supply.
   - **Structure - target solution & publisher:** the existing **unmanaged solution** unique name and its
     **publisher prefix** (Vela doesn't create them). With an org, confirm read-only:
     `vela solution show <uniquename> --json`. `--publisher-prefix` must equal that prefix; `--prefix` is
     only the namespace. **Unknown and no org?** Ask the human once (`vela-grill`) if reachable; otherwise
     scaffold with an obvious placeholder (`--publisher-prefix tbd`), list it as an open question, and state
     in the Gate that apply is blocked until confirmed.
   - **"When X changes" on Update:** the filter fires whenever the column is *sent*, even unchanged.
     Record whether the value must differ (compare `ctx.PreImage`); write, or set an unsent Target column,
     only when the value differs.
   - **Trigger:** `FilterOn` is mandatory on Create/Update (VELA020) and **gates Create too** (the
     Microsoft docs are wrong): a create sending none of the filtered columns does not fire. "Every
     create" → filter on a column every create sends; record the residual risk.
   - **Images / legality:** which images? Legal per the matrix?
   - **Association:** `vela add plugin <Name> --entity <E> --message Associate`, scoped with
     `.ForRelationship("<schema name>")`; record the schema name(s) and that either side can be the Target.
     Associate vs marketing-list `AddMember` / `AddListMembers` vs dynamic lists (no event) is a question
     for the human - ask (`vela-grill`) or list it as open.
   - **Bulk:** `*Multiple` or single-record, never both; record why. A "bulk only" story also runs on
     single Updates - a scope point for the human, listed at the Gate.
   - **Models:** which tables/columns must `vela-models` generate (a minimal scaffold has none)?
   - **Platform services** (`references/plugin-authoring-api.md`, *Platform services*): a message the user
     sees → a localized key (the message source is the project's convention: ask once); a value that differs
     per environment → an environment variable, not a constant; reference data read on every run → the cache
     with a TTL; operational logs → `ctx.Log*`; behaviour that depends on rights → a `WithSecurity` test.
     Record each choice in the Canvas.
   - **Security context:** default is the step's user (`ctx.Service`). SYSTEM (`ctx.SystemService`) is a
     business decision: with a human reachable, ask (one question); record answer and reason. Data read as
     SYSTEM never reaches the user beyond what they may read (a count, not names).
   - **Norms:** generated naming + prefix; SOLID/DRY; secrets → `WithSecureConfigFrom`, never code.
   - **Acceptance cases:** written as Given / When / Then, the DoD as concrete RED tests - primary behaviour, each edge, each applicable
     gotcha; on Update "column not sent" vs "column cleared"; a `PluginPipeline` case when the step must
     (not) fire or could re-trigger. **Every behaviour-changing assumption** is also a case.
3. **Fill the Vela Canvas** (`references/build-report-template.md`): seven sections, `rules:` (add / change /
   retire, with ids), acceptance cases (the rule's case ids), and **write the rules into the registry now** - this is
   the design phase, the only one where `docs/rules/` may change (with the human; a new or
   changed rule is `Status: proposed (by <slug>)`, a retired one keeps its text). Commit the Canvas + registry
   before any test: that commit is the frozen spec the build is checked against.
   assumptions, open questions - one line per section for a simple story.
4. Flag the assumptions in one line and **continue** to `vela-scaffold` - unless a branch is a **business
   decision only the human can make** (a story term's meaning, which record drives which, the rule itself,
   **edge values that change an acceptance case**): then `vela-grill` first and resume with the answers.
   With a human reachable such a rule is **asked**, never assumed. No human reachable → a flagged
   assumption, listed as an open question that blocks the apply gate. A **blocked** outcome (framework
   limit, undeliverable story) wins: set the Canvas `status: blocked` and stop (see the builder's
   "Blocked stories").

## Rationalizations (excuse → rebuttal)

- "The story is clear enough." → Grill it anyway; a paragraph is cheaper than building the wrong thing.
- "I'll figure out images/filtering while coding." → Decide now; they change the registration and the
  scaffold.

## Red flags

- Any grilling branch left unanswered and not recorded as an assumption or open question.
- Proceeding without a Vela Canvas, or one whose Approach/Structure leave Sync-vs-Async or reuse-vs-new
  undecided.

## Verification

- A Vela Canvas exists with all seven sections filled (proportional), every grilling branch resolved or
  logged, and the assumptions surfaced to the user.
