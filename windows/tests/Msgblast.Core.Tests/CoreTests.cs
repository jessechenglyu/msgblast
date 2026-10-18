using Msgblast.Core;
using Xunit;

namespace Msgblast.Core.Tests;

public sealed class TempDir : IDisposable
{
    public string Path { get; } = System.IO.Path.Combine(System.IO.Path.GetTempPath(), "msgblast-test-" + Guid.NewGuid().ToString("N"));
    public TempDir() => Directory.CreateDirectory(Path);
    public void Dispose() { try { Directory.Delete(Path, true); } catch (IOException) { } }
}

public class CliAdapterTests
{
    [Fact]
    public void CodexArgumentsResumeExistingSessionAndReadStdin()
    {
        var args = CliAdapters.Arguments(CliProvider.Codex, @"C:\tmp\x", "4b8f7d1e-1111-2222-3333-444455556666");
        Assert.Equal("exec", args[0]);
        Assert.Contains("--json", args);
        Assert.Equal(new[] { "resume", "4b8f7d1e-1111-2222-3333-444455556666", "-" }, args.TakeLast(3));
        Assert.Contains(System.IO.Path.Combine(@"C:\tmp\x", "answer.txt"), args);
    }

    [Fact]
    public void ClaudeArgumentsNeverPromptAndStartNewSession()
    {
        var args = CliAdapters.Arguments(CliProvider.Claude, "x", null);
        Assert.Contains("--permission-prompts", args);
        Assert.Equal("none", args[args.ToList().IndexOf("--permission-prompts") + 1]);
        var id = args[args.ToList().IndexOf("--session-id") + 1];
        Assert.True(Guid.TryParse(id, out _));
        Assert.DoesNotContain("--resume", args);
    }

    [Fact]
    public void ParsesCodexJsonEvents()
    {
        var stdout = "{\"type\":\"thread.started\",\"thread_id\":\"4b8f7d1e-1111-2222-3333-444455556666\"}\n{\"type\":\"turn.completed\"}\n";
        var reply = CliAdapters.ParseReply(CliProvider.Codex, stdout, " hello \n", null);
        Assert.Equal("hello", reply.Text);
        Assert.Equal("4b8f7d1e-1111-2222-3333-444455556666", reply.SessionId);
    }

    [Fact]
    public void RejectsIncompleteOrFailedCodexTurns()
    {
        Assert.Throws<AgentException>(() => CliAdapters.ParseReply(CliProvider.Codex,
            "{\"type\":\"thread.started\",\"thread_id\":\"4b8f7d1e-1111-2222-3333-444455556666\"}", "hi", null));
        Assert.Throws<AgentException>(() => CliAdapters.ParseReply(CliProvider.Codex,
            "{\"type\":\"turn.failed\"}\n{\"type\":\"turn.completed\"}", "hi", null));
    }

    [Fact]
    public void ParsesClaudeResultAndReportsPermissionDenials()
    {
        var stdout = "{\"result\":\"answer\",\"session_id\":\"4b8f7d1e-1111-2222-3333-444455556666\",\"permission_denials\":[{}]}";
        var reply = CliAdapters.ParseReply(CliProvider.Claude, stdout, null, null);
        Assert.StartsWith("answer", reply.Text);
        Assert.Contains("denied 1 requested action", reply.Text);
    }

    [Fact]
    public void RejectsClaudeErrorsAndSessionMismatch()
    {
        Assert.Throws<AgentException>(() => CliAdapters.ParseReply(CliProvider.Claude, "{\"is_error\":true,\"result\":\"x\"}", null, null));
        Assert.Throws<AgentException>(() => CliAdapters.ParseReply(CliProvider.Claude,
            "{\"result\":\"x\",\"session_id\":\"4b8f7d1e-1111-2222-3333-444455556666\"}", null, "00000000-1111-2222-3333-444455556666"));
    }
}

public class DetectionAndProcessTests
{
    [Fact]
    public void FindsCmdShimViaPathExt()
    {
        using var dir = new TempDir();
        File.WriteAllText(System.IO.Path.Combine(dir.Path, "codex.cmd"), "@echo off");
        var agents = AgentDetection.InstalledCliAgents(dir.Path, ".EXE;.CMD");
        var codex = Assert.Single(agents);
        Assert.Equal("codex-cli", codex.Id);
        Assert.EndsWith("codex.cmd", codex.ExecutablePath, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void StartInfoIsHiddenAndQuotesCmdArguments()
    {
        var info = CliBackend.StartInfo(@"C:\npm\claude.cmd", new[] { "--print", @"C:\a b\" }, ".");
        Assert.True(info.CreateNoWindow);
        Assert.False(info.UseShellExecute);
        Assert.Contains("\"C:\\a b\\\\\"", info.Arguments);
        Assert.Throws<AgentException>(() => CliBackend.QuoteForCmd("a%PATH%"));
    }
}

public class StoreAndBlastTests
{
    [Fact]
    public async Task BlastsToAllAgentsAndPersists()
    {
        using var dir = new TempDir();
        var store = new LocalStore(dir.Path);
        var controller = new BlastController(store, new Dictionary<AgentKind, IAgentBackend> { [AgentKind.Mock] = new MockBackend(TimeSpan.Zero) });
        controller.Load();
        var comparison = controller.NewComparison("Plan a weekend in Ojai");
        var results = await controller.BlastAsync(comparison, AgentDetection.DemoAgents, "Plan a weekend in Ojai");
        Assert.Equal(3, results.Count);
        Assert.All(results.Values, t => Assert.Equal(TurnStatus.Delivered, t.Status));
        await controller.BlastAsync(comparison, AgentDetection.DemoAgents.Take(1).ToList(), "Follow-up");
        var reloaded = new LocalStore(dir.Path).Load();
        var saved = Assert.Single(reloaded.Comparisons);
        Assert.Equal(4, saved.Thread("demo-alpha").Turns.Count);
        Assert.Equal(2, saved.Thread("demo-beta").Turns.Count);
        Assert.NotNull(saved.Thread("demo-alpha").SessionId);
    }

    [Fact]
    public async Task FailedSendIsRecordedNotRetried()
    {
        using var dir = new TempDir();
        var failing = new CountingFailBackend();
        var controller = new BlastController(new LocalStore(dir.Path), new Dictionary<AgentKind, IAgentBackend> { [AgentKind.Mock] = failing });
        var comparison = controller.NewComparison("q");
        var results = await controller.BlastAsync(comparison, AgentDetection.DemoAgents.Take(1).ToList(), "q");
        Assert.Equal(TurnStatus.Failed, results["demo-alpha"].Status);
        Assert.Equal(1, failing.Calls);
    }

    [Fact]
    public void UnreadableStateIsPreservedAndStoreBecomesReadOnly()
    {
        using var dir = new TempDir();
        var store = new LocalStore(dir.Path);
        File.WriteAllText(store.StatePath, "{ not json");
        var state = store.Load();
        Assert.Empty(state.Comparisons);
        Assert.True(store.IsReadOnly);
        Assert.Throws<InvalidOperationException>(() => store.Save(state));
        Assert.Equal("{ not json", File.ReadAllText(store.StatePath));
    }

    [Fact]
    public async Task CliBackendRejectsMissingExecutableWithoutThrowingUnexpectedly()
    {
        using var dir = new TempDir();
        var agent = AgentDefinition.Cli(CliProvider.Claude, System.IO.Path.Combine(dir.Path, "missing.exe"));
        var error = await Assert.ThrowsAsync<AgentException>(() => new CliBackend().ReplyAsync(agent, new AgentThread(), "hi", dir.Path, CancellationToken.None));
        Assert.Contains("could not be started", error.Message);
    }

    private sealed class CountingFailBackend : IAgentBackend
    {
        public int Calls;
        public Task<AgentReply> ReplyAsync(AgentDefinition agent, AgentThread thread, string prompt, string workingDirectory, CancellationToken cancellation)
        {
            Interlocked.Increment(ref Calls);
            throw new AgentException("simulated failure");
        }
    }
}
