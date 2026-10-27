# Vela Canvas (plan) & Build Report templates

The **Vela Canvas** is a REASONS-style spec adapted to Dataverse plugins (from Thoughtworks' SPDD): the
single artifact the reviewer reasons about, and the home of the decisions the tooling does not make
(Sync/Async, reuse-vs-new, services, naming, safeguards). It grows into the **Build Report**. Both are
Markdown + YAML front-matter, reused as the PR body. Keep it **proportional**: one line per section is fine
for a simple story.

**One folder per story:** `docs/features/<slug>/README.md` is the Canvas that becomes the Build Report (`kind:
canvas` → `kind: feature`) - a short, durable record: decisions, cases, evidence lines, gate. The run's working
material stays **untracked** in `.vela-runs/<slug>/` (add `/.vela-runs/` to `.gitignore`): `trace.md` (the Run
trace), `review.md` (the reviewer's output, verbatim) and `plan.json` (`vela plan --out`); the PR body carries
the README plus the review and trace. Before a project exists, write the README at that path under the working directory;
after `vela init`, at the same relative path inside the project. Never another path or name. A
new story on an existing plugin gets its **own** slug and file, referencing the plugin.

**Living spec (fix-spec-first):** a requirement change updates the Canvas **before** the code; a
behaviour-neutral refactor updates the code, then is **synced** back into the Canvas.

**Rules registry:** the Build Report is the history of one change; `docs/rules/<table>.md` is the current set of
business rules on a table (template at the end). The Canvas names the rules the story adds, changes or retires
(`rules:`). The registry is the **functional spec of the tests**: each rule's cases carry an id (`ACC-002/C1`)
and each test carries it (`[Trait("Case", "ACC-002/C1")]`). It is written in the **design** phase and is
**read-only during the build** (`tools/spec-check.cs` checks it at review) - except a rule's trace lines
(`Implementation:` / `Tests:`), synced to the code like the Canvas, and a **review-driven amendment** (a new case
id, a corrected sentence) listed in the Canvas `amendments:` and recorded in the Sync log with its finding.
**Architecture decisions** are **ADRs**, one file each in `docs/adr/NNNN-<title>.md` (template at the end): a
choice that outlives the story, shapes structure, security, integration or data, and is costly to reverse -
the execution security context, an external provider and its failure policy (timeout, retry, what the user
sees), where data migration lives, a caching strategy, plugin vs Custom API vs flow. Written in the design phase
in the commit of the story that raises it (or by the dispatcher before parallel builds), read before planning,
cited by the Canvas (`{by: adr, what: "0001 - ..."}`), never re-asked. **Not an ADR:** a business rule
(`docs/rules/`, even when several rules share it), a choice local to the story (Canvas `decisions:`), a pack
convention (naming, documentation), a machine value (publisher prefix, solution - Vela's).

**Lifecycle = git.** Rules and ADRs carry no `proposed` / `active` / `accepted` status: on a branch or in a PR
they are proposed, merged on the base branch they are in force (the human merges - that is the approval).
A replaced rule is deleted with its tests, a replaced ADR edited or deleted - git keeps the history. Whether a story is deployed, and
where, is the Build Report's `apply:` and the org itself (`vela inspect`) - never the registry.

## Vela Canvas (front gate - produced by `vela-plan-review`)

```markdown
---
kind: canvas
slug: account-default-description
date: 2026-09-25
status: draft             # draft | blocked (needs-input, undeliverable) | superseded - merging approves it;
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
rules:                    # rules this story adds / changes / retires in docs/rules/<table>.md
  - {id: ACC-001, change: add}            # add | change | retire
supersedes: []            # slugs of earlier stories this one replaces, if any
amendments: []            # rules amended in the build after a review finding (each in the Sync log)
acceptance_cases:         # the rule's cases, by id - each becomes a test carrying [Trait("Case", "<id>")]
  - "ACC-001/C1 Given an account with no Description, When it is created, Then Description = 'Created via Vela plugin'"
  - "ACC-001/C2 Given a whitespace-only Description, When it is created, Then it is defaulted"
  - "ACC-001/C3 Given a non-empty Description, When it is created, Then it is left untouched"
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
kind: feature
date: 2026-09-25
slug: account-default-description
status: awaiting-apply    # awaiting-apply | applied (the human, after apply: date + package_sha256)
entity: account
message: Create
vela_cli: <vela version>
framework: <Vela.Plugins version>
packages: [Zava.Plugins.1.0.0.nupkg]   # every previewed package (+ Zava.Integrations.<ver>.nupkg for an outbound call)
package_sha256: <sha256 of the previewed package>   # one per package
signed: no                # yes | no (a human signs before apply) | n/a (the human said not required) | unknown (asked at the gate) - `vela plan` does not tell
harness: pass             # pass | fail  (must be pass)
analyzers: clean          # clean | violations  (authored code)
review: pass              # pass | block  (no unresolved Critical/Required)
plan_preview: changes     # changes (exit 8 with --detailed-exitcode) | clean (exit 0) | unavailable (record the command + exit)
plan_command: "vela plan -p artifacts/Zava.Plugins.1.0.0.nupkg --solution ZavaSales --url <org> --detailed-exitcode --out .vela-runs/<slug>/plan.json"
apply: pending
---

## Canvas
<the approved Canvas carried forward; mid-build updates under "Sync log">

## What was built
- Commands run; components created / models generated; handler summary

## Evidence
- `dotnet build`: <0 errors, 0 VELA00x in authored code>
- Acceptance cases (RED→green): [x] empty→defaulted  [x] whitespace→defaulted  [x] non-empty→untouched
- Harness: <runner summary + runner name>; RED run: <summary> + the failing test names, each with its case id
- Code review: <PASS / BLOCK; findings most-severe first; the Canvas decisions the reviewer checked (Sync/Async,
  reuse-vs-new, service, ...)> - its output saved verbatim, never paraphrased
- Solution: `vela solution show <uniquename> --json` → `{"solution": ..., "publisherPrefix": ...}` (exit 0)
- Package: <path> · sha256 <hash> · signed <yes/no/n/a/unknown>
- `vela plan --solution <uniquename>` (on that package, after review): <the `operations` apply WOULD run,
  every `diagnostics` line, the exit code; or "unavailable" with the exact command and exit code>

## Sync log
<Canvas changes made during the build (requirement change → Canvas first; refactor → synced back)>

## Run trace (in `.vela-runs/<slug>/trace.md`, not in this README)
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
| 7 | plan | vela-apply | `vela plan -p artifacts/Zava.Plugins.1.0.0.nupkg --solution ZavaSales --url <org> --detailed-exitcode --out .vela-runs/<slug>/plan.json` | 8 | changes: create package + 1 step |

## Gate - human approval required
Run to deploy (after `shasum -a 256 <pkg>` matches `package_sha256`):
`vela apply -p <pkg> --solution <uniquename> <the plan's connection, e.g. --url https://<org>> [--secure-config <Name>=@<file>]` - this will: <exact changes from the plan's `operations`>.
A secure-config value the agent does not hold is an **open question** (who supplies it, how); the plan's
"expects the secure configuration" diagnostic stays as evidence - never a placeholder. Exit `7` = partial
apply (fix, re-run); `5` = not converged - both reported, never "done".

## Blocking decisions (the human must answer before apply - a handful at most)
<business decisions not yet made by the human, most important first; a SYSTEM security context chosen
without the human is one of them>

## Assumptions taken (FYI)
<platform facts and low-impact choices made without the human>

## Rule fixes for the human to approve
<wording or case fixes to `docs/rules/` found during the build and not amended>
```

## Rules registry - `docs/rules/<table>.md` (one file per table, written in English)

One file per table, holding the rules **triggered** on it; a rule that also affects another table gets one
`See also` line in that table's file. Rules are written for the business, in Given / When / Then / Otherwise,
with the technical trace separate. A rule in the file on the base branch is in force; a retired rule is deleted with its
tests (git keeps the history).

```markdown
# Rules - account

### ACC-002 - An account with active contacts cannot be deleted
Since: account-delete-guard (2026-10-17)

Given an account that has at least one active contact (contacts whose parent customer is the account)
When a user deletes the account
Then the delete is refused
  And the message gives the number of active contacts and asks to deactivate or move them first
Otherwise (no active contact, or only inactive ones) the delete goes ahead

Cases (the functional spec of the tests - each test carries its id as [Trait("Case", "<id>")]):
  - ACC-002/C1 Given 2 active contacts, When the account is deleted, Then it is refused with "2 active contacts"
  - ACC-002/C2 Given only inactive contacts, When the account is deleted, Then it is deleted
  - ACC-002/C3 Given an active contact of another account, When the account is deleted, Then it is deleted

Exceptions / assumptions:
  - Contacts the user cannot read are not counted (runs as the user - default security context)
Affects: contact

Implementation: AccountDeleteGuard · Delete · PreValidation · Sync
Tests: AccountDeleteGuardTests

```

In the affected table's file: `See also ACC-002 (account) - deleting an account is blocked while it has active contacts.`

## ADR - `docs/adr/NNNN-<title>.md` (one decision per file, written in English)

A changed decision is edited in place (or the ADR deleted); git keeps the history.

```markdown
# 0001 - Plugins run as the calling user

Date: 2026-10-23 · by: human

## Context
Stories read other tables (contacts of an account); SYSTEM would expose rows the user cannot read.

## Decision
Plugins read and write as the calling user. SYSTEM only when a story justifies it in its Canvas.

## Consequences
Read-denied and write-denied cases are tested. A count may differ from what an admin sees.
```
