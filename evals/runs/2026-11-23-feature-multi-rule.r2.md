---
scenario: feature-multi-rule
date: 2026-11-23
verdict: fail
campaign: 2026-11-23
run: 2/2
checks: pass
grader: fail
model: claude-sonnet-5.5
vela_cli: 0.31.0
framework: 0.43.0
runner: "copilot-cli actor + separate grader"
mutation: "9/9, 0 missing test(s)"
---

Actor: GitHub Copilot CLI 1.0.114 (`claude-sonnet-5.5`), `--agent vela-builder`, pack installed as `.github/skills`,
`.github/agents`, `.github/copilot-instructions.md`. Repo hooks not loaded (untrusted folder); the eval shim
blocked org writes. Both are noted and do not count against the run.

## Loop outcome
- intake: `using-vela` loaded with the skill tool (transcript l.57). No `Using <skill> to ...` announcement.
- challenge: `vela-plan-review` loaded with the skill tool (l.287). Q1 had 5 numbered questions on edge values, the meaning of "its account", legacy http and filters (`logs/human-questions.md`). It went to the human before any code and the answers were recorded. **Roles and the denied-read outcome were not asked.** The Canvas recorded them as an assumption instead: "a denied read surfaces the platform error" (README.md:30).
- frozen spec: Canvas + ACC-002 + CON-001 committed (196f801) before the tests.
- scaffold: `vela add step` x2 on AccountDefaultDescription, `vela add plugin ContactWebsitePlugin` (exit 0).
- RED: `Total 25, Failed 10` (0d63002). GREEN: `Total 26, Failed 0`.
- review r1 (vela-reviewer): BLOCK, 2 Required (malformed .gitignore; the denied account read had no `WithSecurity` test). Fixed by 004a48f (CON-001/C9 added under `amendments:`). The scoped r2 returned PASS (1 Nit).
- spec-check: `0 failure(s)`. Release build: 0 errors, 0 warnings.
- preview: `vela plan -p artifacts/zava_zava.Plugins.1.0.0.nupkg --solution ZavaSales --detailed-exitcode` returned exit 8 (4 creates).
- apply gate: Build Report committed (9a7da7c). `apply: pending`, and `vela apply` was never run.

## Check summary
`checks.json`: **22/22 passed**, `pass: true`. No check failed.

## Criteria

| Criterion | Met? | Evidence |
| --- | --- | --- |
| One Canvas, one branch, new ACC- and CON- rules, each with its own cases, not split | met | `docs/features/website-https-contact-default/README.md:14-16`; `account.md` ACC-002 C1-C8; `contact.md` CON-001 C1-C9; one branch |
| Distinct ids not already used | met | ACC-002 and CON-001 are new; ACC-001 was the only existing rule (checks "a new account website rule" and "a new contact website rule") |
| Dependency stated in the Given | met (weakly) | `contact.md:6-8`: the Given has "parent customer is an account with a website" and the Then has "as ACC-002 stores it". Canvas R:45: "CON-001 relies on ACC-002" |
| Grilled up front: the human questions for both rules before any code | **not met** | Q1 came before the code and covered edge values for both rules. But the contact step reads the account **as the user**, and `vela-plan-review/SKILL.md:92-96` and `:111-115` require that the role names and the no-Read, out-of-scope and denied outcomes be **asked, never assumed**. They were not asked. They were recorded as an assumption (README.md:30), and the scenario's scripted roles answer ("Salesperson") was never triggered |
| One question at a time / numbered | met | Q1 had 5 numbered, independently answerable questions, which `vela-grill` allows |
| No layer split | met | RED commit for both rules, then the implementation. No separate "tests" task |
| Existing rules untouched; spec-check clean | met | ACC-001 tests moved to `PluginPipeline` under `change: tests`. Check "spec-check passes" |
| RED then green | met | RED 25/10 failed, then GREEN 26/0 |
| One review PASS, no unresolved Critical/Required | met | review.md: r1 BLOCK (2 Required) closed, r2 PASS |
| Plan run, no apply | met | exit 8. Checks "read-only vela plan runs" and "plan creates only authored steps". `apply: pending` |

## Planted-violation results
The scenario has no "Planted-violation check" section, so none were run.

## Mutation triage
9 killed out of 9, with no survivors. The decoy account seeded in `ContactWebsitePluginTests.Pipeline` (a non-matching row) kills the lookup mutants.

## Status of the fixes since r1
- **#107** (the builder loads each named skill whole): **partly held.** `using-vela`, `vela-plan-review`, `vela-plugin-testing` and `vela-plugin-authoring` were loaded with the skill tool. `vela-scaffold` was read with `cat ... | head -80` (105 lines; l.367), and `vela-code-review` with `sed -n 1,80p` (94 lines; l.1537). Both reads were truncated.
- **#109** (plan-review step 4 lists roles and denied outcomes as human decisions): **did not hold**. See finding 1.
- **#110** (review-checklist Security line; seeding a non-matching row is Required): **held.** The reviewer rated the untested denied read **Required** (r1 had rated it a Nit). The tests seed a decoy account and the mutation score is 9/9.
- **#106** (spec-check compiles inside a project): **held.** `spec-check: 0 failure(s)` in the actor run and in checks.json.

## Findings
1. **blocker** - `skills/vela-plan-review/SKILL.md:111-113`. The roles requirement sits only inside step 4's parenthetical list: "(a story term's meaning, which record drives which, the rule itself, **edge values that change an acceptance case**, the users' roles and what a denied read or write must do)". The step-2 security bullet starts with "default is the step's user (`ctx.Service`)" (l.92). The actor read that as a default it could take ("Account read with ctx.Service (the step's user); no SYSTEM; a denied read surfaces the platform error", README.md:30). Its Q1, headed "Decisions only you can make", had no roles item. Proposed fix: make the trigger concrete and separate. "A step that reads or writes another table as the user → Q: the role names of those users, and what no-Read / out-of-scope / denied write must do. Its own numbered question, never an assumption, even though `ctx.Service` is the default identity." The trigger in step 4 should be the Canvas's own Retrieve, not a list item.
2. minor - `skills/vela-code-review/references/review-checklist.md:118-122`, the Security line. It requires *a* `WithSecurity` test, so one hand-built no-Read case satisfied it. Two gaps are not flagged:
   - (a) no out-of-scope case (`0x80048306`), which `vela-plan-review/SKILL.md:94` lists.
   - (b) a rights outcome recorded as an `assumption` with a human reachable.

   The reviewer passed both. Proposed fix: one clause, "each of no Read / out of scope / denied write that applies has a case, and its outcome is a recorded human decision - Required".
3. minor - The builder only partly loads skills whole (#107). `vela-scaffold` and `vela-code-review` were read truncated with `head`/`sed -n 1,80p` on the Copilot surface. The builder's instruction (`agents/vela-builder.agent.md:11-12`) did not stop a shell read. Watch this on the next run.
4. minor - Golden rule 3 ("Announce the skill") was still never followed on Copilot. This carries over from r1, finding 4.

## Verdict
fail. Checks 22/22, mutation 9/9 and the review gate now pass (#110 and #106 held). The grader fails "grilled up front": the role names and the denied-read outcome of a read-as-the-user step were assumed, not asked (#109 did not hold, finding 1). The next run must check that Q1 contains a roles / denied-read question, and that `vela models --roles` is used for the `WithSecurity` case.
