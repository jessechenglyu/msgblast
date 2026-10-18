using System.IO;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Threading;
using Msgblast.Core;

namespace Msgblast.Windows;

/// <summary>
/// Headless end-to-end check of the real WPF window with the Demo fixture backend.
/// The window is never shown: it is measured, arranged and rendered offscreen to PNG frames.
/// Writes smoke-result.json and frame-*.png to the output directory; exit code 0 means pass.
/// </summary>
public static class SmokeTest
{
    public static async Task<int> RunAsync(string output)
    {
        Directory.CreateDirectory(output);
        var dataDir = Path.Combine(output, "profile");
        if (Directory.Exists(dataDir)) Directory.Delete(dataDir, true);
        var window = new MainWindow(new LocalStore(dataDir), demo: true) { ShowActivated = false };
        var frames = new List<string>();
        void Frame(string name)
        {
            var root = (FrameworkElement)window.Content;
            var size = new Size(window.Width, window.Height);
            root.Measure(size); root.Arrange(new Rect(size)); root.UpdateLayout();
            Dispatcher.CurrentDispatcher.Invoke(() => { }, DispatcherPriority.Render);
            var bitmap = new RenderTargetBitmap((int)size.Width, (int)size.Height, 96, 96, PixelFormats.Pbgra32);
            var host = new DrawingVisual();
            using (var dc = host.RenderOpen()) dc.DrawRectangle(Brushes.White, null, new Rect(size));
            bitmap.Render(host); bitmap.Render(root);
            var encoder = new PngBitmapEncoder();
            encoder.Frames.Add(BitmapFrame.Create(bitmap));
            var path = Path.Combine(output, $"frame-{frames.Count:D2}-{name}.png");
            using (var file = File.Create(path)) encoder.Save(file);
            frames.Add(path);
        }

        Frame("empty");
        const string question = "Plan a rainy Saturday in Seattle for two adults, under $150.";
        for (var i = 1; i <= question.Length; i += 6) { window.Composer.Text = question[..Math.Min(i, question.Length)]; Frame("typing"); }
        window.Composer.Text = question;
        Frame("ready");
        var sendTask = window.SendAsync();
        await Task.Delay(50);
        Frame("pending");
        await sendTask;
        Frame("replies");
        window.Composer.Text = "Which plan is cheapest?";
        Frame("follow-up");
        await window.SendAsync();
        Frame("follow-up-replies");

        var state = new LocalStore(dataDir).Load();
        var comparison = state.Comparisons.Single();
        var delivered = comparison.Threads.Sum(t => t.Turns.Count(x => x.Role == TurnRole.Agent && x.Status == TurnStatus.Delivered));
        var pass = comparison.Threads.Count == 3 && delivered == 6 && comparison.Threads.All(t => t.SessionId is not null);
        File.WriteAllText(Path.Combine(output, "smoke-result.json"),
            $"{{\"pass\":{pass.ToString().ToLowerInvariant()},\"agents\":{comparison.Threads.Count},\"deliveredReplies\":{delivered},\"frames\":{frames.Count},\"realServicesContacted\":false}}");
        window.Close();
        return pass ? 0 : 2;
    }
}
