# Vela Canvas (plan) & Build Report templates

The front artifact is a **Vela Canvas** - a REASONS-style structured spec adapted to Dataverse
plugins (from Thoughtworks' SPDD). It is the single artifact the reviewer reasons about, and it
is the home for the design decisions the tooling does not make for you (Sync/Async, reuse-vs-new,
services, naming, safeguards). It grows into the **Build Report** at the end. Both are Markdown +
YAML front-matter, committed under `docs/vela-builds/<slug>.md` and reused as the PR body.

Keep it **proportional**: for a simple story, sections can be one line each; do not pad.

**One file per story:** `docs/vela-builds/<slug>.md` starts as the Canvas and is **the same file**
that grows into the Build Report (front-matter `kind: vela-canvas` → `kind: vela-build`). Before a project
exists (plan gate, grill), write it at `docs/vela-builds/<slug>.md` under the working directory;
after `vela init` it moves to the same relative path inside the project. Never another path or name. A new story
on an existing plugin gets its **own** slug and file; it references the plugin, it does not rewrite the
earlier story's record.

**Living spec (fix-spec-first):** when the requirement changes mid-build, update the Canvas
**before** the code; when you refactor without changing behaviour, update the code then **sync**
the change back into the Canvas. The Canvas stays an accurate record of the current plugin.

## Vela Canvas (front gate - produced by `vela-plan-review`)

```markdown
---
kind: vela-canvas
slug: account-default-description
date: 2026-09-25
status: proposed          # proposed | approved | blocked | superseded - stays `proposed` until a HUMAN
                          # approves; past the advisory plan gate the agent never writes `approved` itself.
                          # The Build Report (kind: vela-build) then carries the run status (awaiting-apply).
entity: account           # the table the step is registered on (may differ from the table it writes)
# One step: use the scalar fields below. A multi-step plugin uses a `steps:` list instead, e.g.
#   steps:
#     - {message: Create, stage: PreOperation, mode: Synchronous, filter: [name], handler: OnExecute, images: []}
#     - {message: Update, stage: PreOperation, mode: Synchronous, filter: [description], handler: HandleUpdate,
#        images: [{pre: [accountnumber]}]}
message: Create
stage: PreOperation        # set the default on ctx.Request.Target before the write
mode: Synchronous
filtering_attributes: [Name]   # model property names (as FilterOn / --filtering-attributes take them)
images: []                # e.g. [{pre: [statecode]}, {post: [statecode, parentcustomerid]}]
# A Custom API replaces message/stage/mode/filtering_attributes/images with:
#   custom_api: {unique_name: <pfx>_<Name>, binding: global | bound:<entity>, kind: action | function,
#                callers: [flows | code | web-api], inputs: [email:string!], outputs: [leadScore:int]}
reuse: new-plugin         # new-plugin | add-step:<PluginName> | reuse:<name>
service: none             # none | new:<Name> | reuse:<Name>
solution: <uniquename>    # target unmanaged solution (must already exist in the org); passed to plan/apply --solution
publisher_prefix: <pfx>   # the solution publisher's prefix, confirmed by `vela solution show <uniquename> --json`;
                          # = the scaffold --publisher-prefix (Custom API unique names)
namespace_prefix: Zava    # the scaffold --prefix (PascalCase project/namespace prefix, not the publisher prefix)
acceptance_cases:
  - "empty Description -> defaulted to 'Created via Vela plugin'"
  - "whitespace Description -> defaulted"
  - "non-empty Description -> left untouched"
decisions:                # business decisions and who made them (vela-grill answers)
  - {by: human, what: "'empty' means null or whitespace"}
assumptions:              # platform facts relied on, not decided by the human
  - "Create PreOperation edits of ctx.Request.Target are persisted with the record."
open_questions: []
skills: [vela-plan-review, vela-scaffold, vela-models, vela-plugin-authoring, vela-test-harness, vela-code-review]
---

## R - Requirements & DoD
<story verbatim + the acceptance cases restated as Definition of Done>

## E - Entities
<Dataverse entities and the attributes read/written, e.g. account.description (read + write)>

## A - Approach
<Stage, Sync vs Async and WHY (see registration-rules); reuse vs new and WHY. e.g. "Sync
PreOperation: the default is set on ctx.Request.Target before the platform writes the record - no
extra write, no second Update event. New plugin: no Account plugin exists yet.">

## S - Structure
<Where it fits: which project, `vela add plugin` vs `vela add step` on an existing plugin, and
whether a service is needed or an existing one reused.>

## O - Operations
<The concrete steps, reviewable before code: the RegisterStep() chain, the OnExecute outline,
and the test cases (= the acceptance cases as harness tests).>

## N - Norms
<Naming (per generated conventions + prefix), SOLID/DRY intent: thin handler/SRP, reuse over
duplication.>

## Hand-off (only when status: blocked)
<What blocks the story (e.g. a framework limit), the evidence, what would unblock it, and the open
questions for the human. Nothing is scaffolded or packaged for a blocked story.>

## S - Safeguards
<Registration legality from registration-rules (e.g. no post-image on Delete; mandatory Create
FilterOn); applicable gotchas; no secrets in code; stop before apply.>
```

## Build Report (deploy gate - the Canvas grown, with evidence)

The Build Report keeps every Canvas front-matter key (acceptance_cases, decisions, assumptions,
solution, publisher_prefix, ...) and adds the build keys below; only `kind` changes.

```markdown
---
kind: vela-build
date: 2026-09-25
slug: account-default-description
status: awaiting-apply    # awaiting-apply | applied
entity: account
message: Create
vela_cli: 0.24.1
framework: 0.33.0
packages: [Zava.Plugins.1.0.0.nupkg]   # the plugin package (an Integrations package only with --samples + an outbound flow)
package_sha256: <sha256 of the previewed package>
signed: no                # yes | no (a human signs before apply) | n/a (org does not require it) | unknown (asked at the gate)
harness: pass             # pass | fail  (must be pass to reach the gate)
analyzers: clean          # clean | violations  (authored code)
review: pass              # pass | block  (no unresolved Critical/Required)
plan_preview: changes     # changes (exit 8 with --detailed-exitcode) | clean (exit 0, nothing to do) | unavailable (connection failed: record the command + exit)
plan_command: "vela plan -p artifacts/Zava.Plugins.1.0.0.nupkg --solution ZavaSales --url <org> --detailed-exitcode --out plan.json"
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
- Solution: `vela solution show <uniquename> --json` → `{"solution": ..., "publisherPrefix": ...}` (exit 0)
- Package: <path> · sha256 <hash> · signed <yes/no/n/a/unknown>
- `vela plan --solution <uniquename>` (on that package, after review): <the `operations` apply WOULD run
  (package + steps / Custom APIs), every `diagnostics` line, and the exit code; or "unavailable" with the
  exact command and its exit code>

## Sync log
<any Canvas changes made during the build (requirement change → Canvas updated first; refactor →
synced back), so the Canvas stays accurate>

## Run trace
Machine-readable audit of the run - one row per step, appended as you go. Makes the run
auditable and replayable, and is the structured input for `diagnosing-vela`. Every value is
copied from what the tool printed or returned - `exit` is the real exit code, `-` when nothing ran.
Never estimate or fill in a value you did not observe (no timings from memory).

| # | step | skill | command | exit | verdict |
|---|------|-------|---------|------|---------|
| 1 | scaffold | vela-scaffold | `vela init ZavaSales --prefix Zava --publisher-prefix zava` | 0 | ok |
| 2 | model | vela-models | `vela models --entities account --project src/Zava.Shared/Zava.Shared.csproj --url <org>` | 0 | Generated <N> file(s) |
| 3 | test-red | vela-test-harness | `mono …/xunit.console.exe … -parallel none` | 1 | RED 2 fail (expected) |
| 4 | verify | vela-test-harness | `mono …/xunit.console.exe … -parallel none` | 0 | GREEN 12/12 |
| 5 | review | vela-code-review | (self-review) | - | PASS 2 Nits |
| 6 | package | vela-apply | `dotnet build ZavaSales.sln -c Release` (→ `artifacts/Zava.Plugins.1.0.0.nupkg`, dll checked) | 0 | ok |
| 7 | plan | vela-apply | `vela plan -p artifacts/Zava.Plugins.1.0.0.nupkg --solution ZavaSales --url <org> --detailed-exitcode --out plan.json` | 8 | changes: create package + 1 step |

## Gate - human approval required
Run to deploy (after `shasum -a 256 <pkg>` matches `package_sha256`):
`vela apply -p <pkg> --solution <uniquename> -i`  - this will: <exact changes from the plan's `operations`>.
Exit `7` = partial apply (fix the cause, re-run); `5` = not converged (the org still differs) - both are
reported, never "done".

## Open questions
<anything the human must decide>
```
