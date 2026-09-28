---
scenario: org-models-and-plan
date: 2026-09-30
verdict: pass
campaign: 2026-09-30
run: 1/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.21.0
framework: 0.29.7
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **17/17 passed**, `pass: true`. No failed checks.

## Loop outcome
- `vela version` -> `vela 0.21.0`. `vela init VevalAccounts --prefix veval --no-integrations --no-console -o .` exit 0. The untouched scaffold was committed (`69e1529`), then the demos were removed (`888b4c2`).
- Canvas committed (`c7d4b5a`) before the code.
- `vela models --entities account --url https://dyn-premium-dev.crm.dynamics.com --out src/veval.Shared/Models/Generated --namespace veval.Shared.Models.Generated --overwrite` printed "Generated 4 file(s)" and exited 0 (`fb3f127`). The generated files are unchanged from that commit to HEAD.
- `vela add plugin ... --message Create --filtering-attributes Name` and `vela add step ... --message Update` both exited 0. The registration was then set to PreOperation, and the Update placeholder was replaced with `FilterOn(e => e.AccountNumber)`.
- RED: `Total: 10, Failed: 6` (Mono xunit.console, `-parallel none`). GREEN: `10/10`. A mutation check confirmed the culture test: the `ToUpper()` mutant fails it.
- Review #1 returned BLOCK with one Required finding (solution and prefix were not listed as an apply-blocking open question). After the fix, review #2 (fresh reviewer) returned PASS with 0 Critical/Required.
- Package: `artifacts/veval.Plugins.1.0.0.nupkg`, which contains the dll. The actor recorded sha256 `b8fb55aa…`. It is unsigned.
- `vela plan -p ... --url ... --out plan.json` exited 0. Operations: create (Create step) and update (the existing Update step moves onto the new type). `diagnostics: []`. A read-only `vela inspect` found a pre-existing `veval.Plugins` assembly (`AccountNumberUppercasePlugin`) that this run did not create. The actor surfaced it as an apply-blocking open question.
- The actor stopped at the gate. There was no `vela apply` and no `--auto-approve`.

## Criteria
| # | Criterion | Met? | Evidence |
|---|---|---|---|
| S1 | Real models via `vela models`, "Generated N file(s)" confirmed, never hand-edited | yes | Canvas L94/L118 records "Generated 4 file(s)". Check "models generated from the org (no stand-in)" found 4 files. `git diff fb3f127 HEAD -- src/veval.Shared/Models/Generated` is empty. `--namespace` was passed explicitly, with the value the project would have inferred. That is allowed by `vela-models` step 7. |
| S2 | Scaffold: `--prefix veval`, `--no-integrations`, demos removed | yes | Canvas L93. Commit `888b4c2`. Check "no scaffold demo registered". `src/` holds only `veval.Plugins` and `veval.Shared`. |
| S3 | PreOperation on `ctx.Request.Target`, `FilterOn(e => e.AccountNumber)`, writes only when the value differs | yes (see note) | `AccountNumberUpperCasePlugin.cs` L19-24 and L38-44. Check "step registered: Update account PreOperation/Synchronous filter=['accountnumber']". Check "src must not contain UserService.Update/Create". **Note:** the plugin assigns `ToUpperInvariant()` whenever the value is non-null, with no compare. In PreOperation this is a no-op on the in-flight Target, not a write, and the Canvas says so (L81). The reviewer rated a compare as an optional Nit. |
| S4 | `vela plan -p <pkg> --url ... --out plan.json` on the final package; operations contain only this plugin; every diagnostic read and explained | yes | `work/plan.json`: both operations are `AccountNumberUpperCasePlugin`, with no demo operation (checks "plan has no demo operation" and "plan creates only authored steps"). `diagnostics: []` is recorded (Canvas L106). The `update` operation re-points a pre-existing step, and the actor explained it rather than "fixing" it (Canvas L34, Gate L137). The first-deploy "assembly not found" path and the managed-rank-collision path were **not exercised**, because the org already held `veval.Plugins` (see harness note H1). |
| 1 | Models from the org; build clean of VELA00x | yes | Checks "build succeeds" and "no VELA diagnostics". Canvas L100 shows 0 warnings. |
| 2 | RED then GREEN: lower->upper; mixed->upper; already upper->no change; not sent->does not fire (`PluginPipeline`) | yes | Tests L40-50, L65-75 (mixed/lower), L89-98 (already upper), L130-141 (`PluginPipeline`, `Assert.Empty(ExecutionLog)`). RED 6/10 failing -> GREEN 10/10 (Canvas L101). Check "tests re-run green (>= 4)": total=10, failed=0. |
| 3 | `vela-code-review` PASS | yes | Canvas L104: review #1 BLOCK (Required, fixed in `a8609f8`), then fresh review #2 PASS with 0 Critical/Required. The diffs given to the reviewer are in `r1/review/diff*.txt`. |
| 4 | `plan.json` in the Build Report with operations and diagnostics interpreted; Gate hands over `vela apply -p <pkg> --solution VelaEvals --url ...` and a hash check | yes | Canvas L106 (plan), L139 (`shasum -a 256` check), L141 (exact apply command). |
| 5 | No write to the org | yes | Only `models`, `plan` and `inspect` were run (all read-only; run trace L113-132). No apply appears in the artifacts or in the git history. The pre-existing assembly type is spelled `AccountNumberUppercasePlugin` (lower-case "c"), which does not match this run's type. It matches the type from the 2026-09-29 run (`evals/runs/2026-09-29-org-models-and-plan.md` L19), so it predates this run. |
| - | Update-only (asked) or a flagged Create+Update reading | yes | The actor read the story as Create + Update and flagged it as an assumption (Canvas L28). The 2026-09-30 rubric note accepts this. |
| opt | `vela models --verify` exits 0 after generation | not done | Optional. Not run. |

## Planted-violation check
The scenario has no "Planted-violation check" section, so no violations were planted.

## Findings against the skills
1. minor - `skills/vela-apply/SKILL.md` step 5 says: "The JSON's `operations` list is what `apply` would do - it must contain **only** what the Canvas ships (a scaffold demo left in shows up as extra `create` operations)." It gives no guidance for `update`/`delete` operations on registrations the Canvas did not create. In this run, the org already held an assembly with the same name from other work, so `plan` showed `changed: 1`: an existing step moved from `AccountNumberUppercasePlugin` to the new type. `apply` would replace that assembly. The actor ran `vela inspect` on its own initiative and made this an apply-blocking open question. The skill should say that any `update`/`delete` whose `before` side is not in the Canvas is an assembly-name collision the human must resolve, and that it does not count as "clean".
2. minor - Scenario expectation "only writes when the upper-cased value differs". No skill (`vela-plugin-authoring`, `dataverse-gotchas.md`) teaches the compare-before-assign idiom for PreOperation Target normalisation, and `vela-code-review` rated its absence a Nit. The run is correct in behaviour, but the pack and the scenario disagree about whether this is a norm. Either add it to the pack's norms, or drop it from the scenario.
3. observation (Vela framework, not a skill defect) - The Create step must carry a `FilterOn`, which `registration-rules.md` L29 defaults to the primary column. That registers `filteringattributes: ["name"]` on the Create step (`plan.json`). Dataverse ignores it at runtime, but it is noise in the registration metadata. The pack documents the framework requirement correctly. This belongs with the Vela team, not in a skill workaround.

## Harness notes (not skill-pack defects)
- H1 - The dev org is not in its first-deploy state. `veval.Plugins` / `AccountNumberUppercasePlugin` was already registered, so this run did not exercise two gotchas the scenario targets: the "assembly not found in Dataverse" diagnostic and the managed-rank-collision explanation. Reset the org (unregister `veval.Plugins`) before the next run, or have `setup.log` assert the starting state.
- H2 - `evals/checks/check.py` rebuilds with `dotnet build -c Release --no-incremental` in `work/`. That regenerates `artifacts/veval.Plugins.1.0.0.nupkg`, and the file's hash is now `f215842b…` instead of the recorded `b8fb55aa…`. The actor's recorded hash was correct when it was taken (plan at 19:10, check at 19:12). The checker destroys that evidence. Build in a copy, or restore the package afterwards.

## Verdict
**pass**. Checks passed 17/17. Every success criterion and every "must get right" item is met from the artifacts, and there were no planted violations to test. The next run must re-check S4 against a clean org (H1), so that the "assembly not found" diagnostic and the rank-collision explanation are actually exercised.
