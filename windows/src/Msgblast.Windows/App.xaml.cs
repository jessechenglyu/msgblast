using System.IO;
using System.Windows;
using Msgblast.Core;

namespace Msgblast.Windows;

public partial class App : Application
{
    protected override async void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);
        var args = e.Args;
        var demo = args.Contains("--demo");
        var smoke = Array.IndexOf(args, "--smoke-test");
        var dataIndex = Array.IndexOf(args, "--data-dir");
        var dataDir = dataIndex >= 0 && dataIndex + 1 < args.Length ? args[dataIndex + 1] : LocalStore.DefaultDirectory(demo);

        if (smoke >= 0)
        {
            // Headless smoke test: Demo fixture only, isolated temp profile, never shows a window.
            var output = smoke + 1 < args.Length && !args[smoke + 1].StartsWith("--") ? args[smoke + 1] : Path.Combine(Path.GetTempPath(), "msgblast-smoke");
            ShutdownMode = ShutdownMode.OnExplicitShutdown;
            int code;
            try { code = await SmokeTest.RunAsync(output); }
            catch (Exception error) { File.WriteAllText(Path.Combine(output, "smoke-error.txt"), error.ToString()); code = 1; }
            Shutdown(code);
            return;
        }

        var window = new MainWindow(new LocalStore(dataDir), demo);
        MainWindow = window;
        window.Show();
    }
}
