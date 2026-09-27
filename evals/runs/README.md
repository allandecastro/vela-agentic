# Eval run records

One file per run: `<YYYY-MM-DD>-<scenario>.md`. It is the evidence behind "this scenario passes" and the
input for the next iteration. The lint checks the frontmatter.

```markdown
---
scenario: account-update-recursion   # a file in ../scenarios/
date: 2026-09-28
verdict: fail                        # pass (no blocking finding) | fail
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
