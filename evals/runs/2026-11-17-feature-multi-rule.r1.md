---
scenario: feature-multi-rule
date: 2026-11-17
verdict: fail
campaign: 2026-11-17
run: 1/1
checks: pass
grader: fail
model: claude-opus-5-5
vela_cli: 0.31.0
framework: 0.43.0
runner: "campaign actor + separate grader"
mutation: "11/14, 3 missing test(s)"
---

## Check summary
`checks.json`: **22/22 passed**, no failed check. The checks cover:
- the Canvas exists and names `websiteurl`, ACC- and CON-;
- a new ACC-0xx website rule and a new CON-0xx website rule in `docs/rules/`;
- https was asked in `logs/human-questions.md`;
- spec-check has 0 failures;
- the build is clean with 0 VELA diagnostics, and the tests re-run green (29/0);
- the package holds the dll;
- solution ZavaSales/zava; the read-only plan runs and creates only authored steps.

## Loop outcome
- intake: `vela version` gives 0.31.0 (trace.md:5). `vela solution show ZavaSales --json` exits 0 (trace.md:6).
- challenge: Q1 to Q4 went to the human one at a time (trace.md:7-10). Canvas + rules were committed in 384ff78 (07:55) before the scaffold in 7a113fe (07:58).
- model: `vela models --roles "Salesperson"` exits 0 (trace.md:12).
- scaffold:
  - 2x `vela add step` on AccountDefaultDescription;
  - `vela add plugin ContactPlugin`;
  - `vela add service ContactWebsiteDefault`;
  - all exit 0 (trace.md:9-12).
- RED: e671df4, 29 total / 13 failed on assertion mismatches (`.vela-runs/website-https/red.txt`). Implementation in 5b4149d, GREEN 29/0.
- review round 1: BLOCK, 1 Critical (a PrivilegeDenied fault was caught inside the PreOperation transaction). Fix order:
  - Q5 to the human;
  - amendment first (ba0b075);
  - RED 29/1 (0422ad3);
  - fix (79d90ce);
  - GREEN 29/0.
- review round 2 (fresh, scoped): PASS (review.md:38-46).
- package: `dotnet build -c Release` gives `artifacts/zava_zava.Plugins.1.0.0.nupkg`. `vela plan --solution ZavaSales --detailed-exitcode` exits 8 (create package + 4 steps). The run stopped at the gate; no `vela apply`.

## Criteria
| Criterion | Met? | Evidence |
| --- | --- | --- |
| One story, two rules: one Canvas, one branch, new ACC- and CON- rules in `rules:`, each with its own cases, not split | met | `docs/features/website-https/README.md:25-28` (ACC-002 add, CON-001 add) and cases :33-55. One branch, `feature/website-https`. ACC-002 is in `docs/rules/account.md:22-54` and CON-001 in `docs/rules/contact.md:3-34`. |
| Distinct ids not already used | met | Base d0dc22c has only ACC-001 (`git diff main -- docs/rules` only adds). The checks "new account website rule (ACC-001 is taken)" and "new contact website rule" pass. |
| **Dependency stated: the contact rule relies on the account's stored (normalised) website, and its Given says so** | **not met** | The CON-001 Given (`contact.md:6-7`) says only "a contact whose Company Name (parentcustomerid) is an account the creating user may read / And the contact's Website is empty". None of the 10 case Givens (`contact.md:15-24`) refers to ACC-002 or to the normalised value. The only links are the Then "as stored on the account" (:9) and a `See also: ACC-002` line (:31). The Canvas R section (:82) names the two rules without stating the dependency. C7 goes the other way and declares the copy independent of normalisation ("legacy http:// copied as stored"). The pack rule (`skills/using-vela/SKILL.md:24`, "a rule relying on another says so in its Given") was not applied. The 2026-11-15 run met this criterion through a case Given that cited ACC-002; this run has no such line. |
| Grilled up front: questions for both rules before any code | met | `logs/human-questions.md` Q1 (ACC) and Q2-Q4 (CON) are in trace.md:7-10, before Canvas commit 384ff78 and scaffold 7a113fe. This time the security and role question (Q3/Q4) came during the grill, not after code (an improvement on 2026-11-15). Q5 was review-driven (trace.md:20). |
| One question at a time; ask vs assume | met | Each Q is one decision, multiple-choice, with at most one ride-along edge. The deferred answers are recorded as assumptions + open questions (Canvas :62-76) and as Blocking decision 2 (:177-180). |
| No layer split: RED then implementation per rule, no separate "tests" task | met | e671df4 (RED, both rules) then 5b4149d (implementation). There is no tests-only task in the plan. RED/GREEN was batched across both rules in one cycle rather than one cycle per rule (same as 2026-11-15, accepted). |
| Existing rules untouched; spec-check clean | met | `git diff main -- docs/rules/account.md` only appends ACC-002. The ACC-001 tests moved to PluginPipeline with the same values and assertions (`change: tests`, Canvas :28). Check "spec-check passes": 0 failures. |
| RED then green | met | red.txt `Total: 29, Failed: 13`; green2.txt `Total: 29, Failed: 0`. The review-fix RED came before the fix commit (0422ad3, then 79d90ce). |
| One review PASS | met | `.vela-runs/website-https/review.md:5` round 1 BLOCK, :38-46 round 2 PASS, no unresolved Critical/Required. |
| Plan run | met | `.vela-runs/website-https/plan.json`, trace.md:32 exit 8, check "read-only vela plan runs". |
| No apply | met | `vela apply` appears only as Gate text. The evaluator's check-plan still shows the package + steps as `create`. |

## Planted-violation results
None: the scenario has no "Planted-violation check" section.

## Mutation triage (11 killed / 14, 3 survived)
1. `AccountDefaultDescription.cs:80`, `IndexOf("://") >= 0` changed to `> 0`. **Missing test (low value).** The two versions differ only for a value that starts with `://` (e.g. `"://zava.com"`):
   - the original leaves it as entered;
   - the mutant stores `https://://zava.com`.

   ACC-002 makes "no scheme (no '://')" the criterion (`account.md:28`), so the behaviour is declared. No case covers `://` at index 0. The edge is degenerate.
2. `ContactWebsiteDefault.cs:54`, `parent == null || LogicalName != account` changed to `&&`. **Missing test.**
   - With a contact parent (C5), the mutant runs a query that returns no row, so the website stays empty: an equivalent outcome.
   - With `parentcustomerid` **sent as null** on Create (FilterOn fires on the sent column), the mutant throws a NullReferenceException and refuses the create. The rule says "no parent leave[s] it empty" (`contact.md:10-11`).

   C6 covers only a create that does not send the column (`ContactPluginTests.cs:93`). The sent-as-null case is untested.
3. `ContactWebsiteDefault.cs:61`, the `Where(AccountId == parent.Id)` filter dropped. **Missing test (significant).** The mutant copies the website of whichever account comes first. Every test seeds exactly one account (`ContactPluginTests.cs:21`, `:154`), so none can see that the wrong account's website is copied. CON-001 says "its parent account's website".

## Findings against the skills
1. **blocker** - `skills/using-vela/SKILL.md:24` says the dependency rule only in a parenthetical: "every rule in `rules:` with its own cases (a rule relying on another says so in its Given)".
   - The rules-registry template in `references/build-report-template.md:191-225` (all copies) shows only an `Affects:` / `See also` cross-table line and no dependent-rule Given.
   - `vela-plan-review/SKILL.md:101-104` (acceptance cases, `rules:`) does not repeat the instruction.
   - What happened: the actor followed the template (`See also: ACC-002`) and wrote a CON-001 Given that does not mention the account's normalised website. It also declared C7 "copied as stored", which decouples the contact rule from ACC-002 without saying the rule depends on it.
   - Fix: the registry template and the plan-review step need one line plus an example, e.g. "Given a parent account whose Website is stored per ACC-002 (https)".

   This is why the run fails.
2. minor - `skills/vela-plugin-testing/SKILL.md:23-46` (Coverage) has no bullet for a handler that **reads a related row by key**: seed a second, unrelated row, so that a missing or wrong key filter is caught. Mutant 3 survived because every test seeds a single account. Add: "a lookup/query by key: seed a decoy row of the same table with a different value."
3. minor - `skills/vela-plugin-testing/SKILL.md:33` requires "not sent vs cleared (sent as null)" on **Update** only. On Create with a `FilterOn` lookup, "sent as null" also fires the step. That case was not written, and mutant 2 survived. Extend the bullet to Create when the filtered column can be sent as null.
4. minor (Vela harness, for the Vela repo, not the pack) - `InMemoryOrganizationService` lets a plugin catch a PrivilegeDenied fault inside a PreOperation transaction and continue. Dataverse aborts the transaction instead. The reviewer caught this (review.md:9-11) and noted that `dataverse-gotchas.md` does not cover it. A `dataverse-gotchas.md` line ("a failed service call inside the transaction aborts the save even when caught") would let the plan step see it before code.

## Verdict
**fail**: checks pass 22/22, but the grader fails one criterion, "Dependency stated" (the CON-001 Given does not state that it relies on ACC-002's stored, normalised website). Every other criterion is met: grill up front including security and roles, RED then green, review BLOCK then PASS, plan exit 8, no apply.

The next run must re-check:
- that a dependent rule's Given names the rule it relies on;
- that the contact tests seed a decoy account.
