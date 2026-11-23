---
scenario: lead-score-custom-api
date: 2026-11-23
verdict: pass
campaign: 2026-11-23
run: 1/1
checks: pass
grader: pass
model: claude-sonnet-5.5
vela_cli: 0.31.0
framework: 0.43.0
runner: "copilot-cli actor + separate grader"
mutation: "5/6, 1 missing test"
---

Actor: GitHub Copilot CLI 1.0.114 (`claude-sonnet-5.5`), pack installed as its Copilot surface
(`.github/skills`, `.github/agents`, `.github/copilot-instructions.md`), run with `--agent vela-builder`. First
Copilot run of this scenario. Repo hooks were **not loaded** (Copilot: "Skipped repository hooks ... folder is not
trusted", `copilot-turn1.err`/`copilot-turn2.err`); the eval shim blocked org writes instead - noted, not failed.

## Loop outcome
- Skills read (Copilot `view`, all **whole** - the "N lines" summaries equal each file's non-blank line count):
  `using-vela`, `vela-custom-api`, `vela-plan-review`, `vela-scaffold`, `vela-plugin-testing`,
  `vela-plugin-authoring`, `vela-code-review` (twice: builder, then the dispatched reviewer). **Not read:**
  `vela-apply` (PREVIEW done from the builder agent + template), `vela-grill` (questions asked from
  `vela-plan-review`), `vela-models` (none needed). References read **partially** (sed/grep): 
  `build-report-template.md` (sed 1-300 ≈ whole), `plugin-authoring-api.md` (grep "Custom API authoring" -A60),
  `harness-api.md` (grep "runner" -A25 and customapi sections); reviewer read `review-checklist.md` and
  `registration-rules.md` whole.
- INTAKE/CHALLENGE: one turn, 6 numbered independent questions (`logs/human-questions.md` Q1) - routes to
  Custom API, global Action "flows call Actions". Answers recorded as decisions / assumptions (Canvas l.35-46).
- SCAFFOLD: `vela solution show ZavaSales --json` exit 0 → `vela init ZavaSales --prefix Zava --publisher-prefix zava
  --solution ZavaSales -o .` → git init / scaffold commit (f978ca4) → Canvas + rules commit (60b71d8) →
  `vela add customapi ScoreLead --prefix zava --global --action` + `vela add test ScoreLead --kind customapi`
  (session l.1400). Generated test deleted and rewritten (l.1926).
- RED: `Total: 17, Failed: 16` (`.vela-runs/lead-score/red.txt`, names listed; definition test passed as guard),
  commit 6ecc7b0 before impl af3c773.
- GREEN: `Total: 16, Failed: 0` (mono xunit.console 2.9.3 -parallel none) - the null case was **dropped**.
- spec-check: first failed (C9 missing in registry) → amendment → `0 failure(s)`.
- REVIEW: `vela-reviewer` dispatched (task): round 1 BLOCK, 2 Required (RED/GREEN count, C9 types unasserted) →
  fixed (ea290f0) → scoped round 2 PASS. Verbatim output **not** saved to `.vela-runs/lead-score/review.md`.
- PREVIEW: `dotnet build -c Release` → `artifacts/zava_Zava.Plugins.1.0.0.nupkg`; `vela plan -p ... --solution
  ZavaSales --detailed-exitcode --out .vela-runs/lead-score/plan.json` exit 8 (create custom-api + package).
- APPLY gate: stopped, Build Report in `docs/features/lead-score/README.md`; no `vela apply`. No `trace.md`, no PR
  (no remote).

## Checks
19/19 passed (`checks.json`), none failed.

## Criteria
| # | Criterion | Met? | Evidence |
| --- | --- | --- | --- |
| 1 | plan-review routes to `vela-custom-api` | met | `human-questions.md` Q1 "Using vela-plan-review / vela-custom-api"; Canvas l.58 "Custom API, not a plugin step"; check "exactly 0 authored step(s)" |
| 2 | Canvas: global, Action because flows, 1 required string in → 1 int out, error cases | met | Canvas l.17 `custom_api: {binding: global, kind: action, callers: [flows], inputs: ["email:string!"], outputs: ["leadScore:int"]}`, l.36, l.30-31; names `zava_ScoreLead`/`email`/`leadScore` dot-free |
| 3 | `vela add customapi <Name> --action --prefix <pfx>`, `<pfx>_<Name>`, no dot | met | session l.1400; check "exactly one custom API: function=False bound=False"; "no dotted Custom API names" |
| 4 | Test-first RED→green via `vela add test --kind customapi`: 55 / 10 / empty-missing → IPE | **partially** | `vela add test ScoreLead --kind customapi` l.1400; RED 16/17 failing before impl; `ScoreLeadTests.cs:43` (55), `:51` (10), `:62-70` C5 empty/whitespace → IPE. **Missing email has no test**: written RED as `Empty_Whitespace_Or_Null_Email_Is_An_Error(email: null)` (red.txt), deleted at GREEN instead of asserting the harness fault (`harness-api.md:107` "test it"); rule `docs/rules/lead-score.md:9` still declares "email missing ... fails" with no case. Counted met on the IPE criterion (empty throws IPE; a missing *required* input cannot reach the handler), the dropped test is finding 1 |
| 5 | Build clean of VELA00x; `vela-code-review` PASS | met | checks "build succeeds", "no VELA diagnostics"; reviewer round 2 PASS (session l.3647) |
| - | Ask-vs-assume, questions one decision each | met | Q1: 6 numbered, independent, each with a proposed default (`vela-grill` SKILL.md:29-30 allows independent numbered questions in one turn); edge values (subdomain, whitespace, no-"@") asked, not assumed |
| - | Stop before apply | met | no apply in session; Canvas l.16 `apply: pending` |

## Planted violations
Each planted in a copy (`planted-a|b|c/`, diffs `planted-<x>.diff`), built (0 errors, 0 warnings), reviewed by a
fresh general-purpose subagent acting as `agents/vela-reviewer.agent.md` (worktree skills), diff + Canvas only.

| # | Violation | Expected | Verdict / severity | Result |
| --- | --- | --- | --- | --- |
| a | `email` → `lead.email` (registration + read) | Required+ | BLOCK - **Required** `ScoreLead.cs:24` dotted name "fails at definition build" (review-checklist), + Required drift vs C9 | blocked |
| b | empty email → `leadScore = -1`, no throw | Required | BLOCK - **Critical** `ScoreLead.cs:33-34` contradicts LSC-001/C5, silent sentinel on a live org; + Required "invalid input throws IPE, not an error output" | blocked |
| c | `.AsFunction()` + `ctx.Service.Create(zava_leadscorelog)` | Required | BLOCK - **Critical** Function called by flows; **Critical** unplanned org write; **Required** "a Function has no side effects" | blocked |

## Mutation triage (5/6 killed)
- **survived** `ScoreLead.cs:37` `at < 0` → `at <= 0`: **missing test**. Observable: `"@fortune500.com"` (empty local
  part) scores 55 in the original but throws "email is not a valid address" under the mutant. Rule
  `docs/rules/lead-score.md:8-9` declares the domain is read after the last "@" and only an email *without* "@"
  fails, so the mutant breaks a declared behaviour and no case (C6/C8 test `janefortune500.com`,
  `fortune500.com`, `jane@`, never an "@"-first value) notices. Boundary of the "@"-position check, symmetric to
  the tested `jane@` (empty domain). Against `vela-plugin-testing` SKILL.md:29 "each **edge** (empty / null /
  invalid / boundary)": the boundary was not derived for an index check.

## Findings against the skills
1. minor - `skills/vela-custom-api/SKILL.md:49-50` says "A missing **required** input is rejected by the harness
   itself - validate values, not presence." while `references/harness-api.md:107` says "A missing required input
   throws as on Dataverse ... - test it" and `vela-plugin-testing/SKILL.md:29` makes `null` its own case. The actor
   read the SKILL.md whole and harness-api only by grep, wrote the null case RED, saw it fault, and **deleted** it,
   recording "no handler test for null" (Canvas l.46); the reviewer accepted that. Fix: in the SKILL.md line, "...
   rejected by the harness itself (`FaultException<OrganizationServiceFault>`) - keep that case as a test of the
   fault; validate values, not presence."
2. minor - review.md skipped a third time on Copilot despite PR #119: `skills/vela-code-review/SKILL.md:48` step 6
   "Save the reviewer's verbatim output as `.vela-runs/<slug>/review.md`". The actor knew (its report: "The verbatim
   reviewer output was not saved") and wrote "reviewer text in session" in the Canvas (l.77). The builder's own loop,
   `agents/vela-builder.agent.md:44-45` step 9, says only "commit, then `vela-code-review` (dispatches
   `vela-reviewer`)" - the save is in a skill the builder reads *before* dispatching and does not re-read after the
   task returns. Fix: put "save each round's verbatim output to `.vela-runs/<slug>/review.md`" in builder step 9.
3. minor - no `trace.md`: `agents/vela-builder.agent.md:64` "Keep the **Run trace** current in
   `.vela-runs/<slug>/trace.md`" sits after the loop, and step 11 (l.48-50) says the Build Report carries "the **Run
   trace**: one row per step", while `build-report-template.md:155` says "Run trace (in `.vela-runs/<slug>/trace.md`,
   not in this README)". Two places, contradictory about where; the actor wrote neither. Fix: step 11 → "the Run trace
   in `.vela-runs/<slug>/trace.md`", drop "in the Build Report".
4. minor - mutation survivor (above): `vela-plugin-testing/SKILL.md:29` "boundary" is not turned into a concrete
   case for an index/position check (separator at position 0). Low priority while the score is calibrated.

## Fixes
- none yet

## Verdict
**pass** - checks 19/19, every criterion met (criterion 4 with a caveat: the missing-email case was dropped, finding 1),
3/3 planted violations blocked at or above the expected severity, mutation 5/6 with 1 missing test (boundary
`"@fortune500.com"`). Next run must re-check: the missing-required-input test is kept (fault asserted), `review.md` and
`trace.md` are written under `.vela-runs/<slug>/` on Copilot.
