---
scenario: feature-multi-rule
date: 2026-11-02
verdict: pass
campaign: 2026-11-02
run: 1/1
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.28.0
framework: 0.41.2
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **20/20 passed**. No check failed.

## Loop outcome
- intake: `vela version` → 0.28.0; `vela solution show ZavaSales --json` → exit 0 (`zava`).
- challenge: two questions to the human (Q1 account https, Q2 contact copy), logged in `work/logs/human-questions.md`
  (trace steps 3-4), before any scaffold (trace step 7).
- model: `vela models --verify` → exit 0. scaffold: `vela add step` x2 (account), `vela add plugin ContactPlugin`,
  `vela add service ContactWebsiteDefault`, `vela add test` - all exit 0.
- RED/GREEN: first done **combined** on one branch (`red.txt`: Total 27, Failed 11); spec-check then failed per story
  (trace 16), history split into stacked branches; per-story RED re-run on the split commits
  (`red-0ef06a3.txt` Total 16 Failed 6; `red-1c46286.txt` Total 27 Failed 5). Review-driven C11 seen RED
  (`red-fix1.txt`); C5/C9 written after code, proven by mutation (`mutation-story2.txt`, Failed 2, reverted).
- review: isolated vela-reviewer round 1 BLOCK (3 Required), round 2 PASS (Nits) - `.vela-runs/websites/review.md`.
- plan: `vela plan -p artifacts/zava_zava.Plugins.1.0.0.nupkg --solution ZavaSales --detailed-exitcode` → exit 8
  (create package + 4 steps; 2 rank-collision diagnostics, handled per review-checklist). No apply.
- grader re-runs (on a clone of the work repo): story 1 branch `dotnet build -c Release` 0 Warning / 0 Error, mono
  xunit Total 17 Failed 0; `spec-check --base main` (story 1) and `--base story/account-website-https` (story 2) both
  `0 failure(s)`. Story 2 tip green 29/29 (checks.json).

## Criteria
| Criterion | Met? | Evidence |
| --- | --- | --- |
| Split, not one story: two Canvases, one new rule each (ACC-, CON-), ids free | met | `docs/features/account-website-https/README.md` (`rules: [{id: ACC-002, change: add}]`), `docs/features/contact-website-from-account/README.md` (CON-001); `docs/rules/account.md` had only ACC-001 on main, `docs/rules/contact.md` new; checks ">= 2 story Canvases", ACC-0xx/CON- regex checks |
| Dependency recorded (built after, or stated in Canvas) | met | `story/contact-website-from-account` is branched from `story/account-website-https` (git graph); CON-001 assumption "ACC-002 already keeps it https". Caveat: its Canvas line 6 says "independent of account-website-https at build time" (see finding 4) |
| Grilled together, questions before any code | met | `logs/human-questions.md` Q1+Q2 (one per entry, options + answer); trace steps 3-4 precede scaffold step 7 |
| No layer split: each story its own RED tests and implementation | met | story 1: `0ef06a3 test(...) RED` → `be3dda4 feat`; story 2: `02048a6 test(...) RED` → `1b96bc4 feat`; no tests-only task. Caveat: first built combined (finding 1) |
| Existing rules untouched | met | `git diff main story/contact-website-from-account -- docs/rules/` only appends ACC-002 and adds contact.md; ACC-001 tests changed only for step-key plumbing, ACC-001 behaviour unchanged |
| spec-check clean on each story | met | grader re-run: both `spec-check: 0 failure(s)` |
| RED then green per story | met | `red-0ef06a3.txt`, `red-1c46286.txt`, `red-fix1.txt`, `green-final.txt` (29/0); story 1 alone 17/0 (grader) |
| Review PASS | met | `review.md` round 2 "Verdict: PASS", no open Critical/Required |
| Plan run, no apply | met | trace 34 exit 8; `.vela-runs/websites/plan.json`; check "read-only vela plan runs"; no apply in trace |

## Planted-violation results
None - this scenario has no "Planted-violation check" section.

## Findings against the skills
1. minor - `skills/using-vela/SKILL.md` (HEAD) said "split it into stories ... grill them together, then build them
   in order or in parallel" without saying where each story lives; the actor built both stories on one branch with one
   combined RED commit (`red.txt`, Failed 11), spec-check then failed on each story with the sibling's rule (trace 16),
   and the per-story history was reconstructed afterwards. The uncommitted working-tree edit ("one branch (and Canvas,
   PR) per story, a dependent story branched from its prerequisite") addresses exactly this - re-check next run that
   the actor branches per story from the start.
2. minor - `tools/spec-check.cs` (HEAD) read `amendments:` only as an inline `[...]` list; the actor's block-list form
   was silently ignored and spec-check failed (trace 27) until rewritten inline. The working-tree regex change (inline
   or block list) fixes it.
3. minor - nothing in the pack says how the gate artifacts split across stacked stories: the actor ran **one** review
   and **one** `vela plan` over the combined package, and story 1's Build Report exists only on the story 2 branch
   (commit ea904e0; on `story/account-website-https` the Canvas is still `status: draft`, no Build Report). Story 1's
   PR therefore cannot carry its own report/plan. `skills/vela-apply/references/build-report-template.md` says "One
   folder per story" but not "each story branch carries its own Build Report (and plan of that branch's package)".
4. minor - the Canvas has no field for a story's prerequisite: the actor invented `feature: "Websites" (story 2 of 2;
   independent of account-website-https at build time)`, which reads as "no dependency" although CON-001 relies on
   ACC-002's stored value. `build-report-template.md` / `vela-plan-review` have no `depends_on:` (or equivalent)
   for the dependency the using-vela split rule asks to record.

Observation (not a skill defect, for the Vela team): two Create PreOperation steps on one plugin forced the actor to
set `Context.OwningExtension` by hand in the ACC-001 tests to pick the handler (`AccountDefaultDescriptionTests.cs`);
the harness may lack a first-class way to select the executing step.

## Fixes
- Findings 1-2: uncommitted edits on branch `fix/feature-split-findings` (`skills/using-vela/SKILL.md`, `tools/spec-check.cs`).
- Findings 3-4: open.

## Verdict
pass - checks 20/20 and every criterion met from the artifacts. The next run must re-check that stories are branched
per story from the start (not split after the fact) and that each story branch carries its own Build Report and plan.
