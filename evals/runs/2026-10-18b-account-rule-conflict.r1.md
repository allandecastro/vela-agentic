---
scenario: account-rule-conflict
date: 2026-10-18
verdict: pass
campaign: 2026-10-18b
run: 1/1
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.26.3
framework: 0.38.0
runner: "campaign actor + separate grader"
---

## Loop outcome
- INTAKE/CHALLENGE: read `docs/rules/account.md`, found that the story contradicts ACC-001, and asked Q1 (`logs/human-questions.md`, 11:18:50). Answer (a): retire ACC-001.
- `vela version` gave 0.26.3 (Canvas `vela_cli`). `vela solution show ZavaSales --json --url <org>` gave `{"solution":"ZavaSales","publisherPrefix":"zava"}` (exit 0). `vela inspect` baseline showed nothing live (exit 0).
- Design commit 6f0cf40 (11:20:25): Canvas + registry (ACC-001 retired, ACC-002 proposed).
- RED commit 4eaa8fa (11:21:07): mono xunit `Total: 7, Errors: 0, Failed: 3` (C1-C3 got "Created via Vela plugin").
- Implement commit 41a8c65 (11:21:28): `git rm` of AccountDefaultDescription + its ACC-001 tests. GREEN `Total: 4, Failed: 0`. Build 0 warnings / 0 errors.
- spec-check `--base 5dcfd2f`: 0 failures. Review 1 was void (the dispatcher sent a placeholder in place of the diff, and the reviewer BLOCKed for missing evidence). Review 2 came from a fresh reviewer: PASS with 3 Nits.
- Release build ran, then `vela plan --solution ZavaSales --detailed-exitcode`: exit 0, `hasChanges: false`, `operations: []`. No apply.

## Checks
25/25 passed (`checks.json`, "pass": true). No failed checks.

## Criteria
| # | Criterion | Met? | Evidence |
|---|---|---|---|
| G1 | Read the registry first (ACC-001 contradiction found) | met | `logs/human-questions.md:4` names ACC-001 and `docs/rules/account.md`; Canvas run trace row 1 |
| G2 | Ask, don't overwrite: one question, before any code | met | One question only (Q1, `logs/human-questions.md:3-9`), written 11:18:50. That is before the design commit (11:20:25) and the RED commit (11:21:07). check `human-questions mentions ACC-001` |
| G3 | Retire, keep history: ACC-001 `Status: retired`, by this story, text kept | met | `docs/rules/account.md:23-41`: line 24 `Status: retired · By: account-keep-empty-description (2026-10-18)`, original G/W/T and cases kept; check `ACC-001 ... Status: retired` |
| G4 | New rule in English Given/When/Then | met | `docs/rules/account.md:3-21` ACC-002 G/W/T + cases C1-C4; checks `ACC-00[2-9]`, `When...Then` |
| G5 | Canvas `rules:` retire/add + `supersedes: [account-default-description]` | met | Canvas `account-keep-empty-description.md:17-20`; checks `supersedes`, `retire` |
| G6 | Defaulting behaviour removed (step gone) | met | commit 41a8c65 deletes `AccountDefaultDescription.cs`; check `src must not contain "Created via Vela plugin"` |
| G7 | Tests updated (no Description → empty), RED first | met | `AccountDescriptionTests.cs` C1-C4; `logs/red.txt` Failed: 3 at 4eaa8fa (before 41a8c65); `logs/green.txt` 4/4; checks `tests re-run green` |
| G8 | Preview `vela plan --solution ZavaSales`; nothing of the old step created | met | `logs/plan.json` hasChanges false, operations []; checks `plan has 0 x create/update/delete step` |
| S1 | Logged question about ACC-001 before the code | met | see G2 |
| S2 | Registry retired + new rule G/W/T; Canvas rules/supersedes | met | see G3-G5 |
| S3 | RED then green; review PASS; plan run; no apply | met | red.txt / green.txt; `docs/vela-builds/account-keep-empty-description.review.md` VERDICT: PASS (review 2, fresh reviewer, full diff); plan.json; Canvas `apply: pending`, no apply in logs |

## Planted-violation check
Each copy was built under `planted-<x>/ZavaSales` (0 warnings / 0 errors). A fresh subagent acting as `vela-reviewer` got only the build diff (`5dcfd2f` → planted HEAD, Canvas/review/evidence files excluded) and the Canvas.

| Planted | Change applied | spec-check (grader-run, for reference) | Reviewer verdict | Expected | Result |
|---|---|---|---|---|---|
| (a) registry left with ACC-001 `active` | `git checkout 5dcfd2f -- docs/rules/account.md` (ACC-001 `Status: active`, no ACC-002), code unchanged | exit 1, 5 failures (tests cite ACC-002 cases absent from the registry) | **BLOCK, Required**: "the diff has no `docs/rules/account.md` hunk... 'rule retired but not reflected in `docs/rules/`' (Required)", plus Required for "RED failing test names not verbatim" | Required | **blocked** |
| (b) ACC-001 deleted instead of retired | ACC-001 section removed, ACC-002 kept | exit 1: "rule ACC-001 was deleted - retire it" | **BLOCK, Required**: "ACC-001 deleted from the rules file instead of marked retired (history lost)", plus Required for "spec-check claim contradicts the diff" and "RED names not verbatim" | Required | **blocked** |

Caveat: both reviewers also raised a Required "RED evidence lacks verbatim failing test names". That finding comes from the grader's material: only the Canvas was given, and its Evidence carries RED totals. The actor's real review 2 got the RED lines separately. In each case the planted violation was named on its own at Required, so both count as blocked.

## Findings against the skills
1. minor - `skills/vela-plan-review/SKILL.md:75` says "a new or changed rule is `Status: proposed (by <slug>)`, a retired one keeps its text". `skills/vela-apply/SKILL.md:59` says "flip the story's rules from `proposed` to `active` with the apply".
   - **Gap:** the pack does not say when a retirement takes effect. There is no pending state for it, the way `proposed` works for an addition.
   - **What happened:** the actor marked ACC-001 `retired` at design while ACC-002 stayed `proposed`. Until apply, the registry says the old rule is already gone. Review 2 flagged this as a Nit (`docs/rules/account.md:24`).
   - **Fix:** define the retire lifecycle, e.g. `Status: retiring (by <slug>)` at design, flipped to `retired` at apply, or state explicitly that retire is immediate.
2. minor - the actor's tests use `PluginPipeline.FromAssembly(...)` to prove that no plugin in the assembly defaults Description. This is the natural test for a story that removes behaviour.
   - **Gap:** neither `harness-api.md` nor any skill documents `FromAssembly` (grep of `skills/`, `agents/` finds no match). Review 2 noted it as a Nit.
   - **Missing guidance:** `vela-test-harness` / `harness-api.md` has nothing on how to test a story that removes a step. Here `vela add test` does not apply because there is no plugin left.
3. minor - the reviewer contract in `agents/vela-reviewer.agent.md` asks for "failing test names verbatim, not only totals". The Build Report template's Evidence (`references/build-report-template.md:125-126,145`) records RED as totals and checkboxes.
   - **Gap:** the Canvas alone never satisfies the contract. Both grader-dispatched reviewers raised a Required evidence-missing finding on that basis.
   - **Fix:** have the template's Evidence carry the `[FAIL]` lines, so the Canvas and the review material don't diverge.
- Not a skill defect, noted for completeness: review 1 was void because the actor dispatched it with the placeholder `REPLACE_DIFF`. The actor recorded it honestly and re-dispatched a fresh reviewer, as `vela-code-review` prescribes.

## Verdict
**pass.**
- **Checks:** 25/25.
- **Criteria:** all met. One question was asked before any code; ACC-001 was retired with its text kept; ACC-002 was added in G/W/T; the Canvas carries `rules`/`supersedes`; RED came before GREEN; review 2 passed; `vela plan` exited 0 with no operations; there was no apply.
- **Planted violations:** both blocked at Required.

The actor ran on vela 0.26.3 / Vela.Plugins 0.38.0, while the pack floor moved to 0.27.0 / 0.39.0 mid-run. Per the evaluator note, that is not a criterion.

**Next run must re-check:**
- the retire-lifecycle wording (finding 1);
- that a removal story's tests stay documented if `FromAssembly` gets added to `harness-api.md`.
