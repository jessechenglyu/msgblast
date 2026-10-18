namespace Msgblast.Core;

/// <summary>How an agent is reached. Windows currently supports local CLIs and the Demo fixture.</summary>
public enum AgentKind { Cli, Mock }

public enum CliProvider { Codex, Claude }

public sealed record AgentDefinition(string Id, string Name, AgentKind Kind, CliProvider? Provider = null, string? ExecutablePath = null)
{
    public static AgentDefinition Cli(CliProvider provider, string executablePath) => provider switch
    {
        CliProvider.Codex => new("codex-cli", "Codex CLI", AgentKind.Cli, provider, executablePath),
        CliProvider.Claude => new("claude-code", "Claude Code", AgentKind.Cli, provider, executablePath),
        _ => throw new ArgumentOutOfRangeException(nameof(provider)),
    };

    public static AgentDefinition Mock(string id, string name) => new(id, name, AgentKind.Mock);
}

public enum TurnRole { User, Agent }

public enum TurnStatus { Pending, Delivered, Failed }

public sealed class Turn
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public TurnRole Role { get; set; }
    public string Text { get; set; } = "";
    public TurnStatus Status { get; set; } = TurnStatus.Delivered;
    public string? Error { get; set; }
    public DateTimeOffset At { get; set; } = DateTimeOffset.Now;
}

/// <summary>One agent's private conversation inside a comparison. Each agent keeps its own CLI session.</summary>
public sealed class AgentThread
{
    public string AgentId { get; set; } = "";
    public string? SessionId { get; set; }
    public List<Turn> Turns { get; set; } = new();
}

public sealed class Comparison
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string Title { get; set; } = "New Blast";
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.Now;
    public List<AgentThread> Threads { get; set; } = new();

    public AgentThread Thread(string agentId)
    {
        var thread = Threads.FirstOrDefault(t => t.AgentId == agentId);
        if (thread is null)
        {
            thread = new AgentThread { AgentId = agentId };
            Threads.Add(thread);
        }
        return thread;
    }
}

public sealed class AppState
{
    public int Version { get; set; } = 1;
    public List<Comparison> Comparisons { get; set; } = new();
    public List<string> SelectedAgentIds { get; set; } = new();
}
