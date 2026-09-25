# Plan artifact & Build Report templates

Two symmetric artifacts the `vela-builder` loop emits. Both are Markdown with YAML
front-matter, committed in the target project under `docs/vela-builds/<slug>.md` and reused
as the PR body. The Plan artifact is written at the front gate; it grows into the Build
Report at the end.

## Plan artifact (front gate — after Intake + self-grilling)

```markdown
---
kind: vela-plan
slug: account-default-description
date: 2026-09-24
status: proposed        # proposed | approved | superseded
entity: account
message: Create
stage: PostOperation
mode: Synchronous
filtering_attributes: [name]
images: []
assumptions:
  - "Description is empty means null or whitespace."
  - "Standard Account.Description; no custom column."
open_questions: []
acceptance_cases:
  - "empty Description -> defaulted to 'Created via Vela plugin'"
  - "non-empty Description -> left untouched"
skills: [vela-plan-review, vela-scaffold, vela-models, vela-plugin-authoring, vela-test-harness]
---

## User story
<verbatim story>

## Interpreted spec
<entity / message / stage / mode / attributes read+written / behaviour>

## Grilling (self-challenge) — every branch resolved
<the vela-plan-review questions and their answers; unresolved ones become open_questions>

## Acceptance cases (the RED test list)
<one line per test: primary behaviour, each edge, each applicable gotcha>

## Proposed approach
<scaffold plan, models needed, handler outline, test cases including gotcha coverage>

## Risks (from dataverse-gotchas)
<the ones that apply and how the plan addresses them>
```

## Build Report (end — grows from the Plan artifact)

Same front-matter, updated:

```markdown
---
kind: vela-build
slug: account-default-description
date: 2026-09-24
status: awaiting-apply    # awaiting-apply | applied
entity: account
message: Create
vela_cli: 0.15.1
framework: 0.26.2
packages: [Zava.Plugins.1.0.0.nupkg]
harness: pass             # pass | fail  (must be pass to reach the gate)
analyzers: clean          # clean | violations  (authored code must be clean to reach the gate;
                          # scaffold demo files' cosmetic VELA013 excluded — clean them for real)
review: pass              # pass | block  (vela-code-review: no unresolved Critical/Required)
plan_preview: clean       # clean | changes | skipped(no-org)
apply: pending
---

## User story  /  ## Interpreted spec  /  ## Assumptions
<carried from the Plan artifact>

## What was built
- Commands run: `vela init ...`, `vela add plugin ...`, `vela add test ...`
- Components created / models generated
- Handler summary (what OnExecute does) + gotchas addressed

## Evidence
- `dotnet build`: <summary line, 0 errors, and 0 analyzer VELA00x violations>
- Acceptance cases (RED→green):
  - [x] empty Description -> defaulted
  - [x] non-empty Description -> left untouched
- Harness: <test runner summary, e.g. "Total: 11, Failed: 0">  (state runner: dotnet test / Mono)
- Code review: <PASS / BLOCK; findings most-severe first, e.g. "PASS — 1 Nit">
- `vela plan`: <the diff apply WOULD make, or "skipped — no org">

Quality gate: harness green over all declared cases **and** analyzers clean **and** code review
PASS (no unresolved Critical/Required) — all three required before the apply gate.

## Gate — human approval required
Run to deploy: `vela apply -p <pkg> --solution <uniquename> -i`
This will: <exact changes>

## Open questions
<anything the human must decide>
```
