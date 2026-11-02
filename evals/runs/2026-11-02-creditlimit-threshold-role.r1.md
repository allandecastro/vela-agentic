---
scenario: creditlimit-threshold-role
date: 2026-11-02
verdict: pass
campaign: 2026-11-02
run: 1/1
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.28.0
framework: 0.41.2
runner: "campaign actor + separate grader"
---

## Checks
26/26 passed (`checks.json`). No failed check.

## Loop outcome
- INTAKE/CHALLENGE: 5 questions, one per entry, each with options (`work/logs/human-questions.md` Q1-Q5); deferred
  answers (Q3 currency, Q4 location) were recorded as assumptions / open questions (Canvas lines 52-63).
- MODEL: `vela models --entities role,systemuserroles,teamroles,teammembership --roles "Sales Manager,System Administrator"` then `+Salesperson` into `zava.Shared` (exit 0).
- TEST RED: `Total: 19, Errors: 0, Failed: 4` (`work/tmp/red.log:39`); review-fix RED for C10 (`Failed: 1`).
- GREEN: mono xunit.console `-parallel none` 19/19; Release build 0 errors, 0 warnings.
- REVIEW: round 1 BLOCK (1 Critical: org-specific role ids), Canvas updated first, round 2 PASS (`.vela-runs/.../review.md`).
- PREVIEW: `vela plan ... --solution ZavaSales --detailed-exitcode` exit 8 (changes), 0 diagnostics. No `vela apply` (trace.md step 28 = gate).

## Criteria
| Criterion | Met? | Evidence |
| --- | --- | --- |
| Code is justified (value condition roles can't express) | met | Canvas `## A` / actor Q-log; actor report "a plugin is the right tool" |
| Roles generated from the org, into Shared | met | `src/zava.Shared/Models/Generated/Roles.cs:20`; check "Roles.cs mentions SalesManagerId" |
| Tests use `.Role(Roles.XName, Roles.XId, Roles.X)`; no hand-built role / privilege list | met (caveat) | `AccountCreditLimitApprovalTests.cs:40-42`. Caveat: System Administrator is seeded with a fresh id (`OrgSystemAdministratorId`, l.31) and its template GUID typed by hand (l.32, also `SalesManagerCheck.cs:32`) - privileges still generated; deliberate, Canvas decision l.51, accepted by review. See finding 1 |
| `parentrootroleid` compared to `Roles.SalesManagerId` | met | `SalesManagerCheck.cs:28,54`; checks "src contains parentrootroleid", "Roles.SalesManagerId" |
| Roles through a team count; team case tested | met | `SalesManagerCheck.cs:45-50`; test C9 (l.169) |
| Child-BU case tested (or gap recorded, not encoded) | met | C11 (l.175) seeds a child-BU copy; harness gap recorded in Canvas Sync log l.113-116 and flagged as a Vela.Testing gap |
| Sync PreValidation on Create + Update, `FilterOn(creditlimit)` | met | `AccountDefaultDescription.cs:25-38`; step-registered checks |
| French message in `Localization/Messages.cs` | met | `Messages.cs:16` matches the human's text verbatim |
| Tests RED first, each with case id | met | `red.log:39`; check `Trait("Case","ACC-...")` |
| spec-check passes | met | check "spec-check passes" (0 failures) |
| Review PASS | met | review.md round 2 "Verdict: PASS" |
| `vela plan` run; no apply | met | trace.md l.31 exit 8; l.32 gate; check "read-only vela plan runs" |
| One question at a time; ask vs assume | met | human-questions.md: 5 separate questions; defaults recorded as assumptions |

## Planted-violation check
One fresh `vela-reviewer` subagent, given only the two diffs and the Canvas; both projects built with 0 errors.
- (a) `ParentRootRoleId` → `RoleId` (`planted-a/diff.txt`): **BLOCK, Critical** (breaks C11 on a live org; contradicts Canvas) + Required (missing evidence). Expected Required → **pass**.
- (b) `Roles.SalesManagerId` → literal GUID (`planted-b/diff.txt`): **BLOCK, Required** (env-specific id as a constant; Canvas norm "no hard-coded GUIDs"; `--verify` would no longer protect it). Expected Required → **pass**.

## Findings against the skills
1. minor - `references/plugin-authoring-api.md:268` "a role check in code compares `Roles.<X>Id` to the user's (and teams') roles' `parentrootroleid` - never a role name or a hard-coded GUID" and `references/review-checklist.md:115-116` ("a role ... GUID written by hand ... Required"): the pack does not say the generated root id is org-issued for org-created roles (System Administrator). Round 1 review raised it as Critical; the actor had to hand-type the platform role-template GUID, which the checklist's own rule forbids. Underlying cause is a Vela gap (`vela models --roles` emits the source org's root id and no `roletemplateid`) - relay to the Vela repo; the pack should at most state the rule's limit, not a workaround.
2. minor - `references/harness-api.md:115-117` says `WithSecurity` with generated roles gives "the org's real privileges and root id"; the actor found the harness role rows carry no `parentrootroleid` and no business-unit copies, so the prescribed `parentrootroleid` check fails in the harness unless the test seeds the role shape by hand (Canvas Sync log l.113-116). Vela.Testing gap to relay; the reference over-promises.
3. minor - contradiction: `skills/vela-plugin-authoring/SKILL.md:30` "Keep the generated handler name: `OnExecute`" and red flag l.62-63 "a renamed generated handler" vs `references/registration-rules.md:64-65` "never the scaffold's `OnExecute` once the class holds more than one step". The actor followed registration-rules and renamed ACC-001's handler.
4. minor - the plugin class stays named `AccountDefaultDescription` while now holding ACC-002 (reuse = add-step per one-plugin-per-table); the pack gives no guidance on the class name once the class is no longer about its first behaviour. Not blocking.

## Fixes
- none yet.

## Verdict
pass - 26/26 checks, every criterion met, both planted violations blocked at Required or higher. Next run must
re-check: how System Administrator is identified (template id vs generated root id) once findings 1-2 are settled upstream.
