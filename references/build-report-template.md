# Vela Canvas (plan) & Build Report templates

The front artifact is a **Vela Canvas** — a REASONS-style structured spec adapted to Dataverse
plugins (from Thoughtworks' SPDD). It is the single artifact the reviewer reasons about, and it
is the home for the design decisions the tooling does not make for you (Sync/Async, reuse-vs-new,
services, naming, safeguards). It grows into the **Build Report** at the end. Both are Markdown +
YAML front-matter, committed under `docs/vela-builds/<slug>.md` and reused as the PR body.

Keep it **proportional**: for a simple story, sections can be one line each; do not pad.

**Living spec (fix-spec-first):** when the requirement changes mid-build, update the Canvas
**before** the code; when you refactor without changing behaviour, update the code then **sync**
the change back into the Canvas. The Canvas stays an accurate record of the current plugin.

## Vela Canvas (front gate — produced by `vela-plan-review`)

```markdown
---
kind: vela-canvas
slug: account-default-description
date: 2026-09-25
status: proposed          # proposed | approved | superseded
entity: account
# One step: use the scalar fields below. A multi-step plugin uses a `steps:` list instead, e.g.
#   steps:
#     - {message: Create, stage: PostOperation, mode: Synchronous, filter: [name]}
#     - {message: Update, stage: PreOperation,  mode: Synchronous, filter: [description]}
message: Create
stage: PostOperation
mode: Synchronous
filtering_attributes: [name]
images: []
reuse: new-plugin         # new-plugin | add-step:<PluginName> | reuse:<name>
service: none             # none | new:<Name> | reuse:<Name>
acceptance_cases:
  - "empty Description -> defaulted to 'Created via Vela plugin'"
  - "whitespace Description -> defaulted"
  - "non-empty Description -> left untouched"
assumptions:
  - "'empty' means null or whitespace."
open_questions: []
skills: [vela-plan-review, vela-scaffold, vela-models, vela-plugin-authoring, vela-test-harness, vela-code-review]
---

## R — Requirements & DoD
<story verbatim + the acceptance cases restated as Definition of Done>

## E — Entities
<Dataverse entities and the attributes read/written, e.g. account.description (read + write)>

## A — Approach
<Sync vs Async and WHY (see registration-rules); reuse vs new and WHY. e.g. "Sync: the default
must be visible on the committed record. New plugin: no Account plugin exists yet.">

## S — Structure
<Where it fits: which project, `vela add plugin` vs `vela add step` on an existing plugin, and
whether a service is needed or an existing one reused.>

## O — Operations
<The concrete steps, reviewable before code: the RegisterStep() chain, the OnExecute outline,
and the test cases (= the acceptance cases as harness tests).>

## N — Norms
<Naming (per generated conventions + prefix), SOLID/DRY intent: thin handler/SRP, reuse over
duplication.>

## S — Safeguards
<Registration legality from registration-rules (e.g. no post-image on Delete; mandatory Create
FilterOn); applicable gotchas; no secrets in code; stop before apply.>
```

## Build Report (deploy gate — the Canvas grown, with evidence)

```markdown
---
kind: vela-build
slug: account-default-description
status: awaiting-apply    # awaiting-apply | applied
entity: account
message: Create
vela_cli: 0.15.1
framework: 0.26.2
packages: [Zava.Plugins.1.0.0.nupkg]
harness: pass             # pass | fail  (must be pass to reach the gate)
analyzers: clean          # clean | violations  (authored code; scaffold-demo VELA013 excluded)
review: pass              # pass | block  (no unresolved Critical/Required)
plan_preview: clean       # clean | changes | skipped(no-org)
apply: pending
---

## Canvas
<the approved Vela Canvas, carried forward; note any mid-build updates under "Sync log">

## What was built
- Commands run: `vela init ...`, `vela add plugin ...`, `vela add test ...`
- Components created / models generated; handler summary (what OnExecute does)

## Evidence
- `dotnet build`: <0 errors, 0 analyzer VELA00x in authored code>
- Acceptance cases (RED→green): [x] empty→defaulted  [x] whitespace→defaulted  [x] non-empty→untouched
- Harness: <runner summary + runner name>
- Code review: <PASS / BLOCK; findings most-severe first>
- `vela plan`: <the diff apply WOULD make, or "skipped — no org">

## Sync log
<any Canvas changes made during the build (requirement change → Canvas updated first; refactor →
synced back), so the Canvas stays accurate>

## Gate — human approval required
Run to deploy: `vela apply -p <pkg> --solution <uniquename> -i`  — this will: <exact changes>

## Open questions
<anything the human must decide>
```
