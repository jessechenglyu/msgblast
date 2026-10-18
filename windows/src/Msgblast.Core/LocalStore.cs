using System.Text.Json;
using System.Text.Json.Serialization;

namespace Msgblast.Core;

/// <summary>
/// App-owned state in %APPDATA%\msgblast-Windows (or msgblast-Windows-Demo).
/// Writes are atomic. An unreadable state file is never replaced with an empty store:
/// the store becomes read-only and the original bytes stay on disk.
/// </summary>
public sealed class LocalStore
{
    public static readonly JsonSerializerOptions Json = new()
    {
        WriteIndented = true,
        Converters = { new JsonStringEnumConverter() },
    };

    public string Directory { get; }
    public string StatePath => Path.Combine(Directory, "state.json");
    public string SessionsDirectory => Path.Combine(Directory, "sessions");
    public string? LoadError { get; private set; }
    public bool IsReadOnly => LoadError is not null;

    public LocalStore(string directory) { Directory = directory; }

    public static string DefaultDirectory(bool demo) => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
        demo ? "msgblast-Windows-Demo" : "msgblast-Windows");

    public AppState Load()
    {
        LoadError = null;
        if (!File.Exists(StatePath)) return new AppState();
        try
        {
            var state = JsonSerializer.Deserialize<AppState>(File.ReadAllText(StatePath), Json)
                ?? throw new JsonException("state.json is empty");
            if (state.Version > 1) throw new NotSupportedException($"state.json version {state.Version} is newer than this build");
            return state;
        }
        catch (Exception error) when (error is JsonException or NotSupportedException or IOException)
        {
            LoadError = $"Saved state could not be read and was left untouched: {error.Message}";
            return new AppState();
        }
    }

    public void Save(AppState state)
    {
        if (IsReadOnly) throw new InvalidOperationException(LoadError);
        System.IO.Directory.CreateDirectory(Directory);
        var temp = StatePath + ".tmp-" + Guid.NewGuid().ToString("N");
        File.WriteAllText(temp, JsonSerializer.Serialize(state, Json));
        if (File.Exists(StatePath)) File.Replace(temp, StatePath, StatePath + ".bak", ignoreMetadataErrors: true);
        else File.Move(temp, StatePath);
    }

    /// <summary>Per-agent, per-comparison working directory so CLI sessions keep a stable identity.</summary>
    public string SessionDirectory(Guid comparisonId, string agentId)
    {
        var path = Path.Combine(SessionsDirectory, comparisonId.ToString("N"), agentId);
        System.IO.Directory.CreateDirectory(path);
        return path;
    }
}
