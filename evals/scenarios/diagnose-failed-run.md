---
scenario: diagnose-failed-run
skills_exercised: [diagnosing-vela]
entity: none
message: none
gotchas_exercised: [skill-defect-not-model-blame, file-and-quote-findings, literal-reading]
org_required: false
---

# Scenario: turn a failed builder run into findings against the skills

## Context
You maintain the Vela skill pack. A builder agent ran the pack on a story and a separate grader failed
the run afterwards. Your job is the pack, not the plugin.

## User story
"The grader failed this run: nothing proves that the API key read from secure configuration reaches the ERP
call - hard-coding the key in the code keeps every test green, and the run's own code review passed. Work out
why the skills let that happen and tell me exactly what to change in them."

## Setup for the run
- `<work>/run` (`sh evals/setup/diagnose.sh <work>`): the run as it was left (Build Report under `ZavaSales/docs/vela-builds/`, source, tests,
  `logs/` with the review verdict and the human questions, `git-log.txt`, `diff-from-scaffold.patch`,
  `actor-report.md`). Generated models, binaries and packages were removed; nothing needs to be built.
- `<work>/pack`: the skill pack **as it was when the run happened** - diagnose against this copy, not
  against any newer version.
- Write your findings to `<work>/findings.md`. No org, no `vela` command needed.

## What the skills must get right
- `diagnosing-vela` is followed: the run is reconstructed from the Build Report's Run trace and logs; each
  finding names a **file in `pack/`**, **quotes** what it said, states what the agent did and the correct path,
  and has a severity (blocker / minor); a verdict closes the list.
- The real causes are found in the pack, not blamed on the model:
  1. `references/review-checklist.md` - the Secrets item only checks where a secret lives (code / unsecure
     config → Critical); nothing requires a test proving a secure-config value reaches the call, so the
     reviewer had no basis to block (**blocker**).
  2. `references/harness-api.md` - the `WithService` recipe shows replacing a service but says nothing
     about the value: a key captured in the real service's constructor inside `ConfigureServices` never
     reaches a `WithService` fake, so the suite cannot see it (**blocker** or minor).
- Skill defects are separated from environment issues; no finding without a file and a quote.

## Success criteria (a clean pass)
1. `findings.md` exists with numbered findings, each: file in `pack/` + quote + what happened + fix + severity.
2. Both causes above are identified (checklist Secrets item; WithService recipe / key not reaching the fake).
3. The diagnosis does not blame the model where the skill's literal text allowed the outcome.
4. A verdict (not ready + top fixes).

## Human answers (evaluator only - never shown to the acting agent)
- Anything asked: "Use the skills' defaults and record it as an assumption."
