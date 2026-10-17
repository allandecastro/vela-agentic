---
scenario: diagnose-failed-run
date: 2026-10-17
verdict: pass
campaign: 2026-10-17b
run: 1/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.26.1
framework: 0.36.0
runner: "campaign actor + separate grader"
---

## Loop outcome
- Meta scenario (diagnosing-vela); no org, no vela command required. The actor announced
  `Using diagnosing-vela to analyse the run` (`work/findings.md:3`), diagnosed against `work/pack` (the
  run-time pack) and reconstructed the run from the Build Report's Run trace
  (`run/ZavaSales/docs/vela-builds/account-erp-outbound.md:150`) -> `findings.md` section 1.
- Extra (not required): it reproduced the defect in a probe scaffold (`work/verify/Probe`, Mono + xunit
  `-parallel none`): baseline 18/18 green (`logs/probe-baseline.txt`), hard-coded-key mutant still 18/18
  green (`logs/probe-mutant-hardcoded.txt`), proposed transport-fake wiring test RED against the mutant
  (`logs/probe-wiring-red.txt`: Expected "key-from-secure-config-91a" / Actual "HARDCODED-KEY") and
  19/19 green against the correct code (`logs/probe-wiring-green.txt`).
- No questions to the human (`work/logs/human-questions.md` absent; actor report: "No questions for the
  human"). Nothing in the task required one. No pack edits, no git in the pack, no `vela apply`.
- Vela CLI 0.26.1 (run's Build Report line 6 and trace row 1; installed `vela version` = 0.26.1);
  Vela.Plugins / Vela.Testing 0.36.0 (`run/ZavaSales/src/*/Zava.*.csproj:36`).

## Deterministic checks
5/5 passed (`checks.json`, pass: true). No failed check.

## Criteria
| Criterion | Met? | Evidence |
| --- | --- | --- |
| diagnosing-vela followed: run reconstructed from the Run trace + logs | met | `findings.md:6-30` (trace steps, commits 2117636/1f6de50, review PASS, plan exit 8; cites `run/logs/review1/review.md`) |
| Each finding: file in `pack/` + quote + what happened + correct path + severity (blocker/minor) | met | F1-F6, `findings.md:78-189`. Quotes checked against the pack copy: `harness-api.md:197-209`, `plugin-authoring-api.md:187-189,224-228`, `review-checklist.md:21-25,116-118`, `vela-test-harness/SKILL.md:24-42,98-104`, `build-report-template.md:131` - all verbatim |
| Verdict closes the list | met | `findings.md:200-215` "Not ready" + ordered top fixes |
| Cause 1: review-checklist Secrets item checks only where the secret lives; no test-proof requirement (blocker) | met | F4 blocker, `findings.md:141-163`, quotes the Secrets item and adds "a pipeline test proves the secure-config value is what is used ... missing - Required" |
| Cause 2: harness-api `WithService` recipe silent on the value; the key captured in the `ConfigureServices` factory never reaches the fake (blocker or minor) | met | F1 blocker, `findings.md:78-102`: "the factory lambda ... is never executed"; "it bypasses the factory, so it proves nothing about what the factory passes in" |
| Skill defects separated from environment issues; no finding without file + quote | met | "Not a defect (checked)" `findings.md:191-198` (no env issue, no Vela/CLI gap); every finding F1-F6 has file:line + quote |
| SC1: `findings.md` with numbered findings, each complete | met | F1-F6 |
| SC2: both causes identified | met | F4 (checklist Secrets), F1 (+F2) (WithService / factory) |
| SC3: does not blame the model where the literal text allowed it | met | `findings.md:8-11` "No command was wrong and no step was skipped ... that came from the skills"; F1 "What the agent did: exactly that" |
| SC4: verdict (not ready + top fixes) | met | `findings.md:200-210` |
| Ask-vs-assume / one question at a time | n/a (met) | no ambiguity required a question; none asked |

All criteria met. The actor's report agrees with the artifacts (every claim it makes is backed by a file
in `work/`).

## Planted-violation results
None - the scenario has no "Planted-violation check" section.

## Findings against the skills
None. The diagnosing-vela skill led to a complete, quoted, severity-rated diagnosis on the first run; its
severity rule ("a missing rule that let a quality gate pass ... is a blocker", current root
`skills/diagnosing-vela/SKILL.md:28-29`) was applied correctly (F3/F4 blocker; F5 minor justified as the
advisory plan gate). Observation only (not a defect): the actor went beyond "nothing needs to be built" with a
mutation probe; this strengthened the evidence and did not touch `run/` or the pack.

## Fixes
- n/a for this run. The diagnosed pack defects (F1-F6) are for the pack as of the failed run; the current root
  `references/harness-api.md:213` already carries part of the F1 fix (pass the key through the interface or
  make the transport the replaced service) - the next iteration should confirm F2-F6 are covered too.

## Verdict
pass - checks 5/5 and every grader criterion met. Next run must re-check that both causes are still found
and rated blocker, and that findings stay quoted against `pack/`, not the newer root pack.
