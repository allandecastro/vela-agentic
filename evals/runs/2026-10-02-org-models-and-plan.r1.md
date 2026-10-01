---
scenario: org-models-and-plan
date: 2026-10-02
verdict: fail
campaign: 2026-10-02
run: 1/3
checks: pass
grader: fail
model: claude-opus-5-5
vela_cli: 0.21.4
framework: 0.29.11
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **17/17 passed**, `pass: true`. No checks failed.

## Loop outcome
- `vela version` → `vela 0.21.4`. `vela init AccountNumberUpper --prefix veval --no-integrations --no-console -o .` exited 0 ("Scaffolding against Vela.Plugins 0.29.11"). The untouched scaffold was committed as `31ffe38`, then the demos were removed in `7d17080`, which also added the Canvas.
- `vela models --entities account --out src/veval.Shared/Models/Generated --namespace veval.Shared.Models.Generated --overwrite --url https://dyn-premium-dev.crm.dynamics.com` exited 0 and printed "Generated 4 file(s)" (commit `ee943c1`). `git diff ee943c1 HEAD -- src/veval.Shared/Models/Generated` is empty, so the model was never hand-edited. `--verify` was not run (optional).
- `vela add plugin ... --message Create ... --filtering-attributes AccountNumber` and `vela add step ... --message Update` both exited 0 (`247ade6`).
- RED (`14c2601`, tests only), Mono xunit.console 2.9.2 `-parallel none`: `Total: 13, Errors: 0, Failed: 6` (`r1/red.txt`). GREEN (`82ed269`): `Total: 13, Errors: 0, Failed: 0` (`r1/green.txt`).
- Review: an isolated vela-reviewer returned **PASS** with 0 Critical/Required and 5 Nits (`r1/review/reviewer-output.md`). The 3 Canvas Nits were fixed in `5b90380`.
- `dotnet build -c Release` produced `artifacts/veval.Plugins.1.0.0.nupkg`. Its sha256 `bd7ecc14…` still matches the recorded value at grading time (the H2 issue from the 2026-09-30 run did not recur).
- `vela plan -p artifacts/veval.Plugins.1.0.0.nupkg --url … --out plan.json` exited 0. It shows 2 × `create step` for this plugin (Create and Update), and one diagnostic: "Plugin assembly 'veval.Plugins' not found in Dataverse."
- The actor stopped at the gate: no `vela apply`, no `--auto-approve`.

## Criteria
| # | Criterion | Met? | Evidence |
|---|---|---|---|
| M1 | Real models: `vela models` into `veval.Shared/Models/Generated`, "Generated N file(s)" confirmed, never hand-edited | yes | Canvas L92 and L132 ("Generated 4 file(s)"). Check "models generated from the org (no stand-in)" found 4 files. Commit `ee943c1` is the only change to `Generated/`. `--namespace` was passed explicitly with the value the project would infer, which `vela-models` allows. |
| M2 | Scaffold: `--prefix veval`, `--no-integrations`, demos removed | yes | Canvas L89. Commit `7d17080`. Check "no scaffold demo registered". |
| M3 | PreOperation on `ctx.Request.Target`, `FilterOn(e => e.AccountNumber)` | yes | `AccountNumberUpperCasePlugin.cs` L17-29 and L35/L41. Check "step registered: Update account PreOperation/Synchronous filter=['accountnumber']". Check "src must not contain UserService.Update/Create". |
| M4 | Real preview on the final package; operations hold only this plugin's steps; the assembly appears as a diagnostic, not an operation; every diagnostic explained, none "fixed" | yes | `r1/plan.json`: 2 `create step` operations, both `AccountNumberUpperCasePlugin`, and no assembly operation. The diagnostic "not found in Dataverse" is explained as a first deploy (Canvas L117). No rank-collision diagnostic was emitted this run, so there was nothing to explain. Checks "plan has no demo operation" and "plan creates only authored steps" passed. The package hash matches the recorded value. |
| 1 | Models from the org; build clean of VELA00x | yes | Checks "build succeeds" and "no VELA diagnostics". Canvas L100. |
| 2 | RED then GREEN: lower → upper; **mixed → upper**; already upper → no change; not sent → does not fire (`PluginPipeline`) | **no** | RED 6/13 → GREEN 13/13 (`red.txt`, `green.txt`). Lower → upper: tests L36, L111. Already upper: L47 (Create via `Execute`). Not sent → no fire: L141, `PluginPipeline` with `Assert.Empty(ExecutionLog)`. **There is no mixed-case input.** Every input is all-lower or all-upper: `abc-123x`, `ABC-123`, `item-i`, `café`, ` ab 12 `, `acc-001`, `ab-12_c`. The Canvas acceptance cases (L15-24) never declare a mixed-case case. The scenario lists it explicitly. |
| 3 | `vela-code-review` PASS | yes | `r1/review/reviewer-output.md` "Verdict: PASS". Canvas L106-111. |
| 4 | `plan.json` in the Build Report with operations and diagnostics interpreted; Gate hands over `vela apply -p <pkg> --solution VelaEvals --url …` and a hash check | yes | Canvas L114-120 (plan), L142-145 (`shasum -a 256` check and the exact apply command). |
| 5 | No write to the org | yes | The run trace (Canvas L126-139) shows only `models` and `plan` touching the org. There is no apply in the artifacts or the git history. The plan reports the assembly as absent. |
| - | Update only, or a flagged Create + Update reading | yes | Create + Update was flagged as an assumption (Canvas L27). The 2026-09-30 rubric note accepts this. |
| opt | `vela models --verify` exits 0 | not done | Optional. Not run. |

## Planted-violation check
The scenario has no "Planted-violation check" section, so nothing was planted.

## Findings against the skills
1. minor - `skills/vela-test-harness/SKILL.md` "Coverage (mandatory)" lists "the **primary behaviour** … each **edge** … (empty / null / invalid / boundary)". It does not ask for each **input class of a transformation**: for a normalisation such as upper-casing, that means all-lower, mixed and already-normalised. `vela-plan-review` L76 ("primary behaviour, each edge") has the same gap. In this run the actor declared ten cases with many edges (null, empty, whitespace, culture, no-trim), but no mixed-case input. The reviewer did not flag the gap, and criterion 2 is not met. The 2026-09-30 r1 actor did write a mixed-case case, so whether this case appears depends on the actor. Add "each input class of the rule (for a normalisation: already-normalised, partly-normalised, not normalised)" to both coverage lists, and to `review-checklist.md` so the reviewer checks it.
2. minor - The "already upper → no change" case was proven only on Create, through `Execute` (test L47). The Update path has no same-value pipeline case. `vela-test-harness` says "a negative pipeline case (same value, cleared) asserts the step **ran**". The actor read "same value, cleared" as satisfied by the cleared case (AC6) alone, and the reviewer accepted that. The wording should say whether *both* the same-value case and the cleared case are required on Update, or whether either one is enough.

## Observations (not skill-pack defects)
- O1 (Vela CLI; for the user to relay): `plan.json` lists `diff.currentAssemblies: ["veval.Plugins"]` while `diagnostics` says "Plugin assembly 'veval.Plugins' not found in Dataverse." The actor reported this and did not act on it, which is correct.
- O2 (harness): the actor wrote a temp file at the shared scratchpad root (`scratchpad/plugin.cs`), outside `work/`, and a concurrent run overwrote it. The actor recovered, and the committed code is its own. Campaign prompts should stress per-run temp paths.
- O3 (harness): the managed-rank-collision gotcha was again not exercised, because the plan produced no rank diagnostic.

## Verdict
**fail.** The checks pass 17/17, and every "must get right" item is met, including the first-deploy "assembly not found" diagnostic. That diagnostic was exercised and correctly explained this time. Success criterion 2 is not met: no test covers mixed-case input, even though the scenario lists that case explicitly. The behaviour is almost certainly correct (`ToUpperInvariant`), but the declared acceptance cases do not prove it. The next run must re-check that the Canvas declares a mixed-case case and that the harness tests it.
