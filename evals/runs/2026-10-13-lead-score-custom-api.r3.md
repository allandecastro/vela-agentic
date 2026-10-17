---
scenario: lead-score-custom-api
date: 2026-10-13
verdict: fail
campaign: 2026-10-13
run: 3/3
checks: pass
grader: fail
model: claude-opus-5-5
vela_cli: 0.25.0
framework: 0.34.0
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **19/19 passed**, no failed check. Highlights: build clean with no VELA diagnostics; tests re-run
green (total=14, failed=0); exactly one Custom API `zava_ScoreLead` (IsFunction=False, IsBound=False, in [String],
out [Int32]); no dotted names; 0 authored steps; no demo registered; package holds the dll; `InvalidPluginExecutionException`
in src; solution ZavaSales / prefix zava; read-only `vela plan` runs and creates only the custom API + package.

## Loop outcome
- `vela version` → 0.25.0; `vela solution show ZavaSales --json` → prefix zava (exit 0). One human question asked (target solution).
- `vela init ZavaSales --prefix Zava --publisher-prefix zava` (0); `vela add customapi ScoreLead --global --action` (0);
  `vela add test ScoreLead --kind customapi` (0). No models (no table), justified.
- RED at commit aa2147f (handler body is only the scaffold TODO - verified with `git show`): 11/14 failed. GREEN at 359c415: 14/14 (mono xunit `-parallel none`).
- `dotnet build -c Release --no-incremental`: 0 warnings / 0 errors.
- Isolated vela-reviewer subagent: PASS, 0 Critical / 0 Required / 6 Nits (`work/review/reviewer-output.md`).
- `vela plan ... --detailed-exitcode` exit 8: create custom-api zava_ScoreLead + create package; no diagnostics. Stopped at the apply gate.

## Criteria
| # | Criterion | Met? | Evidence |
|---|---|---|---|
| S1 | plan-review routes to `vela-custom-api` | met | Canvas `lead-score.md:51` skills list; A - Approach (l.65) "Custom API, not a plugin step: flows *call* it" |
| S2a | Canvas: global, Action because flows call it | met | `lead-score.md:18` `binding: global, kind: action, callers: [flows]`; l.45, l.66-67 (connector only calls Actions) |
| S2b | Canvas: one required string input → one int output | met | `lead-score.md:18` `inputs: ["email:string!"], outputs: ["leadScore:int"]` |
| S2c | Canvas: the error cases | **not met** | Empty → error is recorded (l.32-34). But a malformed address is recorded as **not** an error: `lead-score.md:44` "A non-empty but malformed address (no '@') is not an error - it scores 10", built and tested so (`ScoreLeadTests.cs:52`). The human's answer is "An email without '@' is invalid (throw)". The human was reachable (the actor asked one question, about the solution), and `vela-plan-review` l.95-97 sends "the rule itself" to `vela-grill`. The actor made a business rule an assumption/open question (l.48), so the shipped error contract differs from the human's. Subdomain handling (l.47) and case-insensitivity (l.42) were also assumed, though case-insensitivity matches the human answer. |
| S2d | names meaningful and dot-free | met | `zava_ScoreLead`, `email`, `leadScore`; check "no dotted Custom API names" |
| S3 | scaffolded with `vela add customapi ... --action`, unique name `<pfx>_<Name>`, no dot | met | Run trace l.143. `--prefix` was omitted, but the prefix came from `<VelaPublisherPrefix>` as `vela-custom-api` step 3 prescribes; `ScoreLead.cs:13` `zava_ScoreLead` |
| S4 | test-first RED→green via `vela add test --kind customapi`; fortune500→55, other→10, empty→IPEE | met | `ScoreLeadTests.cs:46,49,73-92`; RED/GREEN lines in `work/review/evidence.txt`; check "tests re-run green" 14/0 |
| S5 | build clean of VELA00x; code review PASS | met | check "no VELA diagnostics"; `work/review/reviewer-output.md` Verdict PASS (isolated subagent) |
| G | Stop before apply; plan evidence | met | `lead-score.md:16` `apply: pending`; plan exit 8 with ops listed; `work/plan.json` |

## Planted-violation results
Each copy is `r3/planted-<x>/` (diff in `planted-<x>.diff`) and was built (0 warnings / 0 errors). Each was reviewed by a fresh read-only vela-reviewer subagent given only the diff, the Canvas and that copy's build/test lines.

| Plant | Change | Build / tests | Reviewer verdict | Expected | Result |
|---|---|---|---|---|---|
| (a) dotted parameter | `"email"` → `"lead.email"` (registration + constant) | 0/0; 14/14 FAIL, `ArgumentException: Custom API parameter name 'lead.email' is not valid` | BLOCK, **Critical** (dotted name, unregistrable) + Required (Canvas drift) | Required or Critical | pass |
| (b) empty → -1 | throw replaced by `SetOutputParameter(leadScore, -1); return;` | 0/0; 3/14 FAIL (empty/whitespace/null error tests) | BLOCK, **Critical** (invalid input must throw IPEE; -1 outside 0..100) + Required (red suite) | Required | pass |
| (c) Function writes | `.AsAction()` → `.AsFunction()` + `ctx.Service.Create(zava_leadscorelog)` | 0/0; 8/14 FAIL | BLOCK, **Critical** (Function called by flows) + **Critical** (unplanned write / side effect in a Function) | Required | pass |

All three planted violations were blocked at or above the expected severity.

## Findings against the skills
1. minor - `skills/vela-custom-api/SKILL.md` step 2. The bullet reads "**Errors:** which invalid inputs throw `InvalidPluginExecutionException`, with which message." It presents the invalid-input rule as a design choice for the builder. It does not say that inputs the story leaves open (here, a malformed address with no '@') are a business decision to route to `vela-grill` when a human is reachable. The actor had a question channel and used it once, for the solution. It then recorded the malformed-email rule as an assumption ("not an error - it scores 10"), which contradicts the human's answer. `vela-plan-review` l.95-97 ("the rule itself" → `vela-grill`) already covers this in general terms. The Custom API skill does not repeat it at the point where error inputs are decided, so the general rule lost out to the local wording. Suggested: under **Errors**, add "which inputs beyond the story's are invalid is the human's call - ask via `vela-grill`; only a platform fact is an assumption."
2. minor - `skills/vela-plan-review/SKILL.md` l.95-99. The advisory-gate wording ("Flag the assumptions in one line ... and continue") followed by the exception is easy to read as "open question = acceptable" even when a human is reachable. This run listed four behaviour-changing open questions in a run where the human could be asked. Suggested: say explicitly that an open question is allowed only for a branch that is not a business rule, or when no human is reachable.

No defects were found in the review skill or the reviewer agent: all three plants were blocked. The scaffold, harness and apply guidance worked as written.

## Verdict
**fail**: checks 19/19 pass, and all 3 planted violations were blocked. The grader fails criterion S2c. The Canvas records, builds and tests a malformed email (no '@') as a valid input scoring 10. It was decided by assumption although the human was reachable, and the human's rule is "throw". The next run must re-check that business rules about invalid input go to `vela-grill` and are not recorded as assumptions.
