# Eval run records

One file per run: `<YYYY-MM-DD>-<scenario>.md`. It is the evidence behind "this scenario passes" and the
input for the next iteration. The lint checks the frontmatter.

```markdown
---
scenario: account-update-recursion   # a file in ../scenarios/
date: 2026-09-28
verdict: fail                        # pass (no blocking finding) | fail  - campaign runs: checks AND grader
campaign: 2026-09-30                 # campaign runs only: the campaign id (YYYY-MM-DD; a re-run the same day: 2026-09-30b)
run: 1/3                             # campaign runs only: k/N
checks: pass                         # campaign runs only: evals/checks/check.py result (passed/total in the body)
grader: pass                         # campaign runs only: the separate grader's verdict
model: claude-opus-5-5               # the model the actor ran on
vela_cli: 0.19.6
framework: 0.28.2
runner: fresh subagent, local, no org
---

## Loop outcome
<one line per step: what the agent did, exit codes>

## Findings
1. **blocker** - `skills/<skill>/SKILL.md` said "<quote>"; the agent did <what>; correct path: <command/API>.
2. minor - ...

## Fixes
- <commit / PR that addressed each finding>

## Verdict
<pass/fail and why; what the next run must re-check>
```
