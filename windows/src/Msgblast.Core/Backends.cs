using System.Diagnostics;
using System.Text;

namespace Msgblast.Core;

public interface IAgentBackend
{
    Task<AgentReply> ReplyAsync(AgentDefinition agent, AgentThread thread, string prompt, string workingDirectory, CancellationToken cancellation);
}

/// <summary>Demo fixture backend: deterministic local replies, never contacts any service.</summary>
public sealed class MockBackend(TimeSpan? delay = null) : IAgentBackend
{
    private readonly TimeSpan delay = delay ?? TimeSpan.FromMilliseconds(400);

    public async Task<AgentReply> ReplyAsync(AgentDefinition agent, AgentThread thread, string prompt, string workingDirectory, CancellationToken cancellation)
    {
        await Task.Delay(delay, cancellation);
        var session = thread.SessionId ?? Guid.NewGuid().ToString();
        var turn = thread.Turns.Count(t => t.Role == TurnRole.User);
        var words = prompt.Split(' ', StringSplitOptions.RemoveEmptyEntries).Length;
        return new AgentReply($"[{agent.Name} — simulated fixture reply #{turn}] I read your {words}-word question: \"{Clip(prompt)}\". No real service was contacted.", session);
    }

    private static string Clip(string text) => text.Length <= 80 ? text : text[..77] + "...";
}

/// <summary>
/// Runs Codex CLI / Claude Code as hidden child processes (no console window), with file-backed
/// stdin/stdout, a timeout, cancellation and whole-tree cleanup.
/// </summary>
public sealed class CliBackend(TimeSpan? timeout = null) : IAgentBackend
{
    private const int MaxBytes = 4_000_000;
    private readonly TimeSpan timeout = timeout ?? TimeSpan.FromSeconds(180);

    public async Task<AgentReply> ReplyAsync(AgentDefinition agent, AgentThread thread, string prompt, string workingDirectory, CancellationToken cancellation)
    {
        if (agent.Kind != AgentKind.Cli || agent.Provider is not { } provider || agent.ExecutablePath is null)
            throw new AgentException($"{agent.Name} is not a CLI agent.");
        if (Encoding.UTF8.GetByteCount(prompt) > 2_000_000) throw new AgentException("The message is too large.");
        var scratch = Path.Combine(Path.GetTempPath(), "msgblast-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(scratch);
        Directory.CreateDirectory(workingDirectory);
        try
        {
            var start = StartInfo(agent.ExecutablePath, CliAdapters.Arguments(provider, scratch, thread.SessionId), workingDirectory);
            using var process = new Process { StartInfo = start };
            try { process.Start(); }
            catch (Exception error) { throw new AgentException($"{agent.Name} could not be started: {error.Message}"); }
            var stdoutTask = process.StandardOutput.ReadToEndAsync(cancellation);
            var stderrTask = process.StandardError.ReadToEndAsync(cancellation);
            await process.StandardInput.WriteAsync(prompt.AsMemory(), cancellation);
            process.StandardInput.Close();
            using var limit = CancellationTokenSource.CreateLinkedTokenSource(cancellation);
            limit.CancelAfter(timeout);
            try { await process.WaitForExitAsync(limit.Token); }
            catch (OperationCanceledException)
            {
                Kill(process);
                if (cancellation.IsCancellationRequested) throw;
                throw new AgentException($"{agent.Name} timed out.");
            }
            var stdout = await stdoutTask;
            await stderrTask;
            if (stdout.Length > MaxBytes) throw new AgentException($"{agent.Name} returned too much output.");
            if (process.ExitCode != 0) throw new AgentException($"{agent.Name} exited with status {process.ExitCode}.");
            var answerPath = Path.Combine(scratch, CliAdapters.AnswerFileName);
            var answer = File.Exists(answerPath) ? await File.ReadAllTextAsync(answerPath, cancellation) : null;
            return CliAdapters.ParseReply(provider, stdout, answer, thread.SessionId);
        }
        finally
        {
            try { Directory.Delete(scratch, recursive: true); } catch (IOException) { } catch (UnauthorizedAccessException) { }
        }
    }

    /// <summary>Builds a hidden-window start. .cmd/.bat shims run through cmd.exe with each argument quoted.</summary>
    public static ProcessStartInfo StartInfo(string executable, IReadOnlyList<string> arguments, string workingDirectory)
    {
        var info = new ProcessStartInfo
        {
            UseShellExecute = false,
            CreateNoWindow = true,
            WindowStyle = ProcessWindowStyle.Hidden,
            RedirectStandardInput = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            StandardOutputEncoding = Encoding.UTF8,
            StandardErrorEncoding = Encoding.UTF8,
            StandardInputEncoding = new UTF8Encoding(false),
            WorkingDirectory = workingDirectory,
        };
        info.Environment["NO_COLOR"] = "1";
        info.Environment.Remove("CLAUDECODE");
        var extension = Path.GetExtension(executable).ToLowerInvariant();
        if (extension is ".cmd" or ".bat")
        {
            info.FileName = Environment.GetEnvironmentVariable("ComSpec") ?? "cmd.exe";
            info.Arguments = "/d /s /c \"" + QuoteForCmd(executable) + " " + string.Join(' ', arguments.Select(QuoteForCmd)) + "\"";
        }
        else
        {
            info.FileName = executable;
            foreach (var argument in arguments) info.ArgumentList.Add(argument);
        }
        return info;
    }

    /// <summary>
    /// Quotes one argument for a cmd.exe command line. User text never travels as an argument
    /// (prompts go through stdin); arguments are fixed flags, app-owned paths and session ids.
    /// Characters cmd.exe can still interpret inside quotes are rejected rather than escaped.
    /// </summary>
    public static string QuoteForCmd(string argument)
    {
        if (argument.IndexOfAny(['"', '%', '\r', '\n', '\0']) >= 0)
            throw new AgentException("A CLI argument contained characters that cannot be passed safely through cmd.exe.");
        var trailing = argument.Length - argument.TrimEnd('\\').Length;
        return "\"" + argument + new string('\\', trailing) + "\"";
    }

    private static void Kill(Process process)
    {
        try { if (!process.HasExited) process.Kill(entireProcessTree: true); } catch (InvalidOperationException) { }
    }
}
