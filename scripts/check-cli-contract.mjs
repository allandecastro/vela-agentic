#!/usr/bin/env node
// The Vela CLI contract: the pack drives Vela only through the `vela` CLI, so every command and option it cites must
// exist in the CLI it is verified against. contract/vela-help.json is that CLI's `vela help --json`,
// contract/vela-cli.version its version (the pack's single source of it).
//
//   node scripts/check-cli-contract.mjs                 offline (scripts/check.sh, every PR):
//       - contract/vela-cli.version = the "Verified against" CLI of references/cli-surface.md = the minimum in
//         docs/install.md;
//       - usage check: every `vela <command> [--option]` cited in the sources (skills/*/SKILL.md, references/*.md,
//         agents/*.md, AGENTS.md, docs/**/*.md; generated copies excluded) exists in the snapshot - file:line on error.
//   node scripts/check-cli-contract.mjs --pinned        installs the snapshot's exact Vela.Cli and fails on any
//                                                       difference with the snapshot (guards the snapshot).
//   node scripts/check-cli-contract.mjs --latest        installs the newest Vela.Cli and diffs its structure with the
//                                                       snapshot: a removed/changed item the pack uses is BREAKING.
//     --against <file>   diff a given `help --json` document instead of installing (tests the diff).
//     --report <file>    write a markdown report (first line: the issue title) when there is a difference;
//                        the file is removed when there is none.
//     --update           with --latest/--pinned/--against: write the CLI's document into contract/ (refresh PR).
// Exit 0 = clean (information-only differences allowed with --latest), 1 = errors / breaking change /
// schemaVersion change / --pinned mismatch, 2 = bad arguments or the CLI could not be installed.
//
// Plain node, no dependency; --pinned/--latest need the dotnet SDK (`dotnet tool install`).

import { promises as fs } from "node:fs";
import { spawnSync } from "node:child_process";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const CONTRACT_JSON = path.join(root, "contract", "vela-help.json");
const CONTRACT_VERSION = path.join(root, "contract", "vela-cli.version");
const VERSION_RE = /^\d+\.\d+\.\d+$/;

// Options the CLI accepts before any command (`vela --version`, `vela --help`); `help --json` lists none.
const GLOBAL_OPTIONS = new Set(["--version", "--help", "-h"]);
// Options of other tools the pack cites alone in code (git, the xUnit console runner): a lone option that is not one
// of these must be a vela option. Add a tool's option here only when the text names that tool.
const FOREIGN_OPTIONS = new Set(["--no-verify", "--force-with-lease", "-parallel"]);

// ---------- arguments ----------
const args = process.argv.slice(2);
const opt = { mode: "offline", against: null, report: null, update: false };
for (let i = 0; i < args.length; i++) {
  const a = args[i];
  if (a === "--pinned" || a === "--latest") opt.mode = a.slice(2);
  else if (a === "--against") opt.against = args[++i];
  else if (a === "--report") opt.report = args[++i];
  else if (a === "--update") opt.update = true;
  else { console.error(`unknown argument '${a}' - see the header of scripts/check-cli-contract.mjs`); process.exit(2); }
}
if ((opt.against && opt.mode === "offline")) opt.mode = "latest";
if ((opt.report || opt.update) && opt.mode === "offline") { console.error("--report/--update need --pinned, --latest or --against"); process.exit(2); }

// ---------- snapshot ----------
// Stable key order: the known keys in this order, any other key after them, alphabetically.
const KEY_ORDER = ["schemaVersion", "tool", "version", "name", "aliases", "kind", "value", "summary", "usage", "description", "options", "commands", "exitCodes"];
function canonical(v) {
  if (Array.isArray(v)) return v.map(canonical);
  if (v && typeof v === "object") {
    const rank = (k) => (KEY_ORDER.includes(k) ? KEY_ORDER.indexOf(k) : KEY_ORDER.length);
    const keys = Object.keys(v).sort((a, b) => rank(a) - rank(b) || (a < b ? -1 : a > b ? 1 : 0));
    if (keys.every((k) => /^\d+$/.test(k))) keys.sort((a, b) => Number(a) - Number(b));
    return Object.fromEntries(keys.map((k) => [k, canonical(v[k])]));
  }
  return v;
}
const serialize = (doc) => JSON.stringify(canonical(doc), null, 2) + "\n";

const snapshot = JSON.parse(await fs.readFile(CONTRACT_JSON, "utf8"));
const snapshotVersion = (await fs.readFile(CONTRACT_VERSION, "utf8")).trim();

// Lookup tables of one `help --json` document.
function model(doc) {
  const commands = new Map(); // canonical name -> { cmd, options: Map(token -> canonical option), positionals: Set|null }
  const byToken = new Map(); // command name or alias -> canonical name
  for (const c of doc.commands || []) {
    const options = new Map();
    for (const o of c.options || []) for (const t of [o.name, ...(o.aliases || [])]) options.set(t, o.name);
    // Options a usage line shows but the options list omits (e.g. `vela help [<command>] [--json]`).
    for (const u of c.usage || []) for (const m of u.matchAll(/(?<![\w-])(--?[A-Za-z][\w-]*)/g)) if (!options.has(m[1])) options.set(m[1], m[1]);
    commands.set(c.name, { cmd: c, options, positionals: positionals(c) });
    for (const t of [c.name, ...(c.aliases || [])]) byToken.set(t, c.name);
  }
  return { commands, byToken };
}

// The literal words a command takes first (`vela add (plugin|service|...)`, `vela solution show`), or null when its
// usage shows a free positional (`vela init <Name>`) - then any word is accepted.
function positionals(c) {
  const words = new Set();
  for (const u of c.usage || []) {
    const first = u.replace(/^vela\s+\S+\s*/, "").split(/\s+/)[0] || "";
    if (!first || first.startsWith("-")) continue;
    const alt = first.match(/^\(?([a-z][a-z-]*(?:\|[a-z][a-z-]*)*)\)?$/);
    if (!alt) return null;
    for (const w of alt[1].split("|")) words.add(w);
  }
  return words.size ? words : null;
}

// ---------- usage scan ----------
const rel = (p) => path.relative(root, p).split(path.sep).join("/");
async function* walk(dir) {
  for (const e of await fs.readdir(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) yield* walk(p);
    else if (e.name.endsWith(".md")) yield p;
  }
}
async function sources() {
  const out = [path.join(root, "AGENTS.md")];
  for (const e of await fs.readdir(path.join(root, "skills"), { withFileTypes: true }))
    if (e.isDirectory()) out.push(path.join(root, "skills", e.name, "SKILL.md")); // not skills/*/references (generated)
  for (const d of ["references", "agents"])
    for (const f of await fs.readdir(path.join(root, d))) if (f.endsWith(".md")) out.push(path.join(root, d, f));
  for await (const f of walk(path.join(root, "docs"))) out.push(f);
  return out;
}

// Code segments of a markdown file: [{ text, line }] - inline code spans (a span may wrap onto the next line inside a
// paragraph) and fenced-code lines (a trailing `\` joins the next line). Command-line text lives there; prose is not
// checked. `headings` maps each line to the code spans of the heading above it (section context).
function segments(md) {
  const lines = md.replace(/\r\n/g, "\n").split("\n");
  const out = [];
  let fence = false, para = [], pending = null;
  const flush = () => {
    if (!para.length) return;
    const text = para.map((p) => p.text).join("\n");
    const lineAt = (off) => para[0].line + (text.slice(0, off).match(/\n/g) || []).length;
    for (const m of text.matchAll(/(`+)([^`]+?)\1/g)) out.push({ text: m[2].replace(/\s*\n\s*/g, " "), line: lineAt(m.index), inline: true });
    para = [];
  };
  lines.forEach((l, i) => {
    if (/^\s*(```|~~~)/.test(l)) { flush(); fence = !fence; pending = null; return; }
    if (fence) {
      const joined = pending ? { text: pending.text + " " + l.trim(), line: pending.line } : { text: l, line: i + 1 };
      if (/\\\s*$/.test(l)) { pending = { text: joined.text.replace(/\\\s*$/, ""), line: joined.line }; return; }
      pending = null;
      out.push({ ...joined, inline: false });
      return;
    }
    if (!l.trim() || /^#{1,6}\s/.test(l)) { flush(); if (l.trim()) { para.push({ text: l, line: i + 1 }); flush(); } return; }
    para.push({ text: l, line: i + 1 });
  });
  flush();
  return out;
}

// The pieces of a command line that are options: `--x`, `-x`, `--x=v`, also inside `[--a|--b]` or `--a/--b`.
function optionsIn(words) {
  const found = [];
  for (const w of words)
    for (const piece of w.split(/[\[\]()|/,"']/))
      { const m = piece.match(/^(--?[A-Za-z][A-Za-z0-9-]*)(=.*)?$/); if (m) found.push(m[1]); }
  return found;
}
const isPlaceholder = (w) => /^</.test(w) || /^(\.\.\.|…)$/.test(w);

// Scans the sources against a model. Returns { errors: [msg], uses: Map(key -> [file:line]), invocations }.
async function scan(m) {
  const errors = [];
  const uses = new Map();
  const use = (key, where) => { if (!uses.has(key)) uses.set(key, []); uses.get(key).push(where); };
  const allOptions = new Set(GLOBAL_OPTIONS);
  for (const { options } of m.commands.values()) for (const t of options.keys()) allOptions.add(t);
  let invocations = 0;

  for (const file of await sources()) {
    const md = await fs.readFile(file, "utf8");
    const name = rel(file);
    let exitSection = false;
    // Exit codes the pack cites: "exit `5`", "exits 0", "(exit 4", and every `N` under an "Exit codes" heading.
    md.split("\n").forEach((l, i) => {
      if (/^#{1,6}\s/.test(l)) exitSection = /exit codes?/i.test(l);
      for (const e of l.matchAll(/\bexit(?:s|ed)?(?: code)?\s*\**\s*`?(\d{1,3})\b/gi)) use(`exit:${e[1]}`, `${name}:${i + 1}`);
      if (exitSection) for (const e of l.matchAll(/`(\d{1,3})`/g)) use(`exit:${e[1]}`, `${name}:${i + 1}`);
    });

    for (const seg of segments(md)) {
      const where = `${name}:${seg.line}`;
      // Each `vela` starts one invocation; it ends at a shell separator (and, outside inline code, a pipe or comment).
      const stops = seg.inline ? /\s(?:&&|\|\||;|→)\s/ : /\s(?:&&|\|\|?|;|→|#)\s/;
      const parts = seg.text.split(/(?<![\w./~@$<-])vela(?=[ \t]+\S)/).slice(1);
      if (seg.inline && !parts.length) {
        // `add step <Plugin> --entity ...`, `models --verify` (the `vela` left out): a command word, then an option
        // or one of its literal first words (so C#'s `new Foo()` is not `vela new`).
        const [, first, second] = seg.text.match(/^([a-z][a-z-]*)\s+(\S+)/) || [];
        const c = first && m.byToken.get(first);
        if (c && (second.startsWith("-") || m.commands.get(c).positionals?.has(second))) parts.push(" " + seg.text);
        // A lone option (`--filtering-attributes`, `--pfx <file>`): it must exist on some command.
        else if (/^--?[A-Za-z][\w-]*(?:[ =/|]|$)/.test(seg.text)) {
          for (const o of optionsIn(seg.text.split(/\s+/).filter((w) => w.startsWith("-")))) {
            if (FOREIGN_OPTIONS.has(o)) continue;
            if (!allOptions.has(o)) errors.push(`${where}: \`${o}\` - no command of the snapshot has it`);
            else use(`anyopt:${o}`, where);
          }
        }
      }
      for (const part of parts) {
        const words = part.split(stops)[0].trim().split(/\s+/).map((w) => w.replace(/^["'(\[]+|["'`),;:\]]+$/g, "")).filter(Boolean);
        if (!words.length) continue;
        invocations++;
        const head = words[0];
        if (/^\d/.test(head)) continue; // `vela 0.33.0`: a version, not a command
        let cmds = [];
        if (head.startsWith("-")) {
          // `vela --version`: global options only.
          for (const o of optionsIn(words)) if (!GLOBAL_OPTIONS.has(o)) errors.push(`${where}: \`vela ${o}\` - not a global option of the snapshot`);
          continue;
        }
        if (!isPlaceholder(head)) {
          for (const t of head.split("|")) {
            const c = m.byToken.get(t);
            if (!c) { errors.push(`${where}: \`vela ${t}\` - no such command or alias in the snapshot`); continue; }
            use(`cmd:${c}`, where);
            if (t !== c) use(`alias:${c}:${t}`, where);
            cmds.push(c);
          }
          if (!cmds.length) continue;
          // A literal first word (`vela add plugin`, `vela solution show`).
          const next = words[1];
          if (next && !next.startsWith("-") && !isPlaceholder(next))
            for (const c of cmds) {
              const pos = m.commands.get(c).positionals;
              if (!pos) continue;
              for (const w of next.split("|")) {
                if (!/^[a-z][a-z-]*$/.test(w)) continue;
                if (pos.has(w)) use(`pos:${c}:${w}`, where);
                else errors.push(`${where}: \`vela ${c} ${w}\` - '${w}' is not one of ${[...pos].join(", ")}`);
              }
            }
        }
        for (const o of optionsIn(words.slice(1))) {
          if (!cmds.length) { // `vela <command> --help`: the option must exist on some command
            if (!allOptions.has(o)) errors.push(`${where}: \`${o}\` - no command of the snapshot has it`);
            else use(`anyopt:${o}`, where);
            continue;
          }
          for (const c of cmds) {
            const canon = m.commands.get(c).options.get(o);
            if (!canon) { errors.push(`${where}: \`vela ${c} ${o}\` - '${o}' is not an option of '${c}' in the snapshot`); continue; }
            use(`opt:${c}:${canon}`, where);
            if (o !== canon) use(`optalias:${c}:${o}`, where);
          }
        }
      }
    }
  }
  return { errors, uses, invocations };
}

// ---------- offline checks ----------
async function versionChecks() {
  const errors = [];
  if (!VERSION_RE.test(snapshotVersion)) errors.push(`contract/vela-cli.version: '${snapshotVersion}' is not x.y.z`);
  if (snapshot.version !== snapshotVersion) errors.push(`contract/vela-help.json: version '${snapshot.version}' != contract/vela-cli.version '${snapshotVersion}'`);
  const surface = await fs.readFile(path.join(root, "references", "cli-surface.md"), "utf8");
  const verified = surface.match(/Verified against:\*\*\s*`vela (\d+\.\d+\.\d+)`/)?.[1];
  if (verified !== snapshotVersion) errors.push(`references/cli-surface.md: "Verified against" vela ${verified ?? "(missing)"} != contract/vela-cli.version ${snapshotVersion}`);
  const install = await fs.readFile(path.join(root, "docs", "install.md"), "utf8");
  const minimum = install.match(/minimum Vela CLI version is `(\d+\.\d+\.\d+)`/i)?.[1];
  if (minimum !== snapshotVersion) errors.push(`docs/install.md: minimum Vela CLI ${minimum ?? "(missing: 'The minimum Vela CLI version is `x.y.z`')"} != contract/vela-cli.version ${snapshotVersion}`);
  return errors;
}

// ---------- drift ----------
function installCli(version) {
  const dir = path.join(os.tmpdir(), `vela-cli-contract-${process.pid}`);
  const install = ["tool", "install", "Vela.Cli", "--tool-path", dir, ...(version ? ["--version", version] : [])];
  const r = spawnSync("dotnet", install, { encoding: "utf8" });
  if (r.status !== 0) { console.error(`dotnet ${install.join(" ")} failed:\n${r.stdout}${r.stderr}`); process.exit(2); }
  const exe = path.join(dir, process.platform === "win32" ? "vela.exe" : "vela");
  const h = spawnSync(exe, ["help", "--json"], { encoding: "utf8" });
  if (h.status !== 0) { console.error(`vela help --json failed (exit ${h.status}):\n${h.stderr}`); process.exit(2); }
  return { doc: JSON.parse(h.stdout), cleanup: () => fs.rm(dir, { recursive: true, force: true }) };
}

const required = (o) => o.required === true || /^Required\b/.test(o.description || "");
const sameList = (a = [], b = []) => JSON.stringify(a) === JSON.stringify(b);

// Structural diff old -> new. Each item: { what, level: "breaking" | "info", uses: [file:line] }.
function diff(oldDoc, newDoc, uses) {
  const items = [];
  const at = (keys) => [...new Set(keys.flatMap((k) => uses.get(k) || []))];
  const add = (what, keys) => { const u = keys ? at(keys) : []; items.push({ what, level: u.length ? "breaking" : "info", uses: u }); };
  const info = (what) => items.push({ what, level: "info", uses: [] });
  const o = model(oldDoc), n = model(newDoc);

  for (const [name, { cmd }] of o.commands) {
    const now = n.commands.get(name);
    if (!now) {
      const renamed = [...n.commands.keys()].filter((k) => !o.commands.has(k));
      add(`command \`${name}\` removed${renamed.length ? ` (possible rename: ${renamed.map((r) => `\`${r}\``).join(", ")} added)` : ""}`, [`cmd:${name}`]);
      continue;
    }
    for (const a of cmd.aliases || []) if (!(now.cmd.aliases || []).includes(a)) add(`command alias \`${a}\` of \`${name}\` removed`, [`alias:${name}:${a}`]);
    for (const a of now.cmd.aliases || []) if (!(cmd.aliases || []).includes(a)) info(`command alias \`${a}\` of \`${name}\` added`);
    if (cmd.summary !== now.cmd.summary) info(`\`${name}\` summary changed: "${now.cmd.summary}"`);
    if (!sameList(cmd.usage, now.cmd.usage)) info(`\`${name}\` usage changed: ${(now.cmd.usage || []).map((u) => `\`${u}\``).join("; ")}`);
    const oldPos = o.commands.get(name).positionals, newPos = now.positionals;
    if (oldPos) for (const w of oldPos) if (!newPos || !newPos.has(w)) add(`\`${name} ${w}\` no longer in the usage`, [`pos:${name}:${w}`]);

    const oldOpts = new Map((cmd.options || []).map((x) => [x.name, x]));
    const newOpts = new Map((now.cmd.options || []).map((x) => [x.name, x]));
    const removed = [...oldOpts.keys()].filter((k) => !newOpts.has(k));
    const added = [...newOpts.keys()].filter((k) => !oldOpts.has(k));
    for (const r of removed)
      add(`\`${name} ${r}\` removed${added.length ? ` (possible rename: ${added.map((a) => `\`${a}\``).join(", ")} added)` : ""}`, [`opt:${name}:${r}`, `anyopt:${r}`]);
    for (const a of added) info(`\`${name} ${a}\` added${required(newOpts.get(a)) ? " (required)" : ""}`);
    for (const [k, was] of oldOpts) {
      const is = newOpts.get(k);
      if (!is) continue;
      for (const al of was.aliases || []) if (!(is.aliases || []).includes(al)) add(`\`${name} ${al}\` (alias of \`${k}\`) removed`, [`optalias:${name}:${al}`]);
      for (const al of is.aliases || []) if (!(was.aliases || []).includes(al)) info(`\`${name} ${al}\` added as an alias of \`${k}\``);
      if (was.kind !== is.kind) add(`\`${name} ${k}\` kind changed: ${was.kind} -> ${is.kind}`, [`opt:${name}:${k}`]);
      else if (was.value !== is.value) info(`\`${name} ${k}\` value placeholder changed: <${was.value}> -> <${is.value}>`);
      if (!required(was) && required(is)) add(`\`${name} ${k}\` became required`, [`cmd:${name}`]);
      else if (required(was) && !required(is)) info(`\`${name} ${k}\` no longer required`);
      else if (was.description !== is.description) info(`\`${name} ${k}\` description changed: "${is.description}"`);
    }
  }
  for (const name of n.commands.keys()) if (!o.commands.has(name)) info(`command \`${name}\` added`);

  const oe = oldDoc.exitCodes || {}, ne = newDoc.exitCodes || {};
  for (const [code, meaning] of Object.entries(oe)) {
    if (!(code in ne)) add(`exit code ${code} ("${meaning}") removed`, [`exit:${code}`]);
    else if (ne[code] !== meaning) add(`exit code ${code} changed: "${meaning}" -> "${ne[code]}"`, [`exit:${code}`]);
  }
  for (const [code, meaning] of Object.entries(ne)) if (!(code in oe)) info(`exit code ${code} added: "${meaning}"`);
  return items;
}

function reportMarkdown(cliVersion, items, schemaChanged, mode) {
  const b = items.filter((i) => i.level === "breaking"), inf = items.filter((i) => i.level === "info");
  const out = [`# Vela CLI ${cliVersion} changes the contract`, ""];
  out.push(`\`vela help --json\` of Vela.Cli ${cliVersion} (${mode}) differs from the snapshot \`contract/vela-help.json\` (${snapshotVersion}).`, "");
  if (schemaChanged) out.push(`**schemaVersion changed: ${snapshot.schemaVersion} -> ${schemaChanged}** - the document format changed; the diff below may be incomplete.`, "");
  out.push(`## Breaking - the pack uses it (${b.length})`, "");
  if (!b.length) out.push("None.");
  for (const i of b) out.push(`- ${i.what}`, ...i.uses.map((u) => `  - \`${u}\``));
  out.push("", `## Information (${inf.length})`, "");
  if (!inf.length) out.push("None.");
  for (const i of inf) out.push(`- ${i.what}`);
  out.push("", "## Update", "", "One pull request (RELEASING.md, \"Vela CLI contract\"): review every skill and doc listed above, refresh",
    "`contract/` (`node scripts/check-cli-contract.mjs --latest --update`), align `references/cli-surface.md` and",
    "`docs/install.md`, run `sh scripts/check.sh`, and decide whether the pack needs a release.", "");
  return out.join("\n");
}

// ---------- main ----------
const snapModel = model(snapshot);
if (opt.mode === "offline") {
  const errors = await versionChecks();
  const { errors: usage, invocations } = await scan(snapModel);
  errors.push(...usage);
  for (const e of errors) console.error(`ERROR ${e}`);
  console.log(`\ncheck-cli-contract: vela ${snapshotVersion}, ${invocations} invocation(s) checked, ${errors.length} error(s).`);
  process.exit(errors.length ? 1 : 0);
}

let current, cleanup = async () => {};
if (opt.against) current = JSON.parse(await fs.readFile(path.resolve(opt.against), "utf8"));
else ({ doc: current, cleanup } = installCli(opt.mode === "pinned" ? snapshotVersion : null));
const cliVersion = current.version || "unknown";
const { uses } = await scan(snapModel);
const schemaChanged = current.schemaVersion !== snapshot.schemaVersion ? current.schemaVersion : null;
let items = diff(snapshot, current, uses);
let failed = !!schemaChanged || items.some((i) => i.level === "breaking");
if (opt.mode === "pinned") {
  // The snapshot must be exactly the output of its own version.
  const same = serialize(current) === serialize(snapshot);
  if (!same && !items.length) items = [{ what: "the document differs from the snapshot outside the compared structure (version or key layout)", level: "info", uses: [] }];
  failed = !same;
  if (cliVersion !== snapshotVersion) { console.error(`installed ${cliVersion}, expected ${snapshotVersion}`); failed = true; }
}

console.log(`Vela.Cli ${cliVersion} (${opt.against ? `--against ${opt.against}` : opt.mode}) vs snapshot ${snapshotVersion}:`);
if (schemaChanged) console.log(`FAIL  schemaVersion ${snapshot.schemaVersion} -> ${schemaChanged}: the document format changed`);
for (const i of items) {
  console.log(`${i.level === "breaking" ? "BREAKING" : "info    "}  ${i.what}`);
  for (const u of i.uses) console.log(`            used at ${u}`);
}
if (!items.length && !schemaChanged) console.log("no difference");

if (opt.report) {
  if (items.length || schemaChanged) await fs.writeFile(opt.report, reportMarkdown(cliVersion, items, schemaChanged, opt.against ? "--against" : `--${opt.mode}`));
  else await fs.rm(opt.report, { force: true });
}
if (opt.update) {
  await fs.mkdir(path.dirname(CONTRACT_JSON), { recursive: true });
  await fs.writeFile(CONTRACT_JSON, serialize(current));
  await fs.writeFile(CONTRACT_VERSION, cliVersion + "\n");
  console.log(`contract/ updated to ${cliVersion} - align references/cli-surface.md and docs/install.md, then sh scripts/check.sh`);
  failed = false;
}
await cleanup();
console.log(`\ncheck-cli-contract --${opt.mode}: ${items.filter((i) => i.level === "breaking").length} breaking, ${items.filter((i) => i.level === "info").length} info${schemaChanged ? ", schemaVersion changed" : ""}.`);
process.exit(failed ? 1 : 0);
