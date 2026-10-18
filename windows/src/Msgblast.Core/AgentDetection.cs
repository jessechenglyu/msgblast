namespace Msgblast.Core;

/// <summary>Finds installed CLIs on PATH using Windows PATHEXT rules (npm installs codex/claude as .cmd shims).</summary>
public static class AgentDetection
{
    public static string? FindExecutable(string name, string? path = null, string? pathExt = null)
    {
        path ??= Environment.GetEnvironmentVariable("PATH") ?? "";
        pathExt ??= Environment.GetEnvironmentVariable("PATHEXT") ?? ".COM;.EXE;.BAT;.CMD";
        var extensions = pathExt.Split(';', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Where(e => e.StartsWith('.')).ToList();
        foreach (var directory in path.Split(Path.PathSeparator, StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
        {
            string root;
            try { root = Path.GetFullPath(directory.Trim('"')); } catch { continue; }
            foreach (var extension in extensions)
            {
                var candidate = Path.Combine(root, name + extension);
                if (File.Exists(candidate)) return candidate;
            }
        }
        return null;
    }

    public static IReadOnlyList<AgentDefinition> InstalledCliAgents(string? path = null, string? pathExt = null)
    {
        var agents = new List<AgentDefinition>();
        foreach (var provider in Enum.GetValues<CliProvider>())
        {
            var executable = FindExecutable(CliAdapters.Executable(provider), path, pathExt);
            if (executable is not null) agents.Add(AgentDefinition.Cli(provider, executable));
        }
        return agents;
    }

    public static IReadOnlyList<AgentDefinition> DemoAgents { get; } = new[]
    {
        AgentDefinition.Mock("demo-alpha", "Demo Alpha"),
        AgentDefinition.Mock("demo-beta", "Demo Beta"),
        AgentDefinition.Mock("demo-gamma", "Demo Gamma"),
    };
}
