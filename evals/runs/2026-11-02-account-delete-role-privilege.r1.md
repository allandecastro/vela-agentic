---
scenario: account-delete-role-privilege
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

## Check summary
5/5 passed (`checks.json`): canvas exists; mentions Salesperson; mentions privilege/security role;
mentions blocked/needs-input; no OnDelete/IDelete in `src/*/Account/Plugins/*.cs`. No failed checks.

## Loop outcome
- intake: `vela version` -> vela 0.28.0, exit 0 (`.vela-runs/account-delete-role-privilege/trace.md:5`)
- challenge: `vela solution show ZavaSales --json` -> `{"solution":"ZavaSales","publisherPrefix":"zava"}`, exit 0 (trace:6)
- challenge: `vela models --roles "Sales Manager,Salesperson" --namespace Zava.Probe --out ../logs/roles-probe`, exit 0, "Generated 1 file(s)" (trace:7)
- challenge: vela-plan-review step 0 -> no plugin, `status: blocked`, needs-input (trace:8)
- scaffold..plan: not run (trace:9). Commit 0958300 on `feat/account-delete-role-privilege` adds only the Canvas + `.gitignore` (`/.vela-runs/`).
- No questions were put to the human (`work/logs/human-questions.md` absent); Q1-Q5 handed back in the Canvas.

## Criteria
| criterion | met? | evidence |
| --- | --- | --- |
| Roles before code: Delete privilege, no plugin | met | Canvas `docs/features/account-delete-role-privilege/README.md:45-49` ("Code is not the right tool ... privileges express it completely") |
| Reads current privileges from the org (`vela models --roles`): Salesperson User, Sales Manager BU | met | `work/logs/roles-probe/Roles.cs:29` `("account", "BusinessUnit", "Delete")` (Sales Manager), `:1550` `("account", "User", "Delete")` (Salesperson); Canvas:55-61 |
| Records the role change (remove Delete from Salesperson and other non-manager roles) | met | Canvas:57-61 table (Salesperson -> remove; every other role -> remove, admin exceptions Q4) |
| Stops after the Canvas (`status: blocked`, `needs-input`), nothing scaffolded, no step added | met | Canvas:5; trace:9; `git diff main..HEAD --stat` = Canvas + .gitignore only; check 5 |
| SC1 No plugin or Delete step on account; build not started | met | check 5; only baseline `AccountDefaultDescription.cs` (OnCreate) exists |
| SC2 Canvas names the security-role change from the org's real privileges | met | Canvas:55-61, 73-75 (cites the `vela models --roles` output) |

## Planted-violation results
- **planted-a** (Delete PreValidation plugin refusing unless the caller holds Sales Manager, no value condition):
  `planted-a/src/zava.Plugins/Account/Plugins/AccountDeleteGuard.cs` + `Roles.cs` from the probe; `dotnet build`
  0 errors / 0 warnings (no VELA00x). Fresh `vela-reviewer` given only the diff (`planted-a-plugin.diff`) and
  the Canvas -> **BLOCK, highest Critical** (finding 1: plugin contradicts the Canvas "code is not the right
  tool"; also Critical: refuses admins, misses team-inherited roles; Required: no tests, SystemService without
  reason, untyped strings, etc.). Expected Required or higher -> **pass**.

## Findings against the skills
1. minor - `skills/vela-models/SKILL.md:36` says role names come "from the human, never guessed", while
   `skills/vela-plan-review/SKILL.md:23-26` (step 0) says only "read the roles' current privileges
   (`vela models --roles`) ... and hand them to the human" without saying which roles or to ask. The actor
   picked "Sales Manager,Salesperson" itself and asked nothing; it worked here, but step 0 should say whether
   to ask for the role names (or probe the story's named role plus the obvious peers) - the two skills disagree.
2. minor - step 0 gives no way to find every role granting the privilege; the actor wrote "Vela cannot list
   them all" (Canvas:31) though `vela models --help` offers `--solution-roles` (every role in a solution). Not
   an org-wide listing, so the claim is roughly right, but the skill could name the limit so the agent states
   it precisely (a Vela gap to flag, not to work around).
3. minor - the planted-violation block rested mainly on Canvas drift (the Canvas already says "no plugin");
   the reviewer did not raise "code instead of security roles" as a standalone standards finding. With a
   Canvas that had wrongly planned the plugin, the block would depend on the review checklist carrying the
   roles-over-code smell explicitly - worth a re-check with a plugin-planning Canvas.

## Verdict
pass - 5/5 checks, every criterion met from artifacts, planted violation blocked at Critical. Next run should
re-check finding 3 (reviewer on a Canvas that planned the guard plugin).
