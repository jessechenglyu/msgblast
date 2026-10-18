using System.Text.Json;

namespace Msgblast.Core;

public sealed record AgentReply(string Text, string? SessionId);

public sealed class AgentException(string message) : Exception(message);

/// <summary>
/// Argument construction and output parsing for optional CLI conversations.
/// Mirrors msgblast/Core/LocalPersonalAgent.swift (persistentConversation: true) so
/// both platforms keep the same CLI permission boundary: the installed CLI's own
/// configuration and permission rules apply, and nothing prompts interactively.
/// </summary>
public static class CliAdapters
{
    public const string AnswerFileName = "answer.txt";

    public static IReadOnlyList<string> Arguments(CliProvider provider, string scratchDirectory, string? sessionId)
    {
        switch (provider)
        {
            case CliProvider.Codex:
                var codex = new List<string> { "exec", "--skip-git-repo-check", "--color", "never",
                    "--output-last-message", Path.Combine(scratchDirectory, AnswerFileName), "--json" };
                if (sessionId is not null) { codex.Add("resume"); codex.Add(sessionId); }
                codex.Add("-");
                return codex;
            case CliProvider.Claude:
                var claude = new List<string> { "--print", "--output-format", "json", "--permission-prompts", "none" };
                if (sessionId is not null) { claude.Add("--resume"); claude.Add(sessionId); }
                else { claude.Add("--session-id"); claude.Add(Guid.NewGuid().ToString()); }
                return claude;
            default:
                throw new ArgumentOutOfRangeException(nameof(provider));
        }
    }

    /// <summary>Parses a successful CLI run. Throws when the reply or session identity is missing or inconsistent.</summary>
    public static AgentReply ParseReply(CliProvider provider, string stdout, string? answerFileText, string? expectedSessionId)
    {
        string? session = null;
        string text;
        if (provider == CliProvider.Codex)
        {
            var completed = false;
            foreach (var line in stdout.Split('\n'))
            {
                if (!TryParse(line.Trim(), out var record)) continue;
                var type = record.TryGetProperty("type", out var t) ? t.GetString() : null;
                if (type is "turn.failed" or "error") throw new AgentException("Codex CLI reported a failed turn.");
                if (type == "turn.completed") completed = true;
                if (type == "thread.started" && record.TryGetProperty("thread_id", out var id) && Guid.TryParse(id.GetString(), out _))
                    session = id.GetString();
            }
            if (!completed) throw new AgentException("Codex CLI did not complete the turn.");
            text = answerFileText ?? "";
        }
        else
        {
            if (!TryParse(stdout.Trim(), out var record)) throw new AgentException("Claude Code returned an unreadable response.");
            if (record.TryGetProperty("is_error", out var isError) && isError.ValueKind == JsonValueKind.True)
                throw new AgentException("Claude Code reported an error.");
            if (record.TryGetProperty("error", out var err) && err.ValueKind != JsonValueKind.Null)
                throw new AgentException("Claude Code reported an error.");
            if (!record.TryGetProperty("result", out var result) || result.ValueKind != JsonValueKind.String)
                throw new AgentException("Claude Code returned no reply.");
            text = result.GetString()!;
            if (record.TryGetProperty("permission_denials", out var denials) && denials.ValueKind == JsonValueKind.Array && denials.GetArrayLength() > 0)
                text += $"\n\nClaude Code denied {denials.GetArrayLength()} requested action(s) under its permission rules. Those actions were not completed. Review permissions in the CLI before trying again.";
            if (record.TryGetProperty("session_id", out var sid) && Guid.TryParse(sid.GetString(), out _)) session = sid.GetString();
        }
        text = text.Trim();
        if (text.Length == 0) throw new AgentException($"{Name(provider)} returned an empty reply.");
        if (session is null) throw new AgentException($"{Name(provider)} did not report a conversation id.");
        if (expectedSessionId is not null && !string.Equals(session, expectedSessionId, StringComparison.OrdinalIgnoreCase))
            throw new AgentException($"{Name(provider)} resumed a different conversation than expected.");
        return new AgentReply(text, session);
    }

    public static string Name(CliProvider provider) => provider == CliProvider.Codex ? "Codex CLI" : "Claude Code";

    public static string Executable(CliProvider provider) => provider == CliProvider.Codex ? "codex" : "claude";

    private static bool TryParse(string text, out JsonElement element)
    {
        element = default;
        if (text.Length == 0 || text[0] != '{') return false;
        try { element = JsonDocument.Parse(text).RootElement.Clone(); return true; }
        catch (JsonException) { return false; }
    }
}
