---
kind: feature
slug: account-default-description
date: 2026-10-17
status: awaiting-apply
entity: account
message: Create
stage: PreOperation
mode: Synchronous
filtering_attributes: [Name]
images: []
reuse: new-plugin
service: none
solution: ZavaSales      # human (Q2); confirmed by `vela solution show ZavaSales --json` (exit 0)
publisher_prefix: zava    # `vela solution show` -> {"solution":"ZavaSales","publisherPrefix":"zava"}
namespace_prefix: Zava
acceptance_cases:
  - "AC1 null Description (not sent) on Create -> 'Created via Vela plugin'"
  - "AC2 empty-string Description on Create -> 'Created via Vela plugin'"
  - "AC3 whitespace-only Description on Create -> 'Created via Vela plugin'"
  - "AC4 non-empty Description on Create -> left untouched (incl. text with surrounding spaces, not trimmed)"
  - "AC5 pipeline: a create with Name fires the step once (PreOperation, Sync) and the saved row carries the default; no extra write"
  - "AC6 pipeline: a create without Name does not fire (FilterOn gates Create) - documents the residual risk"
decisions:
  - {by: human, what: "'empty' means null, \"\" or whitespace-only (Q1 answer b)"}
  - {by: human, what: "target solution ZavaSales (publisher prefix zava) (Q2)"}
assumptions:
  - "Create PreOperation edits of ctx.Request.Target are persisted with the record (one write, no extra Update)."
  - "FilterOn gates Create too; filter on Name (application-required, sent by every UI create). A create sending no name does not fire the step - residual risk."
  - "No security elevation: the plugin only edits the Target (no service call)."
open_questions:
  - "Signing: does dyn-premium-dev require signed plugin packages? The package is unsigned (no certificate held); if required, a human runs `vela sign` and re-runs `vela plan` before apply."
skills: [vela-plan-review, vela-grill, vela-scaffold, vela-models, vela-test-harness, vela-plugin-authoring, vela-code-review, vela-apply]
vela_cli: 0.26.2
framework: 0.37.0
packages: [Zava.Plugins.1.0.0.nupkg]
package_sha256: 6dad429970b4550f26fe1bb58c06fa708973884c9e85a2526013bf13c3ec5021
signed: unknown
harness: pass
analyzers: clean
review: pass
plan_preview: changes
plan_command: "vela plan -p artifacts/Zava.Plugins.1.0.0.nupkg --solution ZavaSales --url https://dyn-premium-dev.crm.dynamics.com --detailed-exitcode --out ../logs/plan.json"
apply: pending
---

## Canvas

### R - Requirements & DoD
"When an Account is created, if its Description is empty, set it to 'Created via Vela plugin'." DoD = the acceptance cases above, green in the harness.

### E - Entities
account.description (read + write on the Target); account.name (filter only).

### A - Approach
Create, PreOperation, Synchronous: defaulting a column of the record being created -> set on ctx.Request.Target (no second write, no recursion). Sync because the value must be on the record when the create returns. New plugin (no project/plugin exists).

### S - Structure
New minimal Vela solution; `vela add plugin AccountDefaultDescription --entity Account --message Create --stage PreOperation --mode Sync --filtering-attributes name`. No service (one-line rule) - a private constant + guard in the handler.

### O - Operations
`RegisterStep().OnCreate().PreOperation().FilterOn(Name)`; handler: if Description is empty -> Target.Description = constant. Tests = acceptance cases + a PluginPipeline case (fires on create with name).

### N - Norms
Generated naming; namespace prefix PascalCase; thin handler; no service ceremony.

### S - Safeguards
Legal: Create/PreOp/Sync, no images. No recursion (Target edit in PreOp). No org writes from the plugin, runs as the step's user (no service call at all). No secrets. Stop before apply.

## What was built
- `vela init ZavaSales --prefix Zava --publisher-prefix zava` (minimal: Zava.Shared, Zava.Plugins, Zava.Plugins.Tests).
- `vela models --entities account` -> `src/Zava.Shared/Models/Generated/Account.cs` (+3 attribute files).
- `vela add plugin AccountDefaultDescription --entity Account --message Create --stage PreOperation --mode Sync --filtering-attributes name`
  -> `src/Zava.Plugins/Account/Plugins/AccountDefaultDescription.cs`: `OnCreate().PreOperation().Sync().FilterOn(e => e.Name)`;
  `OnExecute` sets `ctx.Request.Target.Description = "Created via Vela plugin"` when `string.IsNullOrWhiteSpace(Description)`.
- `vela add test` -> `tests/Zava.Plugins.Tests/Account/Plugins/AccountDefaultDescriptionTests.cs` (10 tests, AC1-AC6).

## Evidence
- `dotnet build ZavaSales.sln -c Release`: `0 Warning(s)`, `0 Error(s)`; 0 VELA diagnostics.
- Acceptance cases (RED -> green): [x] AC1 null -> defaulted  [x] AC2 "" -> defaulted  [x] AC3 whitespace (3 variants) -> defaulted
  [x] AC4 non-empty (2 variants, not trimmed) -> untouched  [x] AC5 pipeline fires once Create/PreOperation/Sync, saved with default (+ negative: runs, keeps value)
  [x] AC6 pipeline: no Name -> does not fire.
- Harness (Mono + xunit.console 2.9.2, `-parallel none`):
  RED `Total: 10, Errors: 0, Failed: 6, Skipped: 0` (6 behaviour cases: Expected "Created via Vela plugin", Actual null; 4 guard cases pass by design);
  GREEN `Total: 10, Errors: 0, Failed: 0, Skipped: 0` (re-run on the final Release build: same).
- Code review (fresh `vela-reviewer` subagent): **PASS**, no Critical/Required; 3 Nits (left open, optional):
  1. Nit - AccountDefaultDescription.cs:36 - trace logs `ctx.PrimaryEntityId`, often `Guid.Empty` on Create PreOperation.
  2. Nit - AccountDefaultDescription.cs:3 / tests:5 - unused `using Vela.Constants;` / `using System.Linq;`.
  3. Nit - Canvas `status: proposed` - addressed by this Build Report (`awaiting-apply`).
- Solution: `vela solution show ZavaSales --json --url https://dyn-premium-dev.crm.dynamics.com` -> `{"solution":"ZavaSales","publisherPrefix":"zava"}` (exit 0).
- Package: `artifacts/Zava.Plugins.1.0.0.nupkg` (contains `lib/net48/Zava.Plugins.dll`) - sha256 `6dad429970b4550f26fe1bb58c06fa708973884c9e85a2526013bf13c3ec5021` - signed: unknown (unsigned).
- `vela plan` (exit 8 = changes pending): operations
  - `create package zava_Zava.Plugins` - "Plugin package is not in Dataverse; apply will create it."
  - `create step Zava.Plugins.Account.Plugins.AccountDefaultDescription` - stage 20 (PreOperation), mode 0 (Sync), filteringAttributes [name].
  - diagnostics: none; info: "Plugin assembly 'Zava.Plugins' not found in Dataverse (first deployment)." (expected).

## Sync log
- Q1/Q2 answered by the human before scaffold; Canvas updated before any code. No requirement change during the build.

## Run trace
| # | step | skill | command | exit | verdict |
|---|------|-------|---------|------|---------|
| 1 | challenge | vela-plan-review, vela-grill | Q1 'empty' -> human: null, "" or whitespace; Q2 solution -> human: ZavaSales | - | Canvas filled |
| 2 | scaffold | vela-scaffold | `vela solution show ZavaSales --json --url https://dyn-premium-dev.crm.dynamics.com` | 0 | {"solution":"ZavaSales","publisherPrefix":"zava"} |
| 3 | scaffold | vela-scaffold | `vela init ZavaSales --output <work> --prefix Zava --publisher-prefix zava` | 0 | Created ZavaSales (9 files), Vela.Plugins 0.37.0 |
| 4 | model | vela-models | `vela models --entities account --project src/Zava.Shared/Zava.Shared.csproj --overwrite --url https://dyn-premium-dev.crm.dynamics.com` | 0 | Generated 4 file(s) |
| 5 | scaffold | vela-scaffold | `vela add plugin AccountDefaultDescription --entity Account --message Create --stage PreOperation --mode Sync --filtering-attributes name --project src/Zava.Plugins/Zava.Plugins.csproj` | 0 | Created plugin (name -> Name) |
| 6 | build | vela-scaffold | `dotnet build ZavaSales.sln -c Release` | 0 | 0 errors, 0 warnings |
| 7 | test-red | vela-test-harness | `vela add test AccountDefaultDescription --kind plugin --entity Account --message Create`; `mono .../xunit.console.exe .../Zava.Plugins.Tests.dll -parallel none` | 1 | RED 6 fail / 10 (4 guard cases pass) |
| 8 | verify | vela-test-harness | `dotnet build ZavaSales.sln -c Release`; `mono .../xunit.console.exe ... -parallel none` | 0 | GREEN 10/10, 0 warnings, 0 VELA |
| 9 | review | vela-code-review | fresh `vela-reviewer` subagent | - | PASS, 3 Nits |
| 10 | package | vela-apply | `rm -rf artifacts; dotnet build ZavaSales.sln -c Release` (-> `artifacts/Zava.Plugins.1.0.0.nupkg`, dll checked) | 0 | ok, sha256 6dad4299...5021 |
| 11 | verify | vela-test-harness | `mono .../xunit.console.exe ... -parallel none` (final build, no rebuild) | 0 | GREEN 10/10 |
| 12 | plan | vela-apply | `vela plan -p artifacts/Zava.Plugins.1.0.0.nupkg --solution ZavaSales --url https://dyn-premium-dev.crm.dynamics.com --detailed-exitcode --out ../logs/plan.json` | 8 | changes: create package + 1 step, 0 diagnostics |

## Gate - human approval required
Not applied. After confirming `shasum -a 256 artifacts/Zava.Plugins.1.0.0.nupkg` = `6dad429970b4550f26fe1bb58c06fa708973884c9e85a2526013bf13c3ec5021`
(and, if the org requires signing, `vela sign` + a fresh `vela plan`), a human runs:

`vela apply -p artifacts/Zava.Plugins.1.0.0.nupkg --solution ZavaSales --url https://dyn-premium-dev.crm.dynamics.com`

This will: create plugin package `zava_Zava.Plugins` and the step `AccountDefaultDescription` (account, Create, PreOperation, Sync, filter `name`), added to solution ZavaSales.
Exit `7` = partial apply (fix, re-run); `5` = not converged - report, never "done". Afterwards: `vela inspect -p <pkg> --solution ZavaSales --url ...` must show no difference.

## Open questions
- Signing requirement of the org (see `open_questions`).
- Residual risk (accepted assumption): an Account created without `name` (possible via API) does not fire the step and keeps an empty Description.
