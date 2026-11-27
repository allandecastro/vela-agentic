#!/usr/bin/env node
// Prepares the release pull request (RELEASING.md): the only place a version changes.
//   node scripts/release.mjs vX.Y.Z
// - .claude-plugin/plugin.json and marketplace.json: X.Y.Z (must be above the current version);
// - the `metadata.version` patch of every skill, and the `# version:` line of every hook script, changed since the
//   last tag (git describe; Agent Skills frontmatter: a project that installs single skills compares them by it);
// - every tag reference in docs/ (/blob|tree/vA.B.C/, "tag `vA.B.C`") -> vX.Y.Z;
// - CHANGELOG.md: `## [Unreleased]` content moves under `## [X.Y.Z] - <today>`;
// - node scripts/sync-copilot.mjs (generated copies), then check-docs --release vX.Y.Z.
// Review the diff, add the Vela versions line to the CHANGELOG section, commit "chore(release): vX.Y.Z".

import { promises as fs } from "node:fs";
import path from "node:path";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const tag = process.argv[2];
if (!/^v\d+\.\d+\.\d+$/.test(tag ?? "")) { console.error("usage: node scripts/release.mjs vX.Y.Z"); process.exit(2); }
const version = tag.slice(1);
const git = (...a) => execFileSync("git", a, { cwd: root, encoding: "utf8" }).trim();
const read = (f) => fs.readFile(path.join(root, f), "utf8");
const write = (f, s) => fs.writeFile(path.join(root, f), s);
const num = (v) => v.split(".").map(Number);
const above = (a, b) => { const [x, y] = [num(a), num(b)]; for (let i = 0; i < 3; i++) if (x[i] !== y[i]) return x[i] > y[i]; return false; };

// Plugin version.
const plugin = JSON.parse(await read(".claude-plugin/plugin.json"));
if (!above(version, plugin.version)) { console.error(`${version} is not above the plugin's ${plugin.version}`); process.exit(1); }
const market = JSON.parse(await read(".claude-plugin/marketplace.json"));
plugin.version = market.metadata.version = version;
await write(".claude-plugin/plugin.json", JSON.stringify(plugin, null, 2) + "\n");
await write(".claude-plugin/marketplace.json", JSON.stringify(market, null, 2) + "\n");
console.log(`plugin ${version}`);

// Skills and hook scripts changed since the last tag.
let last = null;
try { last = git("describe", "--tags", "--abbrev=0", "--match", "v*"); } catch { /* no tag yet */ }
const changed = last ? git("diff", "--name-only", `${last}..HEAD`, "--", "skills/", "hooks/bin/").split("\n").filter(Boolean) : [];
const bumpPatch = (s, re, f) => {
  const out = s.replace(re, (_, k, a, b, c) => `${k}${a}.${b}.${+c + 1}`);
  if (out === s) throw new Error(`${f}: no version to bump`);
  return out;
};
for (const name of [...new Set(changed.filter((f) => f.startsWith("skills/")).map((f) => f.split("/")[1]))]) {
  const f = `skills/${name}/SKILL.md`;
  const md = await read(f).catch(() => null);
  if (md === null) continue;
  await write(f, bumpPatch(md, /^(  version: ")(\d+)\.(\d+)\.(\d+)(?=")/m, f));
  console.log(`${name}: patch bumped`);
}
for (const f of changed.filter((f) => /^hooks\/bin\/[^/]+\.sh$/.test(f))) {
  const sh = await read(f).catch(() => null);
  if (sh === null) continue;
  await write(f, bumpPatch(sh, /^(# version: )(\d+)\.(\d+)\.(\d+)$/m, f));
  console.log(`${f}: patch bumped`);
}
if (!last) console.log("no previous tag: skill and hook versions left as they are");

// docs/ tag references.
const docs = path.join(root, "docs");
for (const e of await fs.readdir(docs, { recursive: true, withFileTypes: true })) {
  if (!e.isFile() || !e.name.endsWith(".md")) continue;
  const p = path.join(e.parentPath ?? e.path, e.name);
  const md = await fs.readFile(p, "utf8");
  const out = md.replace(/\/(blob|tree)\/v\d+\.\d+\.\d+\//g, `/$1/${tag}/`).replace(/\btag `v\d+\.\d+\.\d+`/g, `tag \`${tag}\``);
  if (out !== md) await fs.writeFile(p, out);
}

// CHANGELOG.
const today = new Date().toISOString().slice(0, 10);
const log = await read("CHANGELOG.md");
if (!log.includes("## [Unreleased]\n")) { console.error("CHANGELOG.md: no ## [Unreleased] section"); process.exit(1); }
await write("CHANGELOG.md", log.replace("## [Unreleased]\n", `## [Unreleased]\n\n## [${version}] - ${today}\n`));

execFileSync("node", ["scripts/sync-copilot.mjs"], { cwd: root, stdio: "ignore" });
execFileSync("node", ["scripts/check-docs.mjs", "--release", tag], { cwd: root, stdio: "inherit" });
console.log(`\nrelease ${tag} prepared: review the diff, complete CHANGELOG [${version}], commit "chore(release): ${tag}".`);
