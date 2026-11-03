#:package Microsoft.CodeAnalysis.CSharp@4.14.0
// spec-check - guard the functional spec of the tests (vela-agentic).
//
//   dotnet run <pack>/tools/spec-check.cs -- --base <ref> --canvas docs/features/<slug>/README.md [--repo .]
//
// Compares the story (fork point of <base>...HEAD) in a Vela project and fails (exit 1) when:
//   1. a rule section in docs/rules/*.md changed or was added but its id is not declared in the Canvas `rules:`;
//   2. a rule section was deleted while the Canvas does not declare it `retire`;
//   3. docs/rules/ changed in a commit made after the build started (a commit touching src/ or tests/), unless the
//      rule is listed in the Canvas `amendments:` (a review-driven amendment recorded in the Sync log);
//   4. an existing test (a method carrying [Trait("Case", "<RULE>/<case>")] at the fork point) was modified or deleted
//      while <RULE> is not `change` / `retire` in the Canvas;
//   5. a test cites a case the registry does not contain, or a new test cites none (every test proves a case);
//   6. tests/ or docs/rules/ hold uncommitted changes (the check reads history - commit first);
//   7. a rule id or an ADR number is used twice at HEAD, or one the story adds is already taken at the tip of <base>
//      (`git fetch` first and pass the latest base; renumber this story's).
// Only for projects with a docs/rules/ registry (none: nothing to check, exit 0). A rule's trace lines
// (`Implementation:` / `Tests:`) are not spec. Test bodies are compared as syntax (whitespace and comments ignored);
// harness plumbing - the trigger, stage and mode calls of Vela.Plugins' step API, read from the Vela.Plugins.dll
// the project references - does not make a test "modified". Read-only: runs git, writes nothing.
// Exit: 0 clean, 1 violations, 2 cannot check (bad base, Vela.Plugins not restored).
using System.Diagnostics;
using System.Reflection.Metadata;
using System.Reflection.PortableExecutable;
using System.Text.RegularExpressions;
using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp;
using Microsoft.CodeAnalysis.CSharp.Syntax;

string Arg(string name, string? fallback = null)
{
    int i = Array.IndexOf(args, name);
    return i >= 0 && i + 1 < args.Length ? args[i + 1] : fallback ?? throw new ArgumentException($"{name} is required");
}

string repo = Arg("--repo", "."), baseRef = Arg("--base"), canvasPath = Arg("--canvas");
var fails = new List<string>();

string Git(params string[] a)
{
    var psi = new ProcessStartInfo("git") { RedirectStandardOutput = true, RedirectStandardError = true };
    psi.ArgumentList.Add("-C"); psi.ArgumentList.Add(repo);
    foreach (var x in a) psi.ArgumentList.Add(x);
    using var p = Process.Start(psi)!;
    string o = p.StandardOutput.ReadToEnd(); p.StandardError.ReadToEnd(); p.WaitForExit();
    return p.ExitCode == 0 ? o : "";
}
string[] Lines(string s) => s.Split('\n', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
string Show(string rev, string file) => Git("show", $"{rev}:{file}");

bool IsRules(string f) => Regex.IsMatch(f, @"(^|/)docs/rules/[^/]+\.md$");

if (Git("rev-parse", "--verify", "--quiet", baseRef + "^{commit}") == "")
{
    Console.WriteLine($"spec-check: base '{baseRef}' is not a commit in {repo} - nothing was checked");
    return 2;
}
string[] headFiles = Lines(Git("ls-tree", "-r", "--name-only", "HEAD"));
if (!headFiles.Any(IsRules))
{
    Console.WriteLine("spec-check: no docs/rules/ registry in this project - nothing to check");
    return 0;
}
string fork = Git("merge-base", baseRef, "HEAD").Trim();

// --- Canvas declarations --------------------------------------------------------------------------------------
string canvas = File.ReadAllText(Path.Combine(repo, canvasPath));
var declared = Regex.Matches(canvas, @"\{\s*id:\s*([A-Z]+-\d+)\s*,\s*change:\s*(add|change|retire)\s*\}")
    .ToDictionary(m => m.Groups[1].Value, m => m.Groups[2].Value);
var am = Regex.Match(canvas, @"^amendments:[ \t]*(\[[^\]]*\]|(\r?\n[ \t]*-.*)+)", RegexOptions.Multiline);   // inline or block list
var amended = am.Success ? Regex.Matches(am.Groups[1].Value, @"[A-Z]+-\d+").Select(m => m.Value).ToHashSet() : [];

// --- Registry ---------------------------------------------------------------------------------------------------
var trace = new Regex(@"^\s*(Implementation|Tests):.*$", RegexOptions.Multiline);
Dictionary<string, string> Sections(string text)
{
    var o = new Dictionary<string, string>(); string? cur = null; var buf = new List<string>();
    void Flush() { if (cur != null) o[cur] = Regex.Replace(trace.Replace(string.Join("\n", buf), ""), @"\s+", " ").Trim(); }
    foreach (var line in text.Split('\n'))
    {
        var m = Regex.Match(line, @"^###\s+([A-Z]+-\d+)\b");
        if (m.Success) { Flush(); cur = m.Groups[1].Value; buf = [line]; }
        else if (line.StartsWith("# ") && cur != null) { Flush(); cur = null; buf = []; }
        else if (cur != null) buf.Add(line);
    }
    Flush();
    return o;
}
HashSet<string> ChangedIds(string before, string after)
{
    var b = Sections(before); var a = Sections(after);
    return b.Keys.Union(a.Keys).Where(k => b.GetValueOrDefault(k) != a.GetValueOrDefault(k)).ToHashSet();
}

string[] changed = Lines(Git("diff", "--name-only", $"{baseRef}...HEAD"));

// 1-2. registry sections
foreach (var f in changed.Where(IsRules))
{
    var before = Sections(Show(fork, f)); var after = Sections(Show("HEAD", f));
    foreach (var (rid, txt) in before)
    {
        if (!after.ContainsKey(rid))
        { if (declared.GetValueOrDefault(rid) != "retire") fails.Add($"{f}: rule {rid} was deleted but is not declared `retire` in the Canvas rules:"); }
        else if (after[rid] != txt && !declared.ContainsKey(rid) && !amended.Contains(rid))
            fails.Add($"{f}: rule {rid} changed but is not declared in the Canvas rules:");
    }
    foreach (var rid in after.Keys.Where(k => !before.ContainsKey(k) && !declared.ContainsKey(k)))
        fails.Add($"{f}: rule {rid} added but is not declared in the Canvas rules:");
}

// 3. registry edited after the build started
bool started = false;
foreach (var c in Lines(Git("rev-list", "--reverse", $"{baseRef}..HEAD")))
{
    var files = Lines(Git("show", "--name-only", "--format=", c));
    var ids = files.Where(IsRules).SelectMany(x => ChangedIds(Show(c + "^", x), Show(c, x))).ToHashSet();
    ids.ExceptWith(amended);
    if (started && ids.Count > 0)
        fails.Add($"commit {c[..8]} edits rule(s) {string.Join(", ", ids.Order())} after the build started without an " +
                  "`amendments:` entry in the Canvas (spec is read-only in the build)");
    if (files.Any(x => Regex.IsMatch(x, @"(^|/)(src|tests)/"))) started = true;
}

// 4-5. tests
var plumbing = Plumbing();
if (plumbing == null) return 2;
var cases = headFiles.Where(IsRules).SelectMany(f => Regex.Matches(Show("HEAD", f), @"\b[A-Z]+-\d+/C\d+\b").Select(m => m.Value)).ToHashSet();
var forkFiles = Lines(Git("ls-tree", "-r", "--name-only", fork)).ToHashSet();
foreach (var f in changed.Where(x => x.EndsWith(".cs") && Regex.IsMatch(x, @"(^|/)tests/")))
{
    var before = Tests(forkFiles.Contains(f) ? Show(fork, f) : "");
    var after = Tests(Show("HEAD", f));
    foreach (var (key, (cs, body)) in before)
        foreach (var cse in cs)
        {
            string rid = cse.Split('/')[0];
            if (declared.GetValueOrDefault(rid) is "change" or "retire") continue;
            if (!after.TryGetValue(key, out var now))
                fails.Add($"{f}: regression test {key.Method} ({cse}) deleted, but {rid} is not changed/retired by the story");
            else if (now.Body != body)
                fails.Add($"{f}: regression test {key.Method} ({cse}) modified, but {rid} is not changed/retired by the story");
        }
    foreach (var (key, (cs, _)) in after)
    {
        foreach (var cse in cs.Where(x => !cases.Contains(x)))
            fails.Add($"{f}: test {key.Method} cites case {cse}, which the registry does not contain");
        if (!before.ContainsKey(key) && cs.Count == 0)
            fails.Add($"{f}: new test {key.Method} has no [Trait(\"Case\", ...)] id - every test proves a registry case");
    }
}

// 6. uncommitted spec / test edits would escape the history-based checks above
foreach (var l in Git("status", "--porcelain").Split('\n').Where(l => l.Length > 3))
    if (Regex.IsMatch(l[3..], @"(^|/)(tests|docs/rules)/"))
        fails.Add($"{l[3..]}: uncommitted change - commit before spec-check (it reads history)");

// 7. ids unique: twice at HEAD, or added by the story while the tip of <base> already has it (nothing is merged)
var head = IdsAt("HEAD", fails); var atFork = IdsAt(fork, []); var tip = IdsAt(baseRef, []);
foreach (var key in head.Keys.Except(atFork.Keys).Order())
    if (tip.TryGetValue(key, out var where))
        fails.Add($"{key} added by this story is already taken on {baseRef} ({where}) - renumber this story's");

foreach (var x in fails) Console.WriteLine("FAIL  " + x);
Console.WriteLine($"spec-check: {fails.Count} failure(s)");
return fails.Count > 0 ? 1 : 0;

// --- helpers ----------------------------------------------------------------------------------------------------

Dictionary<string, string> IdsAt(string rev, List<string> dup)
{
    var seen = new Dictionary<string, string>();
    foreach (var f in Lines(Git("ls-tree", "-r", "--name-only", rev)))
    {
        var adr = Regex.Match(f, @"(^|/)docs/adr/(\d{4})-[^/]*\.md$");
        if (!adr.Success && !IsRules(f)) continue;
        var ids = adr.Success ? [adr.Groups[2].Value]
            : Regex.Matches(Show(rev, f), @"^###\s+([A-Z]+-\d+)\b", RegexOptions.Multiline).Select(m => m.Groups[1].Value).ToList();
        foreach (var i in ids)
        {
            string key = (adr.Success ? "ADR " : "rule ") + i;
            if (seen.TryGetValue(key, out var first)) dup.Add($"{key} is used twice at {rev} ({first}, {f}) - renumber the newer story's");
            else seen[key] = f;
        }
    }
    return seen;
}

// {(class, method): (case ids, normalized body)} for xUnit tests ([Fact]/[Theory]); class-level Case traits apply
// to every test of the class. The body is its tokens without trivia, with the plumbing calls removed.
Dictionary<(string Class, string Method), (List<string> Cases, string Body)> Tests(string source)
{
    var o = new Dictionary<(string, string), (List<string>, string)>();
    if (source.Length == 0) return o;
    var root = CSharpSyntaxTree.ParseText(source).GetRoot();
    foreach (var m in root.DescendantNodes().OfType<MethodDeclarationSyntax>())
    {
        if (!m.AttributeLists.SelectMany(l => l.Attributes).Any(a => Regex.IsMatch(Name(a), @"(Fact|Theory)$"))) continue;
        var cls = m.Ancestors().OfType<TypeDeclarationSyntax>().ToList();
        var attrs = m.AttributeLists.Concat(cls.SelectMany(c => c.AttributeLists)).SelectMany(l => l.Attributes);
        var cs = attrs.Where(a => Name(a) == "Trait" && a.ArgumentList?.Arguments.Count == 2 && Literal(a, 0) == "Case")
                      .Select(a => Literal(a, 1)).OfType<string>().ToList();
        SyntaxNode? body = (SyntaxNode?)m.Body ?? m.ExpressionBody;
        string norm = body == null ? "" : string.Concat(new StripPlumbing(plumbing!).Visit(body).DescendantTokens().Select(t => t.Text));
        o[(string.Join(".", cls.Select(c => c.Identifier.Text).Reverse()), m.Identifier.Text)] = (cs, norm);
    }
    return o;
}
static string Name(AttributeSyntax a) => Regex.Replace(a.Name.ToString().Split('.').Last(), "Attribute$", "");
static string? Literal(AttributeSyntax a, int i) =>
    a.ArgumentList!.Arguments[i].Expression is LiteralExpressionSyntax l ? l.Token.ValueText : null;

// The plumbing: method names of Vela.Plugins' step API that pick the trigger (IStepTrigger<T>, On...), the stage
// (I*Stages<T>) or the mode (I*Mode<T>) - read from the Vela.Plugins.dll the project references, never a copied list.
HashSet<string>? Plumbing()
{
    var refs = headFiles.Where(f => f.EndsWith(".csproj"))
        .Select(f => Regex.Match(Show("HEAD", f), @"Include=""Vela\.Plugins""\s+Version=""([^""]+)""")).Where(m => m.Success)
        .Select(m => m.Groups[1].Value).Distinct().ToList();
    string packages = Environment.GetEnvironmentVariable("NUGET_PACKAGES")
        ?? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), ".nuget", "packages");
    string? dll = refs.Select(v => Path.Combine(packages, "vela.plugins", v, "lib")).Where(Directory.Exists)
        .SelectMany(d => Directory.GetFiles(d, "Vela.Plugins.dll", SearchOption.AllDirectories)).FirstOrDefault();
    if (dll == null)
    {
        Console.WriteLine($"spec-check: Vela.Plugins {string.Join("/", refs)} not found under {packages} - restore the project (dotnet build) first");
        return null;
    }
    using var pe = new PEReader(File.OpenRead(dll));
    var md = pe.GetMetadataReader();
    var names = new HashSet<string>();
    foreach (var th in md.TypeDefinitions)
    {
        var t = md.GetTypeDefinition(th);
        if (md.GetString(t.Namespace) != "Vela.Steps") continue;
        string tn = Regex.Replace(md.GetString(t.Name), @"`\d+$", "");
        if (!(tn == "IStepTrigger" || Regex.IsMatch(tn, @"^I\w*Stages$") || Regex.IsMatch(tn, @"^I\w*Mode$"))) continue;
        foreach (var mh in t.GetMethods())
        {
            var m = md.GetMethodDefinition(mh);
            if ((m.Attributes & System.Reflection.MethodAttributes.Public) != 0) names.Add(md.GetString(m.Name));
        }
    }
    if (args.Contains("--list-plumbing")) Console.WriteLine($"plumbing ({Path.GetFileName(Path.GetDirectoryName(Path.GetDirectoryName(Path.GetDirectoryName(dll))))}): {string.Join(" ", names.Order())}");
    return names;
}

// Removes `.Name(...)` / `.Name<T>(...)` from a call chain when Name is a plumbing method.
sealed class StripPlumbing(HashSet<string> names) : CSharpSyntaxRewriter
{
    public override SyntaxNode? VisitInvocationExpression(InvocationExpressionSyntax node) =>
        node.Expression is MemberAccessExpressionSyntax ma && names.Contains(ma.Name.Identifier.Text)
            ? Visit(ma.Expression)
            : base.VisitInvocationExpression(node);
}
