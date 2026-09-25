<h1 align="center">vela-agentic</h1>

<p align="center">
  <strong>The agentic layer for <a href="https://github.com/allandecastro/vela">Vela</a>: portable Agent Skills and an agent that turn a user story into a built, tested Dataverse plugin by driving the <code>vela</code> CLI - autonomous up to a human-approved deploy.</strong>
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

`vela-agentic` is a pack of **Agent Skills** and one **agent** (`vela-builder`) that let an AI
assistant build, model, test and deploy Microsoft Dataverse plugins by driving the `vela` CLI.
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
- **Stop before apply.** The whole loop is autonomous and reversible up to `vela plan`; a human
  approves the `vela apply` that writes to the org.
- **Loop engineering.** The skills themselves are held under test (`evals/`): a fresh agent runs
  a scenario, deviations become skill fixes, repeat until a clean pass.

## The build loop

`vela-builder` takes a user story and drives it through, with an advisory front gate and a
blocking deploy gate:

```
INTAKE -> PLAN -> CHALLENGE ··plan gate·· SCAFFOLD -> MODEL -> TEST(RED) -> IMPLEMENT -> VERIFY ──🚧apply gate🚧── APPLY -> REPORT
                  (self-grill  (advisory:  (init/add) (models) (failing    (code to    (suite green   (human        (only if
                   declare      flag +                          harness     green)      + analyzers    approves)     authorized)
                   acceptance   continue)                       tests)                  clean + plan)
                   cases)
```

It emits two artifacts (Markdown + YAML front-matter), committed under `docs/vela-builds/` in the
target project and reused as the PR body:

- a **Plan artifact** at the front gate (interpreted spec, grilling Q&A, acceptance cases, risks),
- a **Build Report** at the deploy gate (what was built, evidence, the exact `vela apply` to run).

## What's inside

| Area | Contents |
| --- | --- |
| `skills/` | 11 portable Agent Skills (`SKILL.md`), read by Claude Code directly |
| `agents/` | `vela-builder` - the gated end-to-end build loop |
| `references/` | Grounded, verbatim knowledge the skills point to (CLI surface, plugin + harness API, Dataverse gotchas, artifact templates) |
| `evals/` | Loop-engineering pressure scenarios + protocol (TDD for the skills) |
| `AGENTS.md` | Durable rules every agent follows, plus the build loop and headless/cloud prerequisites |
| `.claude-plugin/` | Claude Code distribution: plugin marketplace + plugin manifest |
| `.github/` | GitHub Copilot distribution (skills, chat mode, instructions) - **generated**, never hand-edited |
| `scripts/` | `sync-copilot.mjs` regenerates `.github/` from the source of truth |

### Skills

| Skill | Kind | What it does |
| --- | --- | --- |
| `using-vela` | model-invoked | Entry point: the build loop and the non-negotiable rules |
| `vela-plan-review` | model-invoked | Self-grill the plan until every branch resolves; emit the Plan artifact |
| `vela-grill` | user-invoked (`/vela-grill`) | Interview the human when a story is too ambiguous to build safely |
| `vela-scaffold` | model-invoked | `vela init` / `vela add` a solution or component (local only) |
| `vela-models` | model-invoked | Generate early-bound C# / TypeScript models, or verify drift |
| `vela-test-harness` | model-invoked | Write failing (RED) tests with `Vela.Testing`, run them per the OS runner |
| `vela-plugin-authoring` | model-invoked | Implement the handler to green (real `EntityPluginBase` / `OnExecute` surface) |
| `vela-apply` | model-invoked | Preview with `vela plan`, then stop at the human deploy gate |
| `vela-debug-plugin` | model-invoked | Diagnose a misbehaving plugin (reproduce -> minimize -> hypothesize -> fix) |
| `writing-vela-skills` | model-invoked | The meta-skill: how to add or fix a skill under test (RED -> GREEN -> REFACTOR) |
| `diagnosing-vela` | model-invoked | Turn a run transcript into concrete, line-level skill findings |

> **Status** - Preview, review-first, not yet published. The distribution surfaces (`.claude-plugin/`,
> `.github/`) are generated from `skills/`, `agents/`, `AGENTS.md` and `references/`. Edit the source,
> then run `node scripts/sync-copilot.mjs`.

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

The generated `.github/skills/`, `.github/chatmodes/` and `.github/copilot-instructions.md` are
discovered by Copilot. Copy them into a consuming repository, or reference them from your Copilot
configuration.

### Prerequisites

- The `vela` CLI (`dotnet tool install --global Vela.Cli`) and a matching `dotnet` SDK.
- A Dataverse environment for the `models` / `plan` steps: interactive login locally, or a
  connection string / client secret for headless and cloud runs (see `AGENTS.md`).

## Loop engineering

The pack is not written once and trusted. Every skill change is validated against an `evals/`
scenario: a fresh agent runs it following the skills to the letter, and each deviation, wrong
command or missing guardrail is a **skill defect** to fix, then a loophole to close. A scenario is
"ready" only when it passes with no blocking finding - not on a hunch. See `evals/README.md`.

## Compatibility

Skills target the public `vela` CLI command surface and discover exact flags at runtime, so
additive CLI changes do not break them. Each skill states a minimum CLI version as a real floor;
breaking CLI changes are matched by a skill update. See [`ROADMAP.md`](ROADMAP.md) for the policy
and what is planned.

## Contributing

New or changed skills follow the house style and the test-first discipline in
`skills/writing-vela-skills/SKILL.md`: no skill change ships without an eval that would have caught
the defect. Never hand-edit `.github/` - it is generated by `scripts/sync-copilot.mjs`.

## Acknowledgments

Built for [Vela](https://github.com/allandecastro/vela). Skill design informed by the Agent Skills
ecosystem (`SKILL.md`, `AGENTS.md`) and the workflow packs that popularized process-first,
verification-driven skills.

---

<p align="center">
  Crafted with ❤️ and AI by Allan De Castro
</p>

<p align="center">
  License: <a href="LICENSE">MIT</a>
</p>
