---
scenario: feature-multi-rule
date: 2026-11-17
verdict: fail
campaign: 2026-11-17
run: 2/2
checks: pass
grader: fail
model: claude-opus-5-5
vela_cli: 0.31.0
framework: 0.43.0
runner: "campaign actor + separate grader"
mutation: "19/25, 4 missing test(s)"
---

## Check summary
`checks.json`: **22/22 passed**, no failed check.
- Canvas `docs/features/websites-https/README.md` names `websiteurl`, ACC- and CON-.
- New ACC-002 website rule in `docs/rules/account.md` and new CON-001 website rule in `docs/rules/contact.md`.
- https asked in `logs/human-questions.md`.
- spec-check: 0 failures.
- Build clean, 0 VELA diagnostics, tests re-run green (33/0).
- Package holds `zava.Plugins.dll`. Solution ZavaSales/zava.
- Read-only plan runs; it creates only authored steps (package + 3 AccountDefaultDescription steps + 1 ContactPlugin step).

## Loop outcome
- intake: `vela version` gives 0.31.0 (trace.md:5).
- challenge: Q1 (ACC rewrite vs refuse) and Q2 (CON lookup + timing) asked one at a time (trace.md:6-7). Canvas + rules committed in 70d5727 (12:54:43). That design commit records "Role names were not given (human deferred)" and lists "Real security roles of contact creators" under open_questions. **No role question was asked here.**
- scaffold/model:
  - `vela solution show` exits 0;
  - `vela models --verify` exits 0;
  - `vela add step AccountDefaultDescription` x2 and `vela add plugin ContactPlugin` (trace.md:9-12, dde3949 12:55:20).
- RED: 632570e, Total 31 / Failed 12 (`red2.log`). Implementation in cb6c7e2, GREEN 31/0.
- review:
  - Round 1 void (the actor sent a placeholder in the dispatch).
  - Round 2 BLOCK: 1 Critical (a `://` after the host was taken for a scheme), 2 Required (DRY; hand-built role in C10/C11), 6 Nits (`review.md:7-16`).
  - Fix:
    - RED repro bc384ed (33/2), then fix 884e330.
    - **Q3 (security roles) asked only now** (trace.md:20; the Canvas Sync log at :119 says "Review round 2 finding 3 (Required): Q3 asked").
    - `vela models --roles "Salesperson"`.
    - C10/C11 rule amendment (1dabe08, recorded in `amendments:`).
  - Round 3 scoped: PASS (`review.md:18-21`).
- package + preview: `dotnet build -c Release` gives `artifacts/zava_zava.Plugins.1.0.0.nupkg`. `vela plan --solution ZavaSales --detailed-exitcode` exits 8: create package + 4 steps, 2 rank diagnostics recorded. Stopped at the gate; no `vela apply`.

## Criteria
| Criterion | Met? | Evidence |
| --- | --- | --- |
| One story, two rules: one Canvas, one branch, new ACC- and CON- rules in `rules:` with their own cases, not split | met | Canvas `README.md:24-26` (ACC-002 add, CON-001 add), cases :31-57. Single branch `feature/websites-https`. `account.md:22-55` and `contact.md:3-36`. |
| Distinct ids not already used | met | The base has only ACC-001. `git diff main -- docs/rules/account.md` removes no line. Checks "new account website rule (ACC-001 is taken)" and "new contact website rule" pass. |
| Dependency stated (the contact rule's Given relies on the account's normalised website) | met | `contact.md:7`: "And whose Company Name (parent customer) is an account with a Website - already https by ACC-002". Case Givens C1-C4 and C8 say "(https by ACC-002)", and `account.md:52` says "Affects: contact (CON-001 ...)". The r1 finding is fixed. |
| **Grilled up front: the human questions for both rules come before any code** | **not met** | Q1 and Q2 precede the design commit 70d5727. **Q3, the CON-001 security-role question, was asked after implementation (cb6c7e2, 12:57) and after review round 2** (trace.md:13 → :16; Canvas Sync log :119; commit 1dabe08 at 13:03). The answer rewrote rule cases CON-001/C10 and C11 mid-build (`amendments:` :29-30). At design time the actor knew the question was open: 70d5727 says "Role names were not given (human deferred)" and puts "Real security roles of contact creators" under open_questions. The human was never asked; the actor read the catch-all "anything else → defaults" in Q2's answer as a deferral. The actor report (`actor-report.md:8-11`) lists Q3 under "Challenge", as if asked up front, which the artifacts contradict. |
| One question at a time; ask vs assume | met (with the exception above) | Each Q is one decision, multiple choice; Q1 has one ride-along edge. Deferred edges (ftp scheme, C12 behaviour) are recorded as assumptions and open questions (Canvas :63-75) and as Gate blocking decision 2. The role-name question was assumed away instead of asked; see the criterion above. |
| No layer split: RED then implementation per rule, no "tests" task apart | met | 632570e RED (both rules), then cb6c7e2 implementation. RED/GREEN was batched across both rules in one cycle, accepted as in earlier runs. |
| Existing rules untouched; spec-check clean | met | ACC-001 text unchanged (diff only appends). ACC-001 tests moved to PluginPipeline with the same data and assertions (`change: tests`, Canvas :27). Check "spec-check passes": 0 failures (`spec-check2.log`). |
| RED then green | met | `red2.log` Total 31 Failed 12. Review-fix RED `red.log` 33/2 (bc384ed) before fix 884e330. `green4.log` 33/0. |
| One review PASS | met | `review.md:18-21` round 3 PASS, no unresolved Critical/Required. |
| Plan run | met | `.vela-runs/websites-https/plan.json`; trace.md:26 exit 8; check "read-only vela plan runs". |
| No apply | met | `vela apply` appears only as Gate text; `apply: pending`. |

## Planted-violation results
None: the scenario has no "Planted-violation check" section.

## Mutation triage (19 killed / 25, 6 survived)
1. `AccountDefaultDescription.cs:75` `separator > 0` → `>= 0`. **Missing test (low value).** For `"://zava.com"` the original stores `https://://zava.com`. The mutant calls `IsScheme("")`, and `candidate[0]` throws `IndexOutOfRangeException`, which refuses the save. ACC-002 says an address without a scheme gets `https://` (`account.md:29`). No case starts with `://`.
2. `:89` `c < 128` → `c <= 128`. **Equivalent.** U+0080 is a control character, so `char.IsLetterOrDigit` is false either way and the result is the same.
3. `:89` `... || c == '-' || c == '.'` → `c == '-' && c == '.'` (a `.` is no longer a scheme character). **Missing test.** `evil.com://x` (or `a.b://x`) becomes `https://evil.com://x` instead of `https://x`. Round 3 judged `evil.com://x -> https://x` correct per C6 (Canvas :141, `review.md:20`), but no test pins it.
4. `:89` `c == '+' || c == '-'` → `&&` (no `+` or `-` in a scheme). Folded into survivor 3 as **missing test (low value)**: `svn+ssh://x` / `x-y://x` become `https://svn+ssh://x`. C6 declares "another scheme becomes https://x", but no case uses a scheme with `+` or `-`.
5. `:89` `c == '.'` → `c != '.'`. **Missing test (significant).** Under the mutant every ASCII character except `.` counts as a scheme character, including `/ ? #`. The Critical fix's repro data all have a dot before the first `/` (`zava.com/go?u=http://evil.com`, `zava.com/#http://x`, `AccountDefaultDescriptionTests.cs:59-60`), so the regression of the round-2 Critical is invisible for a dotless host: `localhost/go?u=http://evil.com` becomes `https://evil.com`. The repro does not prove the fix in general.
6. `ContactPlugin.cs:29` `parent == null || parent.LogicalName != account` → `&&`. **Missing test.** Same survivor as r1 #2:
   - with a contact parent, the mutant queries an account by the contact's id, gets no row, and the outcome is equivalent;
   - with ParentCustomerId **sent as null** on Create (FilterOn fires on a sent column), the mutant throws a NullReferenceException and refuses the create. The rule says "Company Name ... empty → left as entered" (`contact.md:10`).

   C7 covers only "not sent" (`ContactPluginTests.cs:94`).

Survivors 3 and 4 are one gap (the scheme character set), counted once: **4 missing tests** (1, 3/4, 5, 6) and 1 equivalent (2).

r1's decoy-row finding is fixed: the contact tests seed a second account (`ContactPluginTests.cs:24-26`), and the "drop Where" mutant is killed.

## Findings against the skills
1. **blocker** - `skills/vela-grill/SKILL.md:44-47` (Security context bullet): "Security context: calling user (default) or elevated? If the human defers to the defaults while you recommended otherwise, apply the default and list your recommendation as an open question at the gate. When the behaviour depends on the user's rights, also ask which security roles those users hold (exact names ...)".

   **Confirmed from the run trace and the human-questions log.** The role question was not asked during the grill:
   - `human-questions.md` has only Q1 and Q2 before code;
   - Q3 is review-driven (trace.md:13-16, Canvas Sync log :119).

   The actor did see that the behaviour depends on rights. At design time it wrote CON-001/C10-C12 as WithSecurity cases, recorded "Role names were not given (human deferred)", and listed roles as an open question (70d5727 Canvas :55, :58, :61). The human was never asked; the only "deferral" was the catch-all "Anything else not covered: use the skills' defaults" appended to Q2's answer.

   Why the wording failed to trigger the question:
   - (a) The bullet's deferral clause ("If the human defers to the defaults ... apply the default and list ... as an open question at the gate") sits right before the role sentence. The actor applied it to the role names as well and turned a mandatory question into a Gate open question.
   - (b) The role ask is an "also ask" hanging off the security-context question. When that question was skipped (answered by default), its "also" went with it.
   - (c) The skill never says that role names have **no default**. For user-visible message languages it does say so: ":48-49 never assumed; no default covers it". So "use the defaults for anything else" looked like a valid answer.
   - (d) The stop condition at :53 ("Stop once every branch that changes the registration or the acceptance cases is resolved") let an assumption count as "resolved".
   - Contributing: `skills/vela-plan-review/SKILL.md:92-96` (Security context) asks what no-Read, out-of-scope and denied-write must do, but does not repeat "ask the role names". The role names are only in the Platform-services bullet at :89-90.
   - Contributing: `vela-plugin-testing/references/harness-api.md:121` ("A hand-built role only for a deliberately missing privilege") was stretched into hand-built roles for C10/C11 while the names were "deferred".

   Suggested fix: make the role question its own grill item, not an "also": "Behaviour depends on rights → ask the role names; no default covers them, and a 'defaults for the rest' answer never answers a question you did not ask". Repeat it in the plan-review Security context bullet.

   This is why the run fails: the answer amended CON-001/C10 and C11 after the code was written.
2. minor - `skills/vela-plugin-testing/SKILL.md:33`: "on **Update**: column **not sent** vs **cleared** (sent as null) - different cases." This is still Update-only (r1 finding 3, not fixed). On Create, a FilterOn lookup sent as null also fires the step; the case was not written and mutant 6 survived again. Extend the bullet to Create when the filtered column can be sent as null.
3. minor - `skills/vela-plugin-testing/SKILL.md` (Coverage) and `skills/vela-code-review` (fix order) say nothing about how wide a bug repro must be. The Critical's RED repro used only dotted hosts, so the parser's real rule ("no `/ ? #` in a scheme") is unpinned and mutant 5 survived. Suggested line: a repro for a parsing/matching bug covers the input class, not the one reported value (here, a dotless host too).
4. minor - no skill asks for tests of a hand-written parser's character class. Survivors 1, 3 and 4 show that the RFC 3986 scheme rule (letters, digits, `+ - .`, and a non-empty scheme) is implemented but untested. This is low value; it overlaps finding 3 and needs no separate wording if finding 3 says "the input class".

## Fixes
- (pending)

## Verdict
**fail**. Checks pass 22/22. The grader fails one criterion, "Grilled up front": the CON-001 security-role question was asked only after review round 2, and its answer amended two rule cases mid-build. Every other criterion is met:
- one Canvas with ACC-002 + CON-001;
- the dependency Given is stated (r1 blocker fixed);
- the decoy account is seeded (r1 minor fixed);
- RED then green;
- review BLOCK, then PASS;
- plan exit 8;
- no apply.

The next run must re-check:
- that the role names are asked during the grill even when the human answered "defaults for the rest";
- the Create sent-as-null case;
- a dotless-host repro for the scheme parser.
