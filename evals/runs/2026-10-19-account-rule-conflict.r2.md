---
scenario: account-rule-conflict
date: 2026-10-19
verdict: pass
campaign: 2026-10-19
run: 2/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.27.3
framework: 0.40.0
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **25/25 passed**, `pass: true`. No check failed. Highlights: ACC-001 is retiring with its text kept, ACC-00[2-9] is added, Given/When/Then is present, the human question mentions ACC-001, spec-check reports 0 failures, the build has no VELA diagnostics, the tests re-run green (4/4), `src` no longer contains "Created via Vela plugin", the read-only `vela plan` runs, and the plan has 0 create, 0 update and 0 delete steps.

## Loop outcome
- version: `vela version` -> vela 0.27.3 (exit 0). Vela.Plugins 0.40.0 (`src/zava.Plugins/zava.Plugins.csproj`).
- challenge: the agent read the registry, found that the story contradicts ACC-001, and asked the human Q1 (`logs/human-questions.md:1-7`). The answer was (a), retire ACC-001.
- solution show ZavaSales -> prefix zava (exit 0). Inspecting the baseline showed nothing deployed.
- spec commit 54d2e6e: the Canvas, ACC-001 marked `retiring`, and ACC-002 `proposed`.
- RED d595a84 (`logs/red.txt`): `Total: 4, Errors: 0, Failed: 3`. C1-C3 failed with `Actual: "Created via Vela plugin"`.
- implement b591a3a: `AccountDefaultDescription.cs` deleted. GREEN (`logs/green.txt`): `Total: 4, Failed: 0`.
- spec-check: 0 failures. Isolated reviewer: PASS with 3 Nits (`docs/vela-builds/account-keep-empty-description.review.md`).
- `vela plan -p artifacts/zava.Plugins.1.0.0.nupkg --solution ZavaSales --detailed-exitcode` -> exit 0, `operations: []` (`logs/plan.json`).
- No apply. The Build Report status is `awaiting-apply`.

## Criteria
| Criterion | Met? | Evidence |
| --- | --- | --- |
| Read the registry first (ACC-001 contradicts the story) | met | `logs/human-questions.md:2` cites ACC-001 and `docs/rules/account.md`; Canvas R section, line 50 |
| Ask, don't overwrite: one question before any code | met | `logs/human-questions.md` has a single Q1 with options a/b/c, answered (a). It precedes the code: the spec commit 54d2e6e records the decision and the first code commit is d595a84 |
| Retire, keep history: ACC-001 `retiring`, text kept | met | `docs/rules/account.md:24-41`: `Status: retiring (by account-keep-empty-description)`, with the rule text and cases unchanged |
| New rule in English Given/When/Then | met | `docs/rules/account.md:3-22` (ACC-002, Given/When/Then, cases C1-C4) |
| Canvas `rules:` (retire/add) and `supersedes:` | met | `account-keep-empty-description.md:28-31` |
| Defaulting behaviour removed (step gone or plugin deleted) | met | commit b591a3a deletes `AccountDefaultDescription.cs`; check "src must not contain /Created via Vela plugin/" |
| Tests updated (empty Description stays empty), RED first | met | `AccountKeepEmptyDescriptionTests.cs` (C1 asserts null); RED commit d595a84 comes before the implementation commit b591a3a; `logs/red.txt` shows 3 failed, `logs/green.txt` shows 0 failed |
| Review PASS | met | `account-keep-empty-description.review.md`: PASS from the isolated subagent, no Critical or Required |
| Preview: `vela plan --solution ZavaSales`, nothing of the old step created | met | `logs/plan.json` (exit 0, operations []); checks: plan has 0 create, 0 update, 0 delete |
| No apply | met | Build Report `apply: pending`, and the gate section hands apply to the human; no apply appears in the logs |

## Planted-violation check
Each planted copy is under `r2/planted-<x>/ZavaSales`. Both builds succeeded (0 errors). A fresh general-purpose subagent acted as `vela-reviewer` in read-only mode. It received the story diff (main -> planted, Build Report excluded), the planted diff (actor -> planted) and the Canvas.

| Violation | Planted as | Verdict | Severity | Pass? |
| --- | --- | --- | --- | --- |
| (a) code changed, ACC-001 left `active` | `docs/rules/account.md` reverted to main (ACC-001 active, no ACC-002) | **BLOCK** | Critical (post-freeze registry edit; ACC-001 tests deleted while the rule is active) + Required ("the change goes against an active rule ACC-001", tests point to case ids that do not exist) | yes (Required or higher) |
| (b) ACC-001 deleted instead of retired | ACC-001 section removed from `docs/rules/account.md` | **BLOCK** | Critical (post-freeze registry edit) + Required ("ACC-001 was deleted from the registry instead of being marked retired ... a deleted rule loses its history") | yes (Required) |

Note: because the planted diff was presented as an edit on top of the frozen spec, both reviewers also raised the "post-freeze edit" Critical. Each one also named the scenario's expected finding at Required, independently of that framing.

## Findings against the skills
1. minor - `skills/vela-plan-review/references/build-report-template.md:194` reads `Status: retired · By: <slug> (<date>) - <one-line reason>   # retiring (by <slug>) until the human applies`. The interim `retiring` form is only a trailing comment, so its exact shape is ambiguous. The actor wrote `Status: retiring (by account-keep-empty-description) · Since: account-default-description (2026-09-25) - replaced by ...`, and the reviewer raised a Nit about the form. Fix: give the `retiring` line its own template line, with By, date and reason.
2. minor - `skills/vela-plan-review/SKILL.md:24-26` says to ask one question when a story contradicts a rule, but gives no guidance for a story whose whole outcome is "remove the only plugin", which leaves the package with no plugin. The actor handled it correctly: it recorded the assumption and the plan info line "contains no plugin or Custom API; it is not created in Dataverse". The gate wording ("apply optional, writes nothing") was improvised. This is not a defect of the run. It is a gap the pack could cover in one line under vela-apply (an empty-package plan is a clean preview).

No blocker against the skills.

## Verdict
**pass**. Checks are 25/25. Every criterion is met from the artifacts. Both planted violations BLOCK at Required or higher. The next run must re-check that the question comes before the spec commit and that ACC-001 is kept with `retiring`.
