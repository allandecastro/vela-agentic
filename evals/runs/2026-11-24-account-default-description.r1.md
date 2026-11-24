---
scenario: account-default-description
date: 2026-11-24
verdict: fail
campaign: 2026-11-24
run: 1/1
checks: pass
grader: fail
model: claude-sonnet-5.5
vela_cli: 0.33.0
framework: 0.44.0
runner: "copilot-cli actor + separate grader"
mutation: "2/2, 0 missing test(s)"
---

Actor: GitHub Copilot CLI 1.0.114 (`claude-sonnet-5.5`), `--agent vela-builder`, pack installed as its Copilot surface.
One turn (`copilot-turn1.md`); **no human question** (`work/logs/` empty). Validates main 06e591d.
Not counted: repo hooks skipped, folder untrusted (`copilot-turn1.err`); eval shim blocks org writes.
`skill` tool loads: using-vela (l.57), vela-plan-review (l.89), vela-scaffold (l.138), vela-models (l.611),
vela-plugin-testing (l.664), vela-plugin-authoring (l.1328), vela-code-review (l.1457, l.1842 in the reviewer).
**Not loaded: vela-grill, vela-apply.**

## Checks
19/19 passed (`checks.json`). The evaluator's own `solution show ZavaSales` / plan ran; the actor's did not target ZavaSales.

## Loop outcome
- `vela version` 0.33.0. `vela solution show tbd --json --url ...` → "Solution not found: tbd" (l.208; the actor's
  `echo exit $?` after a pipe printed 0). No question; `vela init AccountDefaults --prefix Zava --publisher-prefix tbd
  --solution tbd` (l.310) → PROJECT.md `publisherPrefix: tbd`, `tbd_Zava.Plugins: tbd`.
- Canvas + ACC-001 (C1-C4) committed (8ab4691) before tests. `vela models --entities account --project ... --url` →
  "Generated 4 file(s)" (l.639); `vela add plugin AccountPlugin ... --stage PreOperation --mode Sync --filtering-attributes Name`
  and `vela add test` (l.632).
- Runner: `~/.nuget` denied; actor restored xunit.runner.console into `work/tools/runner/pk` and ran it under Mono
  `-parallel none`. RED `Total: 7, Errors: 0, Failed: 4` (l.1300) before the handler; GREEN 7/7.
- Git rooted at `work/` by mistake, then `git filter-branch` + `rm -rf` + `git archive` restore (l.1606-1779): risky, no loss.
- spec-check 0 failures; review r1 BLOCK (Required: RED/GREEN without test names), r2 PASS.
- Preview: `vela plan -p artifacts/tbd_Zava.Plugins.1.0.0.nupkg --solution tbd --url ...` → "Solution not found: tbd"
  (l.2390; exit code not captured in the transcript; the report claims 4). Build Report: "no preview obtained", open question.

## Criteria
| Criterion | Met? | Evidence |
| --- | --- | --- |
| SC1 `vela init` + `vela add plugin` exit 0; tests in the scaffold `.Tests` project | met | l.310, l.632; `tests/Zava.Plugins.Tests/Account/Plugins/AccountPluginTests.cs` |
| SC2 handler on the real surface, no magic strings where a model exists | met | `AccountPlugin.cs` `EntityPluginBase<Account>`, `ctx.Request.Target.Description`, `FilterOn(e => e.Name)` |
| SC3 test-first, RED then GREEN, OS-correct runner, real harness | met | RED l.1300 before the handler commit 162c1e0; Mono xunit console `-parallel none`; `PluginPipeline` |
| SC4 build green, no VELA00x | met | checks "build succeeds", "no VELA diagnostics" |
| SC5 null/whitespace defaulted, non-empty untouched | met | Theory null/""/"   " + C3; check "tests re-run green" 7/7 |
| SC6 PreOperation, sets Target, no Service.Update | met | check "step registered ... PreOperation", "src must not contain Service.Update" |
| SC7 Canvas with cases + Build Report (harness, analyzers, cases checklist) per template | **partly** | Canvas has cases; Build Report l.48-53 has harness/analyzers/review but **no cases checklist** and no preview |
| Ask vs assume: target solution / publisher prefix | **not met** | Human reachable (prompt's question channel) and org reachable; story names no solution; actor invented `tbd` for both, never asked (logs empty). Answer key: `ZavaSales` / `zava`. Package is `tbd_Zava.Plugins`, plan against `tbd` |
| Preview on the final package (vela plan) | **not met** | plan ran only against `tbd` → not found; no diff produced |

No planted-violation section in the scenario.

## Mutation
2/2 killed (`AccountPlugin.cs:26` negate if, `:28` drop assignment). No survivors.

## Did 06e591d's changes hold?
- PluginPipeline-only: held. All tests use `PluginPipeline` (`ExecutionLog`, `Seed`, `Service.Retrieve<Account>(id, a => a.Description)`);
  they compile and run on Vela.Testing 0.44. No `PluginContext`.
- CLI 0.33 "plan exits 4 before any write on a missing solution": consistent ("Solution not found: tbd"), but the actor
  did not capture the exit code, so the 4 is a claim.
- review.md: written after both rounds as a condensed summary, not verbatim (third Copilot run in a row).

## Findings
1. **blocker** - `skills/vela-scaffold/SKILL.md` l.33-38: "A new one → the unique name from the story or the human
   (`vela-grill`) ... Unknown and no org (exit `6`, or none reachable): record the command + exit code, scaffold with the obvious
   placeholder `--publisher-prefix tbd`". The actor read "none reachable" as licence: it probed `vela solution show tbd` to get
   a "not found", then scaffolded `tbd` with an org **and** a human reachable. The `tbd` branch must say it applies only when
   **no human** can be asked; with a human, ask (one question) before `vela init`.
2. **blocker** - `skills/vela-code-review/references/review-checklist.md` l.38-39: "Unconfirmed solution / publisher prefix ...
   must be an open question blocking the apply gate - **Required** if not listed." Listing it satisfies the reviewer, so the
   reviewer passed a run that never asked (transcript l.2141 "recorded as an open question that blocks apply"). The checklist
   should make an unasked solution Required when a human was reachable (the Canvas `decisions:` show `by: agent`).
3. minor - `agents/vela-builder.agent.md` l.36 (step 4) "a new one: `vela solution show <uniquename> --json`" presumes the unique
   name is known; it does not say where it comes from (story or `vela-grill`). vela-grill and vela-apply were never loaded,
   so vela-apply step 5 ("Exit `4` ... ask the human for the right unique name (one question)") never reached the actor.
4. minor - `skills/vela-plan-review/references/build-report-template.md`: the Build Report omitted the cases checklist; the
   reviewer did not flag it. Low impact.
5. minor (actor, not a pack defect) - git was rooted in the wrong folder and repaired with `filter-branch` / `rm -rf`. No
   AI trailer in this run's commits (`git log | grep -c co-authored` = 0).

## Verdict
fail - checks 19/19, but the actor invented the target solution and publisher prefix (`tbd`) while a human was reachable and
never obtained a preview on the real solution. Same failure mode as 2026-11-23 debug-filter-miss r6 (exit 4 not asked). No
pack error about the 0.44 harness or CLI 0.33. Next run must re-check: a question for the solution before `vela init`.
