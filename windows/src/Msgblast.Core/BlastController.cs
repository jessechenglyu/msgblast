namespace Msgblast.Core;

/// <summary>
/// Sends one message to several agents at once and records each agent's reply in its own thread.
/// A failed send is recorded as failed and is never retried automatically; the draft is kept by the UI.
/// </summary>
public sealed class BlastController(LocalStore store, IReadOnlyDictionary<AgentKind, IAgentBackend> backends)
{
    private readonly object gate = new();

    public event Action? Changed;

    public AppState State { get; private set; } = new();

    public void Load() => State = store.Load();

    public Comparison NewComparison(string firstMessage)
    {
        var comparison = new Comparison { Title = Title(firstMessage) };
        lock (gate) State.Comparisons.Insert(0, comparison);
        return comparison;
    }

    /// <summary>Blasts <paramref name="message"/> to every agent in <paramref name="recipients"/> concurrently.</summary>
    public async Task<IReadOnlyDictionary<string, Turn>> BlastAsync(Comparison comparison, IReadOnlyList<AgentDefinition> recipients,
        string message, CancellationToken cancellation = default)
    {
        if (string.IsNullOrWhiteSpace(message)) throw new ArgumentException("Message is empty.", nameof(message));
        if (recipients.Count == 0) throw new ArgumentException("Choose at least one agent.", nameof(recipients));
        var pending = new Dictionary<string, Turn>();
        lock (gate)
        {
            foreach (var agent in recipients)
            {
                var thread = comparison.Thread(agent.Id);
                thread.Turns.Add(new Turn { Role = TurnRole.User, Text = message });
                var reply = new Turn { Role = TurnRole.Agent, Status = TurnStatus.Pending };
                thread.Turns.Add(reply);
                pending[agent.Id] = reply;
            }
        }
        Persist();
        await Task.WhenAll(recipients.Select(agent => SendOneAsync(comparison, agent, message, pending[agent.Id], cancellation)));
        Persist();
        return pending;
    }

    private async Task SendOneAsync(Comparison comparison, AgentDefinition agent, string message, Turn reply, CancellationToken cancellation)
    {
        AgentThread thread;
        lock (gate) thread = comparison.Thread(agent.Id);
        try
        {
            if (!backends.TryGetValue(agent.Kind, out var backend)) throw new AgentException($"{agent.Name} is not available in this build.");
            var directory = store.SessionDirectory(comparison.Id, agent.Id);
            var result = await backend.ReplyAsync(agent, thread, message, directory, cancellation);
            lock (gate)
            {
                thread.SessionId ??= result.SessionId;
                reply.Text = result.Text;
                reply.Status = TurnStatus.Delivered;
                reply.At = DateTimeOffset.Now;
            }
        }
        catch (Exception error) when (error is AgentException or OperationCanceledException or IOException)
        {
            lock (gate)
            {
                reply.Status = TurnStatus.Failed;
                reply.Error = error is OperationCanceledException ? "Cancelled." : error.Message;
                reply.At = DateTimeOffset.Now;
            }
        }
        Changed?.Invoke();
    }

    private void Persist()
    {
        if (store.IsReadOnly) return;
        lock (gate) store.Save(State);
        Changed?.Invoke();
    }

    public static string Title(string message)
    {
        var line = message.Trim().Split('\n')[0].Trim();
        return line.Length <= 48 ? line : line[..45] + "...";
    }
}
