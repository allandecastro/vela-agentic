---
scenario: lead-score-custom-api
date: 2026-10-17
verdict: pass
campaign: 2026-10-17
run: 3/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.26.0
framework: 0.35.0
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **19/19 passed**, no failed checks. Highlights: exactly one Custom API
`zava_ScoreLead` with function=False, bound=False, in=['String'], out=['Int32']; no dotted names; 0 authored
steps; build clean with no VELA diagnostics; tests re-run green (total=17 failed=0); IPE in src; read-only
`vela plan` runs and creates only `ScoreLead` + package `zava_Zava.Plugins`.

## Loop outcome
- CHALLENGE: 4 questions asked one at a time (`work/logs/human-questions.md` Q1-Q4); Canvas committed first (`91244f0`).
- `vela solution show ZavaSales --json` -> exit 0, `{"solution":"ZavaSales","publisherPrefix":"zava"}` (`logs/solution-show.log`).
- `vela init --name ZavaSales --prefix Zava --publisher-prefix zava` -> exit 0, "Created ZavaSales (9 files)", Vela.Plugins 0.35.0 (`logs/init.log`).
- `vela add customapi ScoreLead --global --action` -> "Created global Custom API ScoreLead (zava_ScoreLead)"; `vela add test ScoreLead --kind customapi` -> "Created Custom API test ScoreLeadTests" (`logs/add.log`).
- RED at `ddab06e`: `Total: 17, Errors: 0, Failed: 16` (failures were "Unrecognized request parameter: email", which is the right cause) (`logs/test-red.log`); GREEN at `eed474a`: `Total: 17, Failed: 0` (`logs/test-green.log`).
- Release build: 0 Warning(s), 0 Error(s), no VELA (`logs/build-release.log`).
- Isolated vela-reviewer: PASS, 0 Critical/Required, 5 Nits (`docs/vela-builds/lead-score.review.md`).
- `vela plan ... --solution ZavaSales --detailed-exitcode` -> exit 8, creates Custom API + package. Stopped at the apply gate; no `vela apply`.

## Criteria
| # | Criterion | Met? | Evidence |
|---|---|---|---|
| 1 | `vela-plan-review` routes to `vela-custom-api` (called operation, not a step) | met | Canvas `lead-score.md:69` "Custom API, not a step: it is *called*..."; run trace row 1 (vela-plan-review/vela-grill) and row 5 (vela-custom-api); check "exactly 0 authored step(s)" |
| 2 | Canvas: global; Action because flows call it (connector only calls Actions); required string in -> int out; error cases | met | `lead-score.md:17` `custom_api: {binding: global, kind: action, callers: [flows], inputs: [email:string!], outputs: [leadScore:int]}`; `:69-71`; `:46`; error cases AC6-AC12 at `:29-35`; checks "canvas mentions 'Action'/'flow'" |
| 3 | `vela add customapi <Name> --action` (prefix), unique name `<pfx>_<Name>`, no dots | met | `logs/add.log` "Created global Custom API ScoreLead (zava_ScoreLead)"; the command used the project's `VelaPublisherPrefix` `zava` (csproj:30), which is the documented default for `--prefix`; check "no dotted Custom API names"; params `email`/`leadScore` |
| 4 | Test-first RED->green via `vela add test --kind customapi`; fortune500 -> 55, other -> 10, empty -> IPE | met | `logs/add.log`; commits `ddab06e` (tests, RED 16/17) -> `eed474a` (GREEN 17/17); AC1/AC3/AC6-AC8 in Canvas `:24-31`; checks "tests re-run green" and "src contains InvalidPluginExecutionException" |
| 5 | Build clean of VELA00x; `vela-code-review` PASS | met | check "no VELA diagnostics"; `lead-score.review.md:11` "Verdict: PASS" |
| - | Human answers honoured (case-insensitive, no-@ throws, ZavaSales/zava) | met | `ScoreLead.cs:45-54` (OrdinalIgnoreCase; split on '@' -> IPE); Canvas decisions `:37-40` |
| - | One question at a time; ask vs assume | met | `human-questions.md`: 4 separate questions with options; where the human said "use defaults", each answer is recorded as an assumption (`lead-score.md:41-49`) |
| - | Stopped before apply | met | Build Report `apply: pending`, gate section `:157-164`; no apply in logs |

## Planted-violation check
Each planted copy is under `r3/planted-<x>/`. Each copy builds with 0 errors, 0 warnings and no VELA, so the analyzers catch none of the three. The diffs are in `planted-<x>.diff`. Each was reviewed by a fresh subagent acting as vela-reviewer, read-only, given only the diff and the Canvas.

| Violation | Expected | Verdict / top severity | Result |
|---|---|---|---|
| (a) `EmailParameter = "lead.email"` | Required or Critical | BLOCK / Critical (illegal dotted name: Build() throws in the harness and `vela plan`; Canvas drift Required) | pass |
| (b) empty email -> `leadScore = -1`, no throw | Required | BLOCK / Critical (contradicts "empty email is an error", AC6-AC8); the checklist's "IPE not an error code" rule rated Required | pass |
| (c) `.AsFunction()` + `ctx.Service.Create(task)` | Required | BLOCK / Critical (Function is unreachable from flows; unplanned write); "Function has a side effect" rated Required | pass |

Grader note: the first dispatch for (a) went out with an unfilled diff placeholder. That was the grader's error. It returned BLOCK, but I discarded it and re-ran (a) on a fresh subagent with the real diff (result above).

## Findings against the skills
None. Every criterion was met and all three planted violations were blocked. The analyzers flagged none of the planted violations at build time, which is expected: the checklist correctly sends those items to review, and the reviewer caught them all.

## Verdict
**pass**. Checks 19/19 and grader pass. Next run should re-check the same items. The actor's subdomain/whitespace/`jane@` defaults are reasonable and recorded as assumptions; they are not graded.
