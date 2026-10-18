using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Input;
using System.Windows.Media;
using Msgblast.Core;

namespace Msgblast.Windows;

/// <summary>
/// Main workspace: saved comparisons on the left, agent chooser on top, one pane per agent,
/// and a shared composer that blasts the same message to every selected agent.
/// </summary>
public sealed class MainWindow : Window
{
    private readonly LocalStore store;
    private readonly BlastController controller;
    private readonly IReadOnlyList<AgentDefinition> agents;
    private readonly bool demo;
    private readonly ListBox sidebar = new() { BorderThickness = new Thickness(0), Background = Brushes.Transparent };
    private readonly WrapPanel chooser = new() { Margin = new Thickness(0, 0, 0, 8) };
    private readonly UniformGrid panes = new() { Rows = 1 };
    private readonly TextBox composer = new() { AcceptsReturn = true, TextWrapping = TextWrapping.Wrap, MinHeight = 44, MaxHeight = 140, VerticalScrollBarVisibility = ScrollBarVisibility.Auto, Padding = new Thickness(8), FontSize = 14 };
    private readonly Button send = new() { Content = "Send ➤", Margin = new Thickness(8, 0, 0, 0), MinWidth = 90 };
    private readonly TextBlock status = new() { Foreground = (Brush)Application.Current.Resources["Muted"], Margin = new Thickness(0, 6, 0, 0), TextWrapping = TextWrapping.Wrap };
    private readonly HashSet<string> selected = new();
    private Comparison? current;
    private bool sending;

    public MainWindow(LocalStore store, bool demo, IReadOnlyList<AgentDefinition>? agentsOverride = null)
    {
        this.store = store;
        this.demo = demo;
        agents = agentsOverride ?? (demo ? AgentDetection.DemoAgents : AgentDetection.InstalledCliAgents());
        var backends = new Dictionary<AgentKind, IAgentBackend> { [AgentKind.Mock] = new MockBackend() };
        if (!demo) backends[AgentKind.Cli] = new CliBackend();
        controller = new BlastController(store, backends);
        controller.Load();
        controller.Changed += () => Dispatcher.InvokeAsync(RenderPanes);

        Title = demo ? "msgblast Demo — simulated fixture" : "msgblast";
        Width = 1180; Height = 760; MinWidth = 760; MinHeight = 480;
        FontFamily = new FontFamily("Segoe UI Variable Text, Segoe UI");
        Background = Brushes.White;
        Content = Layout();

        foreach (var id in controller.State.SelectedAgentIds.Where(id => agents.Any(a => a.Id == id))) selected.Add(id);
        if (selected.Count == 0) foreach (var a in agents) selected.Add(a.Id);
        RenderChooser();
        RenderSidebar();
        RenderPanes();
        send.Click += async (_, _) => await SendAsync();
        composer.PreviewKeyDown += async (_, e) =>
        {
            if (e.Key == Key.Enter && Keyboard.Modifiers == ModifierKeys.None) { e.Handled = true; await SendAsync(); }
        };
        if (store.LoadError is { } error) status.Text = error;
        else if (agents.Count == 0) status.Text = "No supported agents found. Install Codex CLI (codex) or Claude Code (claude) and make sure it is on PATH, or launch with --demo to try simulated agents.";
    }

    public TextBox Composer => composer;
    public BlastController Controller => controller;

    private UIElement Layout()
    {
        var root = new Grid();
        root.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(240) });
        root.ColumnDefinitions.Add(new ColumnDefinition());

        var left = new DockPanel { Background = (Brush)Application.Current.Resources["Pane"] };
        var header = new StackPanel { Margin = new Thickness(16, 16, 16, 8) };
        header.Children.Add(new TextBlock { Text = "msgblast", FontSize = 20, FontWeight = FontWeights.Bold });
        header.Children.Add(new TextBlock { Text = "Ask once. Compare the answers.", Foreground = (Brush)Application.Current.Resources["Muted"] });
        var newBlast = new Button { Content = "＋ New Blast", Margin = new Thickness(0, 12, 0, 0), HorizontalAlignment = HorizontalAlignment.Stretch };
        newBlast.Click += (_, _) => { current = null; sidebar.SelectedItem = null; RenderPanes(); composer.Focus(); };
        header.Children.Add(newBlast);
        DockPanel.SetDock(header, Dock.Top);
        left.Children.Add(header);
        sidebar.Margin = new Thickness(8, 0, 8, 8);
        ScrollViewer.SetHorizontalScrollBarVisibility(sidebar, ScrollBarVisibility.Disabled);
        sidebar.HorizontalContentAlignment = HorizontalAlignment.Stretch;
        sidebar.SelectionChanged += (_, _) =>
        {
            if (sidebar.SelectedItem is ListBoxItem { Tag: Comparison c }) { current = c; RenderPanes(); }
        };
        left.Children.Add(sidebar);
        root.Children.Add(left);

        var main = new DockPanel { Margin = new Thickness(16) };
        Grid.SetColumn(main, 1);
        var top = new StackPanel();
        top.Children.Add(new TextBlock { Text = "Send to", FontWeight = FontWeights.SemiBold, Margin = new Thickness(0, 0, 0, 6) });
        top.Children.Add(chooser);
        DockPanel.SetDock(top, Dock.Top);
        main.Children.Add(top);

        var bottom = new StackPanel { Margin = new Thickness(0, 12, 0, 0) };
        var row = new DockPanel();
        DockPanel.SetDock(send, Dock.Right);
        row.Children.Add(send);
        row.Children.Add(new Border { BorderBrush = (Brush)Application.Current.Resources["Line"], BorderThickness = new Thickness(1), CornerRadius = new CornerRadius(8), Child = composer });
        bottom.Children.Add(row);
        bottom.Children.Add(status);
        DockPanel.SetDock(bottom, Dock.Bottom);
        main.Children.Add(bottom);
        main.Children.Add(panes);
        root.Children.Add(main);
        return root;
    }

    private void RenderChooser()
    {
        chooser.Children.Clear();
        foreach (var agent in agents)
        {
            var box = new CheckBox { Content = agent.Name, IsChecked = selected.Contains(agent.Id), Margin = new Thickness(0, 0, 16, 4), FontSize = 13 };
            box.Checked += (_, _) => { selected.Add(agent.Id); SaveSelection(); RenderPanes(); };
            box.Unchecked += (_, _) => { selected.Remove(agent.Id); SaveSelection(); RenderPanes(); };
            chooser.Children.Add(box);
        }
    }

    private void SaveSelection()
    {
        controller.State.SelectedAgentIds = selected.ToList();
        if (!store.IsReadOnly) store.Save(controller.State);
    }

    private void RenderSidebar()
    {
        sidebar.Items.Clear();
        foreach (var c in controller.State.Comparisons)
        {
            var item = new ListBoxItem { Tag = c, Padding = new Thickness(8, 6, 8, 6) };
            var stack = new StackPanel();
            stack.Children.Add(new TextBlock { Text = c.Title, TextTrimming = TextTrimming.CharacterEllipsis, FontWeight = FontWeights.SemiBold });
            stack.Children.Add(new TextBlock { Text = c.CreatedAt.LocalDateTime.ToString("MMM d, h:mm tt"), FontSize = 11, Foreground = (Brush)Application.Current.Resources["Muted"] });
            item.Content = stack;
            sidebar.Items.Add(item);
            if (ReferenceEquals(c, current)) sidebar.SelectedItem = item;
        }
    }

    private void RenderPanes()
    {
        panes.Children.Clear();
        var shown = agents.Where(a => selected.Contains(a.Id) || (current?.Threads.Any(t => t.AgentId == a.Id && t.Turns.Count > 0) ?? false)).ToList();
        panes.Columns = Math.Max(1, shown.Count);
        foreach (var agent in shown) panes.Children.Add(Pane(agent));
        if (shown.Count == 0)
            panes.Children.Add(new TextBlock { Text = "Choose at least one agent above.", Foreground = (Brush)Application.Current.Resources["Muted"], HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center });
    }

    private UIElement Pane(AgentDefinition agent)
    {
        var dock = new DockPanel();
        var title = new DockPanel { Margin = new Thickness(12, 10, 12, 6) };
        var kind = agent.Kind == AgentKind.Mock ? "Demo fixture" : "Local CLI";
        var tag = new TextBlock { Text = kind, FontSize = 11, Foreground = (Brush)Application.Current.Resources["Muted"], VerticalAlignment = VerticalAlignment.Center };
        DockPanel.SetDock(tag, Dock.Right);
        title.Children.Add(tag);
        title.Children.Add(new TextBlock { Text = agent.Name, FontWeight = FontWeights.Bold, FontSize = 15 });
        DockPanel.SetDock(title, Dock.Top);
        dock.Children.Add(title);
        var list = new StackPanel { Margin = new Thickness(12, 0, 12, 12) };
        var thread = current?.Threads.FirstOrDefault(t => t.AgentId == agent.Id);
        if (thread is null || thread.Turns.Count == 0)
            list.Children.Add(new TextBlock { Text = selected.Contains(agent.Id) ? "Ready." : "Not selected.", Foreground = (Brush)Application.Current.Resources["Muted"] });
        else foreach (var turn in thread.Turns) list.Children.Add(Bubble(turn));
        var scroll = new ScrollViewer { Content = list, VerticalScrollBarVisibility = ScrollBarVisibility.Auto };
        scroll.Loaded += (_, _) => scroll.ScrollToEnd();
        dock.Children.Add(scroll);
        return new Border
        {
            Child = dock, Margin = new Thickness(4), CornerRadius = new CornerRadius(10),
            BorderBrush = (Brush)Application.Current.Resources["Line"], BorderThickness = new Thickness(1),
            Opacity = selected.Contains(agent.Id) ? 1 : 0.6,
        };
    }

    private static UIElement Bubble(Turn turn)
    {
        var user = turn.Role == TurnRole.User;
        var text = turn.Status switch
        {
            TurnStatus.Pending => "Waiting for a reply…",
            TurnStatus.Failed => "Not sent: " + (turn.Error ?? "unknown error") + " Review before sending again; msgblast does not retry automatically.",
            _ => turn.Text,
        };
        return new Border
        {
            Background = user ? (Brush)Application.Current.Resources["Accent"] : turn.Status == TurnStatus.Failed ? new SolidColorBrush(Color.FromRgb(0xFD, 0xEC, 0xEC)) : (Brush)Application.Current.Resources["Pane"],
            CornerRadius = new CornerRadius(12), Padding = new Thickness(10, 7, 10, 7), Margin = new Thickness(user ? 40 : 0, 4, user ? 0 : 40, 4),
            HorizontalAlignment = user ? HorizontalAlignment.Right : HorizontalAlignment.Left,
            Child = new TextBox
            {
                Text = text, IsReadOnly = true, BorderThickness = new Thickness(0), Background = Brushes.Transparent, TextWrapping = TextWrapping.Wrap,
                Foreground = user ? Brushes.White : turn.Status == TurnStatus.Pending ? (Brush)Application.Current.Resources["Muted"] : Brushes.Black,
                FontStyle = turn.Status == TurnStatus.Pending ? FontStyles.Italic : FontStyles.Normal,
            },
        };
    }

    public async Task SendAsync()
    {
        if (sending) return;
        var message = composer.Text.Trim();
        var recipients = agents.Where(a => selected.Contains(a.Id)).ToList();
        if (message.Length == 0) return;
        if (recipients.Count == 0) { status.Text = "Choose at least one agent."; return; }
        sending = true; send.IsEnabled = false;
        current ??= controller.NewComparison(message);
        RenderSidebar();
        composer.Clear();
        status.Text = $"Sending to {string.Join(", ", recipients.Select(r => r.Name))}…";
        try
        {
            var results = await controller.BlastAsync(current, recipients, message);
            var failed = results.Count(r => r.Value.Status == TurnStatus.Failed);
            status.Text = failed == 0 ? $"Replies received from {results.Count} agent(s)." : $"{failed} agent(s) did not reply. Your message is shown in each pane.";
            if (failed == results.Count) composer.Text = message;
        }
        finally { sending = false; send.IsEnabled = true; RenderPanes(); }
    }
}
