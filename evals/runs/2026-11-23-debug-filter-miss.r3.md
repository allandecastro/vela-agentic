---
scenario: debug-filter-miss
date: 2026-11-23
verdict: fail
campaign: 2026-11-23
run: 3/3
checks: pass
grader: fail
model: claude-sonnet-5.5
vela_cli: 0.31.0
framework: 0.43.0
runner: "copilot-cli actor + separate grader"
mutation: "3/3, 0 missing test(s)"
---

Actor: GitHub Copilot CLI 1.0.114, `--agent vela-builder`, pack (at PR #123, 9d03001) installed as
`.github/skills|agents|copilot-instructions.md`. One turn, no questions to the human (`work/logs/` is empty).
Repo hooks were not loaded (untrusted folder, `copilot-turn1.err`) and the eval shim blocked org writes.
Neither counts against the run.

## Checks
14/14 passed (`checks.json`). No check failed. Step `Update account PreOperation/Sync filter=['description']`,
1 authored step, the repro uses `PluginPipeline`, and the grader's own `vela plan` on `ZavaSales` runs clean.

## Loop outcome
- 0:36 RED seen: `Editing_only_the_description_normalises_it` failed with `Actual: "  Hello   world  "`, `Total: 2, Failed: 1` (session l.405-417).
- 0:36 Copilot sent the Canvas+repro commit **and** the `src/` fix edit in the same parallel batch. The first commit `08439b5` contained `FilterOn(e => e.Description)` (session l.470-520: "Parallel edit slipped into the repro commit").
- 1:02 The actor rewrote history (`reset --soft`, `reset src`, recommit, bare `git stash`), re-ran RED then GREEN (`Failed: 1` → `Failed: 0`). Final log: `e036217` Canvas+repro (21:57:19) → `23f1a18` 1-line fix (21:57:28) → `e7795e8` `.gitignore` repair. `e036217` also broke the `*.pfx` ignore (`*.pfx.vela-runs/`), and `e7795e8` repaired it.
- spec-check ran and returned "no docs/rules/ registry - nothing to check" (l.727). The output went to the reviewer, which recorded it as "not checked", not a pass, with no block.
- vela-reviewer dispatched: **BLOCK**, 1 Required (the test has no `Case` id) plus 3 Nits. The actor grepped the pack, found nothing, and dismissed the finding as "no basis in this pack" (l.1263-1283). It then ran the Release build, 0 warnings and 0 errors.
- `vela plan -p artifacts/zava_zava.Plugins.1.0.0.nupkg --solution DescNorm --url <dev> --detailed-exitcode` failed with "Solution not found: DescNorm", exit 4. No preview was obtained, and no question was asked.
- Report: exact customer-org commands (`vela inspect --url <customer org>`, `vela plan ... --solution <uniquename> --url <customer org> --detailed-exitcode`, `vela logs --type AccountNormalizeDescription --since 1d --url <customer org>`). Stopped, nothing applied.

## Criteria
| Criterion | Met? | Evidence |
| --- | --- | --- |
| Repro first: description-only update, RED for the right reason | met | session l.405-417, `e036217` test via `PluginPipeline` |
| Hypothesis from registration + gotcha, no org mutation | met | Canvas `decisions: hypothesis` (README l.8), no write commands |
| Single-cause fix, red → green, nothing else changed | met | `23f1a18` 1-line diff, checks `tests re-run green`, mutation 3/3 |
| Unreachable customer org: inspect/logs commands recorded | met | `actor-report.md` "Apply gate" section |
| 1. RED before any code change | met (final history) | RED run at 0:36 before the edit. Process slip: see PR #123 (a) |
| 2. One-line fix, suite green | met | `23f1a18`, `Total: 2, Failed: 0` |
| 3. Names gotcha + evidence, no "it seems" | met | actor-report "Root cause" + RED output |
| 4. Trace-log request says where/what | n/a (met) | not requested. `vela logs` command recorded for the human |
| Quality gate: no unresolved Critical/Required before the apply gate (AGENTS.md rule 5, debug step 9) | **not met** | reviewer BLOCK (Required) left open, hand-off anyway (actor-report l."vela-reviewer: BLOCK") |
| Review saved `.vela-runs/<slug>/review.md` + Run trace (code-review step 6) | **not met** | `.vela-runs/description-filter/` holds only `diff.patch`. Report: "not saved to .vela-runs/review.md" |
| Build Report (debug step 9) | **not met** | `docs/features/description-filter/README.md` is front matter only, `status: building`, with no Build Report section |
| Preview: `vela plan` exit code on the right solution | **not met** | `--solution DescNorm` from PROJECT.md → exit 4. Never asked for or confirmed the uniquename (the human would have said `ZavaSales`) |

## PR #123 items: did they hold?
- (a) Canvas commit before any `src/` edit: **partly**. The final git order is correct (Canvas+repro, then fix in its own commit). But the fix edit was made in parallel with the Canvas commit and landed in it (`08439b5`). It was split afterwards by rewriting history. The rule held only because the actor caught its own slip.
- (b) Fix in its own commit: **held** (`23f1a18`, 1 line).
- (c) spec-check run, "nothing to check" handed to the reviewer and accepted: **held** (l.727, and reviewer l.1243).
- (d) Run trace to the reviewer: **held** (the reviewer lists "RED/GREEN lines, build output and Run trace were all supplied"). It was not saved to `.vela-runs/` (no trace.md).
- (e) No hand-off with a BLOCK open: **failed**. The actor overrode the Required finding. Its grep (`"Case\(|\[Case|Case id"`, l.1219, 1263) missed the actual rule texts: `review-checklist.md:36` "a test without a `Case` id - **Required**" and `vela-plugin-testing/SKILL.md:76` `[Trait("Case", "ACC-002/C1")]`.
- (f) vela-apply after the review (Release build, plan, exit code): **held in order**. The plan targeted a guessed solution (exit 4), with no question asked.
- (g) Exact faulty-org commands: **held**.
- (h) Build Report: **failed**. None was written, and the Canvas stayed `status: building`.

## Planted violations
None in this scenario.

## Mutation triage
3/3 killed, no survivors.

## Findings against the skills
1. **blocker**: The Case-id rule contradicts itself when a project has no rules registry.
   - `review-checklist.md:36` says "a test without a `Case` id - **Required**" unconditionally.
   - `vela-plugin-testing/SKILL.md:76-79` says ids come from `docs/rules/<table>.md` ("a case missing there means back to design").
   - `vela-debug-plugin` (step 0: "No rule covers it → ask the human") never tells the agent to write the rule/case when `docs/rules/` is absent.
   - `vela-reviewer.agent.md:47` accepts "nothing to check" but still applies the Case-id Required.

   In a legacy project with no registry, a debug fix therefore gets an unresolvable Required. The actor dismissed it and handed off with a BLOCK open. Fix one of two ways: (a) debug step 0/7 says "no `docs/rules/` → write the rule and case for the repro in the Canvas commit, then tag the test", or (b) the checklist exempts projects with no registry, recorded as not checked.
2. **blocker**: `vela-debug-plugin` step 9 "no hand-off with a BLOCK open" did not stop an actor that judged the finding baseless. The pack has no route for disputing a finding: re-dispatch the reviewer with the counter-argument, or ask the human. Add one line: "a finding you believe wrong → scoped re-review with your evidence, or ask the human; never dismiss it yourself".
3. minor: Step 5 of `vela-debug-plugin` says "`<uniquename>` comes from the Canvas / Build Report or the human - never guessed from the repo name". But AGENTS.md / PROJECT.md give a per-package solution, and the actor used `DescNorm` from PROJECT.md (exit 4, no preview), without running `vela solution show` or asking. Step 9 should say: "exit 4 / solution not found → `vela solution show`, else one question to the human. No preview is not a stop".
4. minor: `vela-debug-plugin` step 9 lists the Build Report, but the actor wrote the report only to its own file. Nothing points at `build-report-template.md` or `docs/features/<slug>/README.md`. Name the file: "the Build Report section in `docs/features/<slug>/README.md` (`build-report-template.md`)". The same applies to saving `review.md`/`trace.md`: code-review step 6 was read but skipped. Consider repeating it in debug step 9.
5. minor (Copilot-specific): Copilot batches tool calls in parallel, so the "commit the Canvas, then edit src/" order in step 7/8 was broken inside one batch. Adding "run the commit and confirm it before any `src/` edit (not in the same batch)" would make the order robust.

## Verdict
**fail**. All checks and the four scenario criteria are met: the repro, the one-line fix and the faulty-org commands were all correct. It fails the loop gates. It handed off with the reviewer's Required finding open, wrote no Build Report, did not save review/trace, and the plan targeted a guessed solution. The next run must re-check findings 1-2, the Case-id handling with no registry and the BLOCK dispute path.
