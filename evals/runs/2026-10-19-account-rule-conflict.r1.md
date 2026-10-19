---
scenario: account-rule-conflict
date: 2026-10-19
verdict: pass
campaign: 2026-10-19
run: 1/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.27.3
framework: 0.40.0
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json` shows **25/25 passed** with `pass: true`, so no check failed. The checks covered:
- The Canvas exists and mentions both `supersedes` and `retire`.
- In `docs/rules/account.md`, ACC-001 is `retiring` with its text kept, and ACC-002 is added in When/Then form.
- `logs/human-questions.md` mentions ACC-001.
- spec-check reports 0 failures.
- The build succeeds with no VELA diagnostics.
- 3 tests are green on re-run.
- `Created via Vela plugin` is gone from src.
- `vela solution show ZavaSales` returns the `zava` prefix.
- A read-only `vela plan` runs with 0 create, 0 update and 0 delete steps, and no demo.

## Loop outcome
Read from `work/logs/run-trace.md`, the Canvas Run trace and `git log` in `work/ZavaSales`.
- `vela version` returned 0.27.3, exit 0.
- The actor read the registry and found that the story contradicts active ACC-001. It asked Q1 and the human answered A (replace ACC-001).
- `vela solution show ZavaSales --json` exited 0 with prefix `zava`.
- `vela inspect` on the baseline package exited 0. zava.Plugins is not deployed on the dev org.
- Design commit `520465f`: Canvas plus registry, with ACC-001 `retiring` and ACC-002 `proposed`.
- RED commit `6973dec`: the mono xunit console run returned `Total: 6, Errors: 0, Failed: 2`. C1 and C2 failed for the right reason; C3 is a guard case.
- Implementation commit `4a13c34`: `git rm` of `AccountDefaultDescription.cs` and of the ACC-001 tests.
- GREEN: `Total: 3, Errors: 0, Failed: 0`.
- Release build: 0 warnings, 0 errors, no VELA00x.
- spec-check `--base main`: 0 failures.
- An isolated vela-reviewer returned PASS with 4 Nits.
- `vela plan --solution ZavaSales --detailed-exitcode` exited 0 with `operations: []`.
- The actor stopped at the gate. It did not run apply.

## Criteria

| Criterion | Met? | Evidence |
|---|---|---|
| The registry was read first, and the ACC-001 contradiction was detected | met | `logs/human-questions.md:2` quotes ACC-001 and its implementation; run-trace row 2 |
| Ask, don't overwrite: one question before any code | met | `logs/human-questions.md:1-5`: a single Q1 with A/B options, answered. The design commit `520465f` comes before `6973dec` (tests) and `4a13c34` (code) |
| ACC-001 kept, `Status: retiring`, by this story, text kept | met | `docs/rules/account.md:22-39`; line 23 reads `Status: retiring (by account-keep-empty-description) · By: ... replaced by ACC-002 (human decision, Q1)` and the Given/When/Then and cases are intact |
| The new rule is in English Given/When/Then | met | `docs/rules/account.md:3-20` (ACC-002, `proposed`, cases C1-C3) |
| The Canvas `rules:` has retire and add; `supersedes: [account-default-description]` | met | Canvas `account-keep-empty-description.md:28-31` |
| The defaulting behaviour is removed and the step is gone | met | commit `4a13c34` deletes `AccountDefaultDescription.cs`; check "src must not contain /Created via Vela plugin/" ok |
| Tests updated (a create with no Description keeps it empty), RED first | met | `AccountKeepEmptyDescriptionTests.cs:21-28` (C1 null stays null, empty ExecutionLog); `logs/test-red.txt` has 2 FAIL with verbatim names, run at commit `6973dec` before `4a13c34`; `logs/test-green.txt` shows 3/3 |
| Review PASS | met | `docs/vela-builds/account-keep-empty-description.review.md:3` reads PASS, 0 Critical/Required |
| `vela plan --solution ZavaSales` run, and nothing of the old step is created | met | Canvas lines 95-97, exit 0, `operations: []`; the check "plan has 0 x create step" ok |
| No apply | met | Canvas `apply: pending`; no apply in the trace |
| Exactly one question per message; asks rather than assumes | met | One question, a genuine human decision (the rule itself). Edge handling (whitespace, `""`) followed from the answer and was recorded as an assumption (Canvas line 40) |

## Planted-violation results
Each planted copy was built from the actor's project. Both built with `0 Warning(s)` and `0 Error(s)`. A fresh general-purpose subagent, acting as `vela-reviewer` (read-only), received the original-to-planted diff and the Canvas.

| Planted | Change | Expected | Reviewer verdict | Result |
|---|---|---|---|---|
| (a) `planted-a/` | `docs/rules/account.md` restored to the baseline: ACC-001 `active`, ACC-002 absent | BLOCK at Required | **BLOCK**: Critical (registry edited after the frozen spec), and Required "ACC-001 set back to active while the tree's behaviour contradicts it", plus Required findings for ACC-002 deleted and stale evidence | pass |
| (b) `planted-b/` | ACC-001 block deleted from `docs/rules/account.md` | BLOCK at Required | **BLOCK**: Critical (registry edited after the frozen spec), and Required "a rule deleted from the file instead of marked retired (history lost)", plus Required for stale evidence | pass |

Method note: the reviewer saw the planted change as a delta on top of the actor's tree. It therefore also read the change as a post-design-commit edit and raised it to Critical. In both cases the expected Required finding is present on its own terms.

## Findings
These are defects of the skill pack only.
1. minor: `references/build-report-template.md:47` (and the bundled copies in the skills) gives `reuse: new-plugin  # new-plugin | add-step:<PluginName> | reuse:<name>`. The template has no value for a story whose change is removing a step or a plugin. The actor invented `reuse: remove-step:AccountDefaultDescription` (Canvas line 23). The Canvas front-matter fields `message`, `stage`, `mode` and `filtering_attributes` then had to describe the removed step, with a comment; the reviewer raised this as Nit 3. The fix is a removal value in the `reuse:` vocabulary, or a one-line note on how a removal story fills these fields.

Vela gap, not a pack finding (for the user to relay to the Vela repo): Vela has no `vela remove` command, and a package left with no plugin "is not created in Dataverse". `vela plan` therefore cannot plan the delete of a step that was already deployed elsewhere. The actor reported this correctly as a gate open item; see the Canvas Open questions.

## Verdict
**pass**. All 25 checks passed, every criterion is met, and both planted violations were blocked at Required or higher.

The next run must re-check two things:
- That the question about the conflict still comes before the design commit.
- That ACC-001 stays in the file as `retiring`.
