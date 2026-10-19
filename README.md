<p align="center">
  <img src="branding/vela-chevron.svg" alt="Vela" width="110" height="110" />
</p>

<h1 align="center">Vela Agentic</h1>

<p align="center">
  <strong>The agentic layer for <a href="https://github.com/allandecastro/vela">Vela</a>: portable Agent Skills and two agents (a builder and a reviewer) that turn a user story into a built, tested, reviewed Dataverse plugin by driving the <code>vela</code> CLI - autonomous up to a human-approved deploy.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/license-MIT-green?style=for-the-badge" alt="License: MIT" />
  <img src="https://img.shields.io/badge/status-preview-orange?style=for-the-badge" alt="Status: preview" />
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Agent_Skills-SKILL.md-000000?style=for-the-badge" alt="Agent Skills" />
  <img src="https://img.shields.io/badge/Claude_Code-plugin_marketplace-CC785C?style=for-the-badge" alt="Claude Code" />
  <img src="https://img.shields.io/badge/GitHub_Copilot-.github-24292F?style=for-the-badge&logo=github&logoColor=white" alt="GitHub Copilot" />
  <img src="https://img.shields.io/badge/Microsoft_Dataverse-107C10?style=for-the-badge&logo=microsoft&logoColor=white" alt="Microsoft Dataverse" />
</p>

`vela-agentic` is a pack of **Agent Skills** and two **agents** (`vela-builder` and
`vela-reviewer`) that let an AI assistant build, model, test, review and deploy Microsoft
Dataverse plugins by driving the `vela` CLI.
It targets **Claude Code** and **GitHub Copilot** from a single source of truth, and it encodes a
safe, **test-first, preview-before-deploy** workflow that stops before writing to a live org.

## Philosophy

- **The CLI is the contract.** Skills wrap the public `vela` command surface (the stable,
  versioned interface) and confirm flags with `--help` at runtime. They do not reach around it.
- **Process, not prose.** Each skill is a workflow with checkpoints, documented rationalizations,
  red flags and a verification section - not reference documentation.
- **Evidence over claims.** No step is "done" without the build/test/plan output that proves it.
- **Test-first quality gate.** Tests are written to fail (RED) before implementation, and the
  deploy gate is unreachable unless the suite is green over every acceptance case and the
  authored code is analyzer-clean.
- **Stop before apply.** The whole loop is autonomous and reversible up to `vela plan` (run on the
  final, packed package); a human
  approves the `vela apply` that writes to the org.
- **Structured, living spec.** The plan is a **Vela Canvas** (a REASONS-adapted structured spec,
  after Thoughtworks' SPDD), not free text: it captures the design decisions and stays in sync
  with the code (fix the spec first, then the code).
- **Author / reviewer separation.** A second, isolated `vela-reviewer` agent reviews the diff with
  fresh context, catching what the author is blind to - while a human keeps the final say.
- **Loop engineering.** The skills themselves are held under test (`evals/`): a fresh agent runs
  a scenario, deviations become skill fixes, repeat until a clean pass.
- **Agent layer, not a framework patch.** Vela and its CLI are the contract. When a capability is
  missing, the skills say so and the agent stops (the story is marked **blocked**) - the gap is fixed
  in Vela, not worked around here.

## The build loop

`vela-builder` takes a user story and drives it through, with an advisory front gate and a
blocking deploy gate:

```mermaid
flowchart TD
    US([User story]) --> I[Intake]
    I --> P[Plan]
    P --> C["Challenge<br/>self-grill · declare acceptance cases"]
    C -. emits .-> PA[/"Vela Canvas"/]
    C --> G1{{"Plan gate<br/>advisory - flag &amp; continue"}}
    G1 --> S["Scaffold<br/>vela init / vela add"]
    S --> M["Model<br/>vela models"]
    M --> T["Test (RED)<br/>failing harness tests"]
    T --> IM["Implement<br/>code to green"]
    IM --> V["Verify<br/>suite green + analyzers clean"]
    V -->|red / violations| IM
    V --> RV["Review<br/>spec + standards axes · severities"]
    RV -->|Critical / Required| IM
    PV -. emits .-> BR[/"Build Report"/]
    RV -->|PASS| PV["Package &amp; preview<br/>dotnet build -c Release · vela sign · vela plan"]
    PV --> G2{{"Apply gate<br/>blocking - human approves"}}
    G2 -->|authorized| AP["Apply<br/>vela apply · writes to org"]
    AP --> R([Report / PR])

    subgraph LOCAL ["Autonomous · local · reversible - org never written"]
        I
        P
        C
        G1
        S
        M
        T
        IM
        V
        RV
        PV
    end

    classDef gate fill:#fde68a,stroke:#b45309,color:#1f2937;
    classDef org fill:#fecaca,stroke:#b91c1c,color:#1f2937;
    classDef art fill:#e0e7ff,stroke:#4338ca,color:#1f2937;
    class G1,G2 gate
    class AP org
    class PA,BR art
```

It emits two artifacts (Markdown + YAML front-matter), committed in one folder per story, `docs/features/<slug>/`, in the
target project and reused as the PR body:

- a **Vela Canvas** at the front gate - a REASONS-adapted spec (Requirements, Entities, Approach,
  Structure, Operations, Norms, Safeguards) that captures the design decisions (Sync/Async,
  reuse-vs-new, services, naming, safeguards) and the acceptance cases,
- a **Build Report** at the deploy gate (what was built, evidence, the exact `vela apply` to run),
  which the Canvas grows into. It is a **living spec**: requirement changes update the Canvas first.

### Business rules and the tests that prove them

The agent also keeps a **rules registry** in the target project, `docs/rules/<table>.md` (one file per
table, the one that triggers the rule): every active business rule written in English as
**Given / When / Then / Otherwise**, with its numbered cases (`ACC-002/C1`), the plugin that implements it,
and the history of retired rules. It is read at the start of every story - to reuse what exists and to
**ask the human** when a story contradicts a rule - and it is the **functional spec of the tests**: each
test carries its case id (`[Trait("Case", "ACC-002/C1")]`).

The registry is written in the **design** phase only. In the **build** it is read-only: a failing
regression test means the code is wrong, never the test. `tools/spec-check.py` checks this
deterministically at review (and in CI): no registry edit after the build started, no undeclared rule
change, no deleted rule (retired, with its text kept), no regression test bent for a rule the story does
not change. See [`examples/`](examples/) for a story built end to end (Build Report, plugin, tests).

## What's inside

| Area | Contents |
| --- | --- |
| `skills/` | 13 portable Agent Skills (`SKILL.md`), read by Claude Code directly. Every skill is model-invoked and can also be run by name (`/vela-grill`) |
| `agents/` | `vela-builder` (the gated end-to-end build loop) + `vela-reviewer` (isolated read-only code reviewer), as `<name>.agent.md` - loaded by Claude Code and by a Copilot CLI plugin as-is |
| `references/` | Grounded, verbatim knowledge the skills point to (CLI surface, plugin + harness API, Dataverse gotchas, artifact templates). The source of truth: each skill gets a **generated copy** of what it cites under `skills/<name>/references/`, so a skill is self-contained once installed |
| `evals/` | Loop-engineering pressure scenarios + protocol (TDD for the skills): hidden criteria, deterministic checks, separate grader |
| `examples/` | A story built end to end by the agent: the Build Report, the plugin and its tests, unedited |
| `tools/` | `spec-check.py` - the deterministic check of the rules registry and the regression tests (run at review / in CI) |
| `hooks/` | Optional dual-target guard: a pre-tool hook that hard-blocks `vela apply` without approval (Claude Code + Copilot) |
| `AGENTS.md` | Durable rules every agent follows, plus the build loop and headless/cloud prerequisites |
| `.claude-plugin/` | Claude Code distribution: plugin marketplace + plugin manifest |
| `.github/` | GitHub Copilot repository surface (skills, custom agents `.github/agents/*.agent.md`, instructions, hooks) - **generated**, never hand-edited |
| `scripts/` | `sync-copilot.mjs` regenerates `.github/` and the per-skill reference copies; `lint-pack.mjs` checks the pack |

### Skills

| Skill | Invocation | What it does |
| --- | --- | --- |
| `using-vela` | model-invoked | Entry point: the build loop and the non-negotiable rules |
| `vela-plan-review` | model-invoked | Self-grill the plan until every branch resolves; fill the Vela Canvas |
| `vela-grill` | model-invoked · also `/vela-grill` | Interview the human when a story is too ambiguous to build safely |
| `vela-scaffold` | model-invoked | `vela init` / `vela add` a solution or component (local only) |
| `vela-models` | model-invoked | Generate early-bound C# / TypeScript models, or verify drift |
| `vela-test-harness` | model-invoked | Write failing (RED) tests with `Vela.Testing`, run them per the OS runner |
| `vela-plugin-authoring` | model-invoked | Implement the handler to green (real `EntityPluginBase` / `OnExecute` surface) |
| `vela-custom-api` | model-invoked | Design, test and implement a Custom API (global or bound, Action or Function, typed or light) |
| `vela-code-review` | model-invoked | Review the diff on the spec + standards axes before the apply gate - by the isolated `vela-reviewer` by default, self-review as a labelled fallback |
| `vela-apply` | model-invoked | Package (`dotnet build -c Release`, `vela sign`), preview with `vela plan`, stop at the human deploy gate; `vela inspect` after apply |
| `vela-debug-plugin` | model-invoked | Diagnose a misbehaving plugin (reproduce -> minimize -> hypothesize -> fix) |
| `writing-vela-skills` | model-invoked | The meta-skill: how to add or fix a skill under test (RED -> GREEN -> REFACTOR) |
| `diagnosing-vela` | model-invoked | Turn a run transcript into concrete, line-level skill findings |

> **Status** - Preview, review-first, not yet published. The distribution surfaces (`.claude-plugin/`,
> `.github/`) and the per-skill `skills/<name>/references/` copies are generated from `skills/`, `agents/`,
> `AGENTS.md` and `references/`. Edit the source, then run `node scripts/sync-copilot.mjs`.

## Using it

### With Claude Code

Add this repository as a plugin marketplace, then install the `vela` plugin:

```
/plugin marketplace add allandecastro/vela-agentic
/plugin install vela
```

Then hand `vela-builder` a user story ("When an Account is created, default its Description ...")
and it drives the loop, stopping at the deploy gate for your approval.

### With GitHub Copilot

Copilot CLI reads the same plugin manifest as Claude Code (it supports the `.claude-plugin/`
location), so install this pack as a Copilot **plugin**, mirroring the Claude Code steps:

```bash
copilot plugin marketplace add allandecastro/vela-agentic
copilot plugin install vela@vela-agentic
# or directly, without the marketplace step:
copilot plugin install allandecastro/vela-agentic
```

Verify what loaded with `copilot plugin list`. The **skills** load from `skills/` automatically.
The agents load from `agents/*.agent.md` (their Claude tool names are documented Copilot aliases) and
the apply-guard from the generated root `hooks.json`; see `hooks/README.md` for the one-time check.

Portable alternative (skills only, any host, no plugin): install the skills with the official
`gh skill` command (`gh` 2.90.0 or later):

```bash
gh skill preview allandecastro/vela-agentic   # inspect first (skills are not verified by GitHub)
gh skill install allandecastro/vela-agentic
```

Then hand `vela-builder` a user story, the same way as on Claude Code.

### Prerequisites

- The `vela` CLI (`dotnet tool install --global Vela.Cli`) and a matching `dotnet` SDK.
- A Dataverse environment for the `models` / `plan` steps: `--interactive` with a human at a browser,
  or headless via `--url` alone with an `az login` session / managed identity (verified), or a
  connection string / client secret (see `AGENTS.md`).
- Tests run on Windows with `dotnet test`; on macOS/Linux with Mono + the xunit console runner.

## Enforcement & observability

The Build Report carries a machine-readable **Run trace** (step, command, exit code, gate verdict -
all copied from tool output, never estimated), so a run is auditable and replayable. On top of that, an **optional** dual-target hook
(`hooks/`, one script wired for Claude Code and GitHub Copilot) makes the deploy gate deterministic:
it **denies `vela apply`** unless a human started the session with `VELA_APPLY_APPROVED=1` (the agent
cannot approve itself with an inline prefix). See `hooks/README.md` for
the per-host wiring and caveats. `tools/spec-check.py` is the deterministic check of the business rules and
the regression tests (above). `scripts/check.sh` lints the pack, runs the guard's table tests and checks every
generated surface is in sync; it runs as a local pre-push hook and in CI (same script).

## Loop engineering

The pack is not written once and trusted. Every behaviour change is validated against an `evals/`
scenario: a fresh agent runs it following the skills to the letter, and each deviation, wrong
command or missing guardrail is a **skill defect** to fix, then a loophole to close. A scenario is
"ready" only when it passes with no blocking finding. See `evals/README.md` (scenarios, coverage table)
and `evals/runs/` (every run, failures included).

Each run is graded the hard way: the acting agent only sees the story (**hidden criteria**); the
evaluator re-builds, re-runs the tests, reads the registration from the compiled dll and runs a read-only
`vela plan` (**deterministic checks**); a **separate grader** judges the rest and replays **planted
violations** against a fresh reviewer. Campaigns run each scenario several times; the pass rate per scenario
is generated into `evals/README.md`. The dev org is used read-only, except a small evaluator-deployed
fixture (`VelaEvals`) for the scenarios that debug or change a live plugin.

**The pack is kept lean on purpose:** skills teach how to *drive* Vela (process, decisions, gates, red
flags) and point to `vela <command> --help`, the generated code and Vela's own docs
([`docs/llms.txt`](https://allandecastro.github.io/vela/llms.txt)) for API
detail, instead of copying the framework into the skills.

## Compatibility

Skills target the public `vela` CLI command surface and discover exact flags at runtime, so
additive CLI changes do not break them. The verified version lives in one place,
`references/cli-surface.md`; skills carry no version numbers. A framework gap found by an eval is reported to the Vela repo, not
worked around in the skills. See [`ROADMAP.md`](ROADMAP.md) for the policy and what is planned.

## Contributing

New or changed skills follow the house style and the test-first discipline in
`skills/writing-vela-skills/SKILL.md`: a change to what an agent *does* ships with an eval that would
have caught the defect (recorded under `evals/runs/`); a grounding fix ships with its `--help` /
harness proof; wording changes need the lint.

Before pushing, run `sh scripts/check.sh` (lint, JSON configs, shell syntax, apply-guard tests,
generated surfaces in sync). Enable it as a pre-push hook once per clone with
`git config core.hooksPath .githooks`. CI runs the same script. Never hand-edit `.github/` - it is generated by `scripts/sync-copilot.mjs`.

## Acknowledgments

Built for [Vela](https://github.com/allandecastro/vela). Skill design informed by the Agent Skills
ecosystem (`SKILL.md`, `AGENTS.md`) and the workflow packs that popularized process-first,
verification-driven skills.

---

<p align="center">
  Crafted with care and AI by Allan De Castro
</p>

<p align="center">
  License: <a href="LICENSE">MIT</a>
</p>
