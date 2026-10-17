---
scenario: diagnose-failed-run
date: 2026-10-17
verdict: pass
campaign: 2026-10-17b
run: 3/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.26.1
framework: 0.36.0
runner: "campaign actor + separate grader"
---

Evaluator note: the actor run was interrupted once by an API usage limit and resumed. This is not a criterion.
`vela_cli` and `framework` are the diagnosed run's values. The Build Report front-matter and Run trace row 1
(`vela version` → `vela 0.26.1`) give the CLI version, and `Zava.Integrations.csproj:36` gives `Vela.Plugins 0.36.0`.
This scenario needs no `vela` command, and the actor ran none.

## Check summary
`checks.json`: **5/5 passed**, `pass: true`. No check failed. The checks matched review-checklist,
harness-api, WithService, secure.?config and blocker in `findings.md`.

## Loop outcome
- The actor announced `Using diagnosing-vela to analyse the run` (`work/findings.md:3`).
- It diagnosed against `work/pack`. It noted that the bundled copies match `pack/references/`.
- It reconstructed the run from the Canvas/Build Report:
  - AC3 (`account-erp-outbound.md:32`);
  - the Operations line that assigns AC3 to the service tests (`:99`);
  - the Evidence ticks (`:130`);
  - the review (`run/logs/review1/review.md:3,5`).
  It also read the code (`AccountErpNotify.cs` `ConfigureServices`).
- It went beyond the brief and ran a probe on a copy (`work/probe/`), using Mono + xunit 2.9.2:
  - baseline 18/18 green;
  - hard-coded-key mutant still 18/18 green;
  - proposed transport-only `WithService<HttpMessageHandler>` wiring test 19/19 green;
  - the mutant against the fix fails at `Secure_Config_Key_Reaches_The_Erp_Header`.
  The logs are `work/logs/probe-*.txt`. This reproduces the grader's claim and validates the fix.
- It asked the human nothing, which is appropriate: the task is fully specified. `run/logs/human-questions.md` is the
  diagnosed run's file, not the actor's.

## Criteria

| # | Criterion | Met? | Evidence |
| --- | --- | --- | --- |
| S1 | `findings.md` exists with numbered findings, each giving a pack file, a quote, what happened, a fix and a severity | met | `work/findings.md:54-185`: findings 1-7, each with "What it says" (quote), "What the agent did", "Change" and blocker/minor. I checked the quotes verbatim against `pack/references/harness-api.md:197-209`, `review-checklist.md:21-25,116-118`, `vela-test-harness/SKILL.md:24-42`, `vela-plan-review/SKILL.md:46-52,87-91`, `plugin-authoring-api.md:224-228`, `build-report-template.md:130` and `vela-code-review/SKILL.md:12-17`. |
| S2a | Cause 1 found: the checklist Secrets item only checks where the secret lives, with no proof that the value is used (blocker) | met | Finding 3, **blocker** (`findings.md:108-132`). It quotes Secrets `:116-118` as "a static check of the declaration only, not of whether the value is used" and adds "proven used ... Declared but unproven - Required", plus a faked-seams Spec item. |
| S2b | Cause 2 found: the `WithService` recipe says nothing about the value, so a key in the real factory never reaches the fake | met | Finding 1, **blocker** (`findings.md:54-82`): "The factory that is replaced is the code that carries the secure config, so it is never run". It gives a replacement recipe and is backed by the probe. |
| S3 | Does not blame the model where the literal text allowed the outcome | met | Every finding is framed as a pack defect. Finding 1: "What the agent did: exactly that". Finding 2: the agent "cover[ed] every listed category". Finding 4: the plan gate never asks "at which seam" a case is proved. No finding blames the model. |
| S4 | Verdict: not ready + top fixes | met | `findings.md:193-206`: "Not ready", with top fixes 1-3 and a handoff to `writing-vela-skills`. |
| R1 | diagnosing-vela followed: reconstructed from the Build Report/Run trace and logs | met | `findings.md:7-25` cites the Canvas AC3/Operations, `review1/review.md` and the code. Build Report line refs were verified (`:32`, `:99`, `:130`). |
| R2 | Skill defects separated from environment issues | met | `findings.md:187-191`, "Environment notes (not skill defects)": no org; generated models removed, so the probe used a stub. |
| R3 | No finding without a file and a quote | met | All 7 findings have both. |

## Planted-violation results
None: this scenario has no "Planted-violation check" section.

## Findings against the skills
1. minor - `skills/diagnosing-vela/SKILL.md`, Process step 2, says "which skill/reference file and what it said". It
   does not say which copy to cite: the source `references/*.md` or the bundled `skills/*/references/*.md`, which
   carry a generated header and so shift line numbers. This actor worked it out (`findings.md:3-5`, "line numbers
   below are those of `pack/references/`") and pointed the fix at the source plus `scripts/sync-copilot.mjs`. A
   literal reader could cite a bundled copy and get the fix overwritten at the next sync. Correct path: one line in
   step 2: "cite the source file under `references/`; bundled copies are generated".
2. minor - `skills/diagnosing-vela/SKILL.md`, Process step 2, says "what the correct command/API is (grounded in
   source or `--help`)". It does not say to confirm a hypothesised gap empirically, for example by mutating the
   suspected line and re-running the suite. The actor's probe (`work/logs/probe-*.txt`) is what made findings 1-3
   evidence rather than claims. That was the actor's initiative, not the skill's guidance. Correct path: in
   Verification, add "a claimed test gap is shown by a mutant that stays green (and the proposed fix turning it red)
   when the run's code is available".

Neither finding blocks: the skill's literal text was sufficient for this scenario.

## Verdict
**Pass.** Checks passed 5/5 and the grader passed: all criteria are met, and both expected causes were found with the
right severity (blocker). The next run should re-check that the two expected causes are still found without the actor
running a probe. Today the probe is optional diligence, not required by `diagnosing-vela`.
