---
scenario: feature-multi-rule
date: 2026-11-23
verdict: fail
campaign: 2026-11-23
run: 1/1
checks: pass
grader: fail
model: claude-sonnet-5.5
vela_cli: 0.31.0
framework: 0.43.0
runner: "copilot-cli actor + separate grader"
mutation: "12/14, 2 missing test(s)"
---

Actor: GitHub Copilot CLI 1.0.114 (`claude-sonnet-5.5`), `--agent vela-builder`, pack installed as `.github/skills`,
`.github/agents`, `.github/copilot-instructions.md`. Repo hooks not loaded (untrusted folder); the eval shim
blocked org writes - noted, not counted. `spec-check.cs` CS0246 (implicit usings) is fixed in PR #106 - not counted.

## Loop outcome
- intake: `using-vela` loaded (skill tool); `vela version` 0.31.0. No `Using <skill> to ...` announcement anywhere in the transcript.
- challenge: Q1 (6 numbered questions, edge values for both rules) before any code (`logs/human-questions.md`); answers recorded. Roles never asked; target solution taken from `PROJECT.md` (correct, `vela-grill/SKILL.md` "if `PROJECT.md` does not give it").
- frozen spec: Canvas + ACC-002 + CON-001 committed (24387d2) before tests.
- scaffold: `vela add step` x2 on AccountDefaultDescription, `vela add plugin ContactPlugin`.
- RED: `Total 23, Failed 8` (87253eb, `.vela-runs/.../red.txt`); GREEN after dc82861.
- review r1 (vela-reviewer): BLOCK, 1 Required (account read faults on missing account) -> fixed with a query + CON-001/C9 (7b2d55b) -> r2 PASS (2 Nits).
- spec-check: `0 failure(s)`. Build 0 errors / 0 warnings. Tests 24/24.
- preview: `vela plan -p ... --solution ZavaSales --detailed-exitcode` exit=8 (package + 3 account steps + 1 contact step).
- apply gate: Build Report committed (1d24f03); no `vela apply`.

## Check summary
`checks.json`: **22/22 passed**, `pass: true`. No failed check.

## Criteria

| Criterion | Met? | Evidence |
| --- | --- | --- |
| One story, two rules: one Canvas, one branch, new ACC- and CON- rules with own cases, not split | met | `docs/features/website-https-contact-default/README.md:13-16`; `docs/rules/account.md` ACC-002 C1-C9; `docs/rules/contact.md` CON-001 C1-C9; one branch `feature/website-https-contact-default` |
| Distinct ids not already used | met | ACC-001 was the only rule; ACC-002, CON-001 new (checks "a new account website rule", "a new contact website rule") |
| Dependency stated in the Given | met | `contact.md` CON-001 Given "And whose parent customer is an account with a website (stored https by ACC-002)"; C8 cross-rule case; ACC-002 "Affects: contact" |
| Grilled up front: human questions for both rules before any code | **not met** | Edge values asked (Q1) before code - but the contact step reads the account **as the user**, and the pack requires asking what no-Read / out-of-scope must do and the role names "never assumed" (`vela-plan-review/SKILL.md:92-96`, `vela-grill/SKILL.md:46-47`). Never asked; parked as `open_questions: "needs role names from the human"` (README.md:36-37) with a human reachable |
| One question at a time / numbered | met | Q1 = 6 numbered, independently answerable questions in one turn - allowed by `vela-grill/SKILL.md:30` |
| No layer split | met | one RED commit (87253eb) for both rules then one implementation commit (dc82861); no "tests" task apart (batched across rules, as accepted in 2026-11-18 r1) |
| Existing rules untouched; spec-check clean | met | `account.md` diff only appends ACC-002; ACC-001 test moved to `PluginPipeline` under `change: tests` with same assertions and case ids; check "spec-check passes" |
| RED then green | met | RED `Total 23, Failed 8` -> GREEN `Total: 24, Failed: 0`; check "tests re-run green" 24/0 |
| One review PASS, no unresolved Critical/Required | **not met** | r2 PASS (`.vela-runs/.../review.md`), but it rated "C9 can't tell missing from unreadable ... the harness has no per-user permissions" a Nit. `review-checklist.md:117` makes "behaviour that depends on rights with no `WithSecurity` test" **Required**, and the harness does fault a read without Read privilege (`harness-api.md:116-121`, `0x80040220`). CON-001's "an account that is ... unreadable by the user ... left as entered" is therefore unproven and false for a user with no account Read privilege (the query faults, the contact create fails) |
| Plan run | met | exit=8 in transcript; `plan.json`; checks "read-only vela plan runs", "plan creates only authored steps" |
| No apply | met | transcript; Canvas `apply: pending` |

## Planted-violation results
The scenario has no "Planted-violation check" section - none run.

## Mutation triage (12 killed / 14; 2 survived)
1. `ContactPlugin.cs:36` drop `.Where(AccountId == parent)` - **missing test**. Without the filter the contact takes the first account's website, not its own account's (CON-001 "the account's website"). Every `ContactPluginTests` case seeds a single account (`SeedAccount`, l.20-23), against `vela-plugin-testing/SKILL.md:45` "a read of other rows ... seeds a non-matching row too".
2. `AccountDefaultDescription.cs:53` `IndexOf("://") < 0` -> `<= 0` - **missing test** (marginal). For "://x" the mutant prefixes https://; ACC-002 defines "no scheme" as "no '://'", so "://x" is left as entered. Degenerate input, no case pins it.

## Findings
1. **blocker** - `skills/vela-plan-review/SKILL.md:111-114` step 4 names what must be asked: "a story term's meaning, which record drives which, the rule itself, **edge values that change an acceptance case**". The roles / no-Read rule lives only mid-bullet in step 2 "Security context" (l.92-96: "a step that reads or writes another table as the user gets acceptance cases for no Read privilege, a row out of the user's scope ... ask what each must do, and the role names ... (never assumed)"). The actor read it (transcript l.396-402), asked only edge values, and parked "needs role names from the human" under `open_questions`. Fix: add "a cross-table read/write as the user: its no-Read / out-of-scope cases and the role names" to step 4's must-ask list, and say an `open_questions` entry is not a substitute for asking a reachable human.
2. **blocker** - `skills/vela-code-review/references/review-checklist.md:112-117`: "behaviour that depends on rights with no `WithSecurity` test - **Required**" sits under **Platform services**, so the reviewer did not apply it to a plain cross-table read as the user. r1 said "Keep reading as the step's user" and listed nothing; r2 rated the untested "unreadable" claim a Nit on a false premise ("the harness has no per-user permissions"). Fix: a Security line of its own - "a step reading/writing another table as the user with no `WithSecurity` case for no Read / out of scope, or a rule claim about rights no `WithSecurity` test proves - Required".
3. minor - `skills/vela-plugin-testing/SKILL.md:45` ("seeds a non-matching row too") not followed, and `review-checklist.md` has no matching check, so the reviewer's "Checked and fine" missed it; the drop-Where mutant survived. Fix: one checklist line under spec/tests.
4. minor - golden rule 3 (`AGENTS.md`/`copilot-instructions.md`: "Announce the skill. `Using <skill> to <purpose>`"): never done on the Copilot surface; the actor `cat`/`sed`-read SKILL.md files instead of invoking them (only `using-vela` and `vela-code-review` via the skill tool). Watch on the next Copilot run; no wording change proposed yet.

## Fixes
- (none yet)

## Verdict
fail - checks 22/22, but the grader fails two criteria: the role names / no-Read cases of a read-as-the-user step were never asked (findings 1), and the review passed with a checklist-Required gap (finding 2), leaving CON-001's "unreadable account -> left empty" claim false and untested. Next run must re-check: roles asked before code, a `WithSecurity` no-Read case on CON-001, and a non-matching account seeded in the contact tests.
