---
scenario: feature-multi-rule
date: 2026-11-02
verdict: pass
campaign: 2026-11-02
run: 2/2
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.28.0
framework: 0.41.2
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **22/22 passed**. No check failed.

## Loop outcome
- intake: `vela version` → 0.28.0; `vela solution show ZavaSales --json` → exit 0 (`zava`) (trace 1-2).
- challenge: Q1 (account https) and Q2 (contact copy), one per entry with options, in `work/logs/human-questions.md`
  (file mtime 01:14:37). Then the Canvas and rules ACC-002 and CON-001 were committed (`b4de63c`, 01:16:39), before any
  scaffold (`a87c871`, 01:17:54).
- model: `vela models --verify` → exit 0. scaffold: `vela add step` x2 on AccountDefaultDescription,
  `vela add plugin ContactPlugin`, `vela add service ContactWebsiteDefault`, `vela add test`. All exit 0.
- RED, first run: Total 26, Failed 15. 3 ACC-001 regression tests broke with "registers several steps matching entity
  'account'". The actor did not edit ACC-001's tests. It moved ACC-002 to a new class `AccountWebsiteHttps`
  (Canvas Sync log 1) and reran RED: Total 26, Failed 12, all "Strings differ" (`logs/red.txt`).
- GREEN: Total 26, Failed 0 (`logs/green.txt`). A mutation check (reading as SYSTEM) made CON-001/C7 fail; the
  actor reverted it.
- spec-check `--base main` → 0 failure(s). The isolated vela-reviewer returned PASS with 0 Critical, 0 Required and
  4 Nits (`.vela-runs/website-https-contact-default/review.md`).
- plan: `vela plan -p artifacts/zava_zava.Plugins.1.0.0.nupkg --solution ZavaSales --detailed-exitcode` → exit 8
  (create package + 4 steps; 2 rank-collision diagnostics, both reported at the gate). No apply.

## Criteria
| Criterion | Met? | Evidence |
| --- | --- | --- |
| One story, two rules: one Canvas, one branch, new ACC- and CON- rules in `rules:`, each with its cases, not split | met | Only one new Canvas, `docs/features/website-https-contact-default/README.md` (`account-default-description` is the baseline). `rules:` lines 27-29 list ACC-002 add and CON-001 add. Cases ACC-002/C1-C9 and CON-001/C1-C8 (lines 32-49). One branch, `feat/website-https-and-contact-default`. |
| Distinct ids not already used | met | `main` had only ACC-001; `contact.md` is new. Checks pass: the ACC-0(0[2-9]…) regex and the CON- regex. |
| Dependency order: account rule built first | met (weak) | Canvas line 17: "built in dependency order: ACC-002, then CON-001". Account steps were scaffolded first (trace 5-6, then 7-8). CON-001 copies the stored value (rule: "https under ACC-002"). Caveat: RED and implementation for both rules were each done in one step (trace 13-14, commits `2a7f10b` and `9d3596e`), so the build order inside the implementation cannot be seen in the artifacts (finding 1). |
| Grilled up front, questions for both rules before any code | met | Q1 and Q2 are in `logs/human-questions.md`, before trace step 5 and commit `a87c871`. Each entry asks one question with options and logs the answer. The deferred "other scheme" case is recorded as an assumption and an open question. |
| No layer split (RED then implementation, no separate tests task) | met | `2a7f10b` holds the RED tests for both rules (seen failing, `red.txt` Failed 12). `9d3596e` implements both. There is no service-only or tests-only task, and every rule's tests were red before its code. |
| Existing rules untouched; spec-check clean | met | `git diff main -- docs/rules` only appends ACC-002 and adds contact.md. ACC-001 code and tests: 0-line diff vs main. Check "spec-check passes" → 0 failure(s). |
| RED then green | met | `logs/red.txt` Total 26 Failed 12 → `logs/green.txt` Total 26 Failed 0. Check "tests re-run green" 26/0. |
| One review PASS | met | `review.md`: "Verdict: PASS", no Critical or Required. |
| Plan run, no apply | met | trace 20, exit 8; `.vela-runs/.../plan.json`; check "read-only vela plan runs". No `vela apply` in the logs or trace. |

## Planted-violation results
None. This scenario has no "Planted-violation check" section.

## Findings against the skills
1. minor - `skills/using-vela/SKILL.md:21` says "every rule in `rules:` with its own cases, built in dependency
   order", but it does not say what that order looks like in the loop or what evidence shows it (a RED → green
   cycle per rule, a commit per rule, or one trace row per rule). The actor wrote RED tests for both rules in one
   commit (`2a7f10b`) and implemented both in one commit (`9d3596e`, trace 14 "implement"). The claim "ACC-002,
   then CON-001" in the Canvas (line 17) therefore cannot be checked from the artifacts. The Canvas also has no field
   for an intra-story rule dependency; the actor put it in a comment on the `entity:` line.
2. minor - the pack gives no guidance for a table whose existing plugin class gains a second step with the same
   message, stage and mode (differing only by filter). In r1 the actor set `Context.OwningExtension` by hand in the
   ACC-001 tests. In r2 the actor added a second class on account (`AccountWebsiteHttps`), which breaks the
   Canvas norm "One plugin class per table" (justified in Sync log 1, review Nit 1). The two runs reached different
   structures for the same story.
   Observation for the Vela team, not a skill fix (see "dont compensate Vela gaps"): the harness cannot pick
   between steps of one class that differ only by filter.

Not skill defects (actor): during the mutation check the actor briefly wrote a backup file to `/tmp`, outside the
work folder. It deleted the file right away.

## Fixes
- Findings 1-2: open.

## Verdict
pass. Checks 22/22, and the artifacts show every criterion met. Unlike r1, this run kept one story, one Canvas and
one branch. The next run must re-check that the dependency order can be verified from the artifacts (finding 1).
