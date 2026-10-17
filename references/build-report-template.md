# Vela Canvas (plan) & Build Report templates

The **Vela Canvas** is a REASONS-style spec adapted to Dataverse plugins (from Thoughtworks' SPDD): the
single artifact the reviewer reasons about, and the home of the decisions the tooling does not make
(Sync/Async, reuse-vs-new, services, naming, safeguards). It grows into the **Build Report**. Both are
Markdown + YAML front-matter, reused as the PR body. Keep it **proportional**: one line per section is fine
for a simple story.

**One file per story:** `docs/vela-builds/<slug>.md` starts as the Canvas and becomes the Build Report
(`kind: vela-canvas` → `kind: vela-build`). Before a project exists, write it at that path under the working
directory; after `vela init`, at the same relative path inside the project. Never another path or name. A
new story on an existing plugin gets its **own** slug and file, referencing the plugin.

**Living spec (fix-spec-first):** a requirement change updates the Canvas **before** the code; a
behaviour-neutral refactor updates the code, then is **synced** back into the Canvas.

## Vela Canvas (front gate - produced by `vela-plan-review`)

```markdown
---
kind: vela-canvas
slug: account-default-description
date: 2026-09-25
status: proposed          # proposed | approved | blocked | superseded - only a HUMAN sets `approved`;
                          # the Build Report then carries the run status (awaiting-apply).
entity: account           # table the step is registered on (may differ from the table it writes)
# Multi-step plugin: a `steps:` list instead of the scalar fields, e.g.
#   steps:
#     - {message: Create, stage: PreOperation, mode: Synchronous, filter: [name], handler: OnExecute, images: []}
#     - {message: Update, stage: PreOperation, mode: Synchronous, filter: [description], handler: HandleUpdate,
#        images: [{pre: [accountnumber]}]}
message: Create
stage: PreOperation
mode: Synchronous
filtering_attributes: [Name]   # model property names (as FilterOn / --filtering-attributes take them)
images: []                # e.g. [{pre: [statecode]}, {post: [statecode, parentcustomerid]}]
# A Custom API replaces message/stage/mode/filtering_attributes/images with:
#   custom_api: {unique_name: <pfx>_<Name>, binding: global | bound:<entity>, kind: action | function,
#                callers: [flows | code | web-api], inputs: [email:string!], outputs: [leadScore:int]}
reuse: new-plugin         # new-plugin | add-step:<PluginName> | reuse:<name>
service: none             # none | new:<Name> | reuse:<Name>
solution: <uniquename>    # existing unmanaged solution; passed to plan/apply --solution
publisher_prefix: <pfx>   # from `vela solution show <uniquename> --json`; = scaffold --publisher-prefix
namespace_prefix: Zava    # scaffold --prefix (PascalCase namespace, not the publisher prefix)
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
<story verbatim + acceptance cases as Definition of Done>

## E - Entities
<entities and attributes read/written, e.g. account.description (read + write)>

## A - Approach
<stage, Sync vs Async and WHY (registration-rules); reuse vs new and WHY>

## S - Structure
<project, `vela add plugin` vs `vela add step`, new or reused service>

## O - Operations
<the RegisterStep() chain, the handler outline, the test cases (= acceptance cases)>

## N - Norms
<naming (generated conventions + prefix), thin handler/SRP, reuse over duplication>

## Hand-off (only when status: blocked)
<the blocker, its evidence, what would unblock it, open questions. Nothing is scaffolded or packaged.>

## S - Safeguards
<registration legality (registration-rules), applicable gotchas, no secrets in code, stop before apply>
```

## Build Report (deploy gate - the Canvas grown, with evidence)

Keeps every Canvas front-matter key and adds the build keys below; only `kind` changes.

```markdown
---
kind: vela-build
date: 2026-09-25
slug: account-default-description
status: awaiting-apply    # awaiting-apply | applied
entity: account
message: Create
vela_cli: 0.25.0
framework: 0.34.0
packages: [Zava.Plugins.1.0.0.nupkg]   # every previewed package (+ Zava.Integrations.<ver>.nupkg for an outbound call)
package_sha256: <sha256 of the previewed package>   # one per package
signed: no                # yes | no (a human signs before apply) | n/a (not required) | unknown (asked at the gate)
harness: pass             # pass | fail  (must be pass)
analyzers: clean          # clean | violations  (authored code)
review: pass              # pass | block  (no unresolved Critical/Required)
plan_preview: changes     # changes (exit 8 with --detailed-exitcode) | clean (exit 0) | unavailable (record the command + exit)
plan_command: "vela plan -p artifacts/Zava.Plugins.1.0.0.nupkg --solution ZavaSales --url <org> --detailed-exitcode --out plan.json"
apply: pending
---

## Canvas
<the approved Canvas carried forward; mid-build updates under "Sync log">

## What was built
- Commands run; components created / models generated; handler summary

## Evidence
- `dotnet build`: <0 errors, 0 VELA00x in authored code>
- Acceptance cases (RED→green): [x] empty→defaulted  [x] whitespace→defaulted  [x] non-empty→untouched
- Harness: <runner summary + runner name>
- Code review: <PASS / BLOCK; findings most-severe first>
- Solution: `vela solution show <uniquename> --json` → `{"solution": ..., "publisherPrefix": ...}` (exit 0)
- Package: <path> · sha256 <hash> · signed <yes/no/n/a/unknown>
- `vela plan --solution <uniquename>` (on that package, after review): <the `operations` apply WOULD run,
  every `diagnostics` line, the exit code; or "unavailable" with the exact command and exit code>

## Sync log
<Canvas changes made during the build (requirement change → Canvas first; refactor → synced back)>

## Run trace
One row per step, appended as you go; the input for `diagnosing-vela`. Every value is copied from the
tool's output - `exit` is the real code, `-` when nothing ran. Never estimate a value you did not observe.

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
`vela apply -p <pkg> --solution <uniquename> <the plan's connection, e.g. --url https://<org>> [--secure-config <Name>=@<file>]` - this will: <exact changes from the plan's `operations`>.
A secure-config value the agent does not hold is an **open question** (who supplies it, how); the plan's
"expects the secure configuration" diagnostic stays as evidence - never a placeholder. Exit `7` = partial
apply (fix, re-run); `5` = not converged - both reported, never "done".

## Open questions
<anything the human must decide>
```
