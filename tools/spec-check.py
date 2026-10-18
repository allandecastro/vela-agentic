#!/usr/bin/env python3
"""spec-check - guard the functional spec of the tests (vela-agentic).

    python3 spec-check.py --base <ref> --canvas docs/vela-builds/<slug>.md [--repo .]

Compares <base>...HEAD in a Vela project and fails (exit 1) when:
  1. a rule section in docs/rules/*.md changed but its id is not declared in the Canvas `rules:`;
  2. a rule section was deleted (a rule is retired, never removed);
  3. docs/rules/ changed in a commit made after the build started (a commit touching src/ or tests/);
  4. an existing test (a method carrying [Trait("Case", "<RULE>/<case>")] at <base>) was modified or deleted
     while <RULE> is not `change` / `retire` in the Canvas;
  5. a test carries a case id that the registry does not contain.
Warns (exit 0) on new tests without a Case id. Read-only: runs git, writes nothing.
"""
import argparse, os, re, subprocess, sys


def git(repo, *args):
    return subprocess.run(["git", "-C", repo, *args], capture_output=True, text=True).stdout


def canvas_rules(path):
    text = open(path, encoding="utf-8").read()
    rules = {}
    for m in re.finditer(r"\{\s*id:\s*([A-Z]+-\d+)\s*,\s*change:\s*(add|change|retire)\s*\}", text):
        rules[m.group(1)] = m.group(2)
    return rules


def rule_sections(text):
    """{id: section text} for every '### <ID> - title' section."""
    out, cur, buf = {}, None, []
    for line in (text or "").splitlines():
        m = re.match(r"^###\s+([A-Z]+-\d+)\b", line)
        if m:
            if cur: out[cur] = "\n".join(buf).strip()
            cur, buf = m.group(1), [line]
        elif line.startswith("# ") and cur:
            out[cur] = "\n".join(buf).strip(); cur, buf = None, []
        elif cur:
            buf.append(line)
    if cur: out[cur] = "\n".join(buf).strip()
    return out


def test_methods(text):
    """{(class, method): (case_ids, body)} for xUnit tests in a C# file (approximate, attribute-based)."""
    out = {}
    if not text: return out
    cls = None
    lines = text.splitlines()
    i = 0
    while i < len(lines):
        line = lines[i]
        m = re.search(r"\bclass\s+(\w+)", line)
        if m: cls = m.group(1)
        if re.search(r"\[\s*(Fact|Theory)\b", line):
            attrs, j = [], i
            while j < len(lines) and not re.search(r"\bvoid\s+\w+\s*\(", lines[j]):
                attrs.append(lines[j]); j += 1
            if j >= len(lines): break
            name = re.search(r"\bvoid\s+(\w+)\s*\(", lines[j]).group(1)
            cases = re.findall(r'Trait\(\s*"Case"\s*,\s*"([^"]+)"', "\n".join(attrs + [lines[j]]))
            depth, body, k, started = 0, [], j, False
            while k < len(lines):
                body.append(lines[k])
                depth += lines[k].count("{") - lines[k].count("}")
                if "{" in lines[k] or "=>" in lines[k]: started = True
                if started and depth <= 0 and ("}" in lines[k] or lines[k].rstrip().endswith(";")): break
                k += 1
            out[(cls, name)] = (cases, "\n".join(body))
            i = k
        i += 1
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", required=True)
    ap.add_argument("--canvas", required=True)
    ap.add_argument("--repo", default=".")
    a = ap.parse_args()
    repo, fails, warns = a.repo, [], []
    declared = canvas_rules(os.path.join(repo, a.canvas))
    changed = [f for f in git(repo, "diff", "--name-only", f"{a.base}...HEAD").split() if f]

    # 1-2. registry sections
    for f in [f for f in changed if re.match(r"(.*/)?docs/rules/[^/]+\.md$", f)]:
        before = rule_sections(git(repo, "show", f"{a.base}:{f}"))
        after = rule_sections(git(repo, "show", f"HEAD:{f}"))
        for rid, txt in before.items():
            if rid not in after:
                fails.append(f"{f}: rule {rid} was deleted - retire it (Status: retired), keep its text")
            elif after[rid] != txt and rid not in declared:
                fails.append(f"{f}: rule {rid} changed but is not declared in the Canvas rules:")
        for rid in after:
            if rid not in before and rid not in declared:
                fails.append(f"{f}: rule {rid} added but is not declared in the Canvas rules:")

    # 3. registry edited after the build started
    started = False
    for c in git(repo, "rev-list", "--reverse", f"{a.base}..HEAD").split():
        files = git(repo, "show", "--name-only", "--format=", c).split()
        if started and any(re.match(r"(.*/)?docs/rules/", x) for x in files):
            fails.append(f"commit {c[:8]} edits docs/rules/ after the build started (spec is read-only in the build)")
        if any(re.match(r"(.*/)?(src|tests)/", x) for x in files):
            started = True

    # 4-5. tests
    registry = "\n".join(git(repo, "show", f"HEAD:{f}") for f in
                         git(repo, "ls-tree", "-r", "--name-only", "HEAD").split() if re.match(r"(.*/)?docs/rules/[^/]+\.md$", f))
    base_files = set(git(repo, "ls-tree", "-r", "--name-only", a.base).split())
    for f in [f for f in changed if f.endswith(".cs") and re.match(r"(.*/)?tests/", f)]:
        before = test_methods(git(repo, "show", f"{a.base}:{f}") if f in base_files else "")
        after = test_methods(git(repo, "show", f"HEAD:{f}"))
        for key, (cases, body) in before.items():
            for case in cases:
                rid = case.split("/")[0]
                if declared.get(rid) in ("change", "retire"):
                    continue
                if key not in after:
                    fails.append(f"{f}: regression test {key[1]} ({case}) deleted, but {rid} is not changed/retired by the story")
                elif after[key][1] != body:
                    fails.append(f"{f}: regression test {key[1]} ({case}) modified, but {rid} is not changed/retired by the story")
        for key, (cases, _) in after.items():
            for case in cases:
                if case not in registry:
                    fails.append(f"{f}: test {key[1]} cites case {case}, which the registry does not contain")
            if key not in before and not cases:
                warns.append(f"{f}: new test {key[1]} has no [Trait(\"Case\", ...)] id")

    for w in warns: print("WARN ", w)
    for x in fails: print("FAIL ", x)
    print(f"spec-check: {len(fails)} failure(s), {len(warns)} warning(s)")
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
