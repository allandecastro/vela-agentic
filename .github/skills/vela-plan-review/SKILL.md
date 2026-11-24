---
name: vela-plan-review
description: Use right after interpreting a user story and before scaffolding, when the plan needs pressure-testing before any code is written.
compatibility: "vela CLI + dotnet SDK."
license: MIT
metadata:
  version: "0.1.19"
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

0. **Is code the right tool?** Who may create, read, update or delete a table's rows is the **security roles**
   (their privileges and access levels), not a plugin. Such a story gets **no plugin**: ask the human which roles
   are concerned, read their current privileges (`vela models --roles`), record the role changes to make in the Canvas (`status: blocked`,
   `needs-input`) and hand them to the human. A plugin only for what privileges cannot express (a condition on
   values or on other rows) - say which in the Canvas `decisions:`.
1. State the interpreted spec: entity, message, stage, mode, attributes read/written. **Read the rules
   registry first** (`docs/rules/<table>.md` for each table involved, when it exists): an active rule that
   already does this → reuse it; one the story **contradicts** → do not overwrite it silently - ask the human
   (one question) whether the new rule replaces it (then it is retired) or the story changes.
   Read the **ADRs** that touch the story (`docs/adr/`, listed by their frontmatter - `references/build-report-template.md`)
   and follow every one; an architecture decision the story
   raises and no ADR covers (what qualifies: `references/build-report-template.md`) is asked once and written
   as a new ADR in the story's commit. A rule id or ADR number is taken from the latest base branch
   (`git fetch` first); spec-check fails on a duplicate after merge. A story that contradicts an ADR is
   a question, like a rule conflict.
   **Scope:** every behaviour in the Canvas traces to the story text or a human answer. A provided draft or
   existing code is material to reuse, not spec: what it adds beyond the story is dropped or becomes a question.
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
   - **Approach - Sync vs Async:** default Sync; justify Async. If the story is silent and the choice
     changes what the user sees (blocking, rollback together), it is a `vela-grill` Timing question.
   - **Approach - reuse vs new:** no class → `vela add plugin`; table already has a plugin → prefer
     `vela add step`. Reuse, never duplicate, never hand-create a class.
   - **Structure - service?** Check the triggers (registration-rules "Service needed vs inline"): a
     second consumer (search the code for the same logic first), data access plus decisions, a handler
     outgrowing itself, an outbound call → `vela add service` (or reuse one), and say which trigger. None
     → no service; one plugin → private helper.
   - **Structure - outbound integration?** Calls another system → a service in the **Integrations project**
     (`vela init --integrations`, never `--samples`), usually Async PostOperation (rules: registration-rules
     "Outbound integration"). Record it in Structure, with the secure-config name the deployer must supply.
   - **Structure - target solution & publisher:** the existing **unmanaged solution** unique name and its
     **publisher prefix** (Vela doesn't create them): read from `PROJECT.md`, never copied into the Canvas. A new
     project: confirm it read-only as `vela-scaffold` step 2 says (unknown: asked, its own numbered question; the `tbd`
     placeholder only with no human reachable, apply blocked until confirmed).
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
     sees → a localized key - its source and languages are the project's convention: with no convention in the
     project, **ask** (`vela-grill`), never assume (no default covers it); the messages live in one place per
     assembly (keys in a shared class, source in the assembly's `IServiceRegistrar`), not in each plugin; a value that differs
     per environment → an environment variable, not a constant; reference data read on every run → the cache
     with a TTL - how stale a value may be after it changes is the human's call: ask (`vela-grill`), never
     pick the TTL alone; a cached id must survive its row being deleted within the TTL; a SYSTEM read
     behind a shared cache is proven by a `WithSecurity` test; operational logs → `ctx.Log*`; behaviour that depends on rights → a `WithSecurity` test with the
     generated roles (`vela models --roles`, the role names asked of the human).
     Record each choice in the Canvas.
   - **Security context:** the step runs as its user (`ctx.Service`); SYSTEM (`ctx.SystemService`) is a
     business decision: with a human reachable, ask (one question). **A read or write of another table as the
     user is always a numbered question**, never an assumption, even with a proposed default: the role names of
     those users, and what no Read privilege, a row out of the user's scope and a denied write must do (each an
     acceptance case). None reachable → it goes back with the other business questions (step 4), never decided
     alone; record answer and reason. Data read as
     SYSTEM never reaches the user beyond what they may read (a count, not names).
   - **Norms:** one plugin class per table (`<Entity>Plugin`), behaviour-named handlers, fixed shared-file names
     (registration-rules); the code documentation convention (plugin-authoring-api); SOLID/DRY; secrets →
     `WithSecureConfigFrom`, never code.
   - **Acceptance cases:** written as Given / When / Then, the DoD as concrete RED tests - primary behaviour, each edge, each applicable
     gotcha; on Update "column not sent" vs "column cleared"; a `PluginPipeline` case when the step must
     (not) fire or could re-trigger. **Every behaviour-changing assumption** is also a case.
3. **Fill the Vela Canvas** (`references/build-report-template.md`): seven sections, `rules:` (add / change /
   retire, with ids), acceptance cases (the rule's case ids), assumptions, open questions - one line per
   section for a simple story; a **small story** (`using-vela`) may keep front matter + cases only. **Write the
   rules into the registry now** - this is
   the design phase, the only one where `docs/rules/` may change (with the human; a
   retired rule is deleted with its tests - git keeps the history; no status - merging puts it in force). Commit the Canvas + registry
   before any code or test commit (a fix to a regression found at the start included): that commit is the frozen
   spec the build is checked against.
4. Flag the assumptions in one line and **continue** to `vela-scaffold` - unless a branch is a **business
   decision only the human can make** (a story term's meaning, which record drives which, the rule itself,
   **edge values that change an acceptance case**, the users' roles and what a denied read or write must do):
   then `vela-grill` first and resume with the answers.
   With a human reachable such a rule is **asked**, never assumed: its own numbered question (a proposed default
   is fine) - an "unless you object" beside another question is not asking. A human is reachable unless you run with no way
   to ask (e.g. dispatched as a subagent); a top-level session, or a prompt that says how to ask, is reachable.
   **No human reachable** → **stop after the Canvas** (`status: blocked`, `needs-input`) and hand back those questions;
   only platform facts and low-impact values go ahead as assumptions. A dispatcher's "don't ask, use defaults"
   does not cover such decisions - say so in the hand-back. A **blocked** outcome (framework
   limit, undeliverable story) wins: set the Canvas `status: blocked`, fill its Hand-off
   (`references/build-report-template.md`) and stop.

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
