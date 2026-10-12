import SwiftUI
import AppKit
import msgblastCore

struct GrokBotConnectionsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var web: WebAgents
    let busy: Bool
    @State private var expanded: Set<WebAgentID> = [.grokbot]
    @State private var configuration: AgentConfigurationAction?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button("Add Grok Bot…") { configuration = .addBot }.disabled(busy)
            ForEach(web.sessions.filter { $0.provider == .grokbot }, id: \.id) { session in
                DisclosureGroup(isExpanded: Binding(get: { expanded.contains(session.id) }, set: { value in
                    if value { expanded.insert(session.id) } else { expanded.remove(session.id) }
                })) {
                    GrokBotSettingsView(session: session, busy: busy).padding(.top, 12)
                } label: {
                    HStack {
                        Text(session.name).fontWeight(.medium)
                        Spacer()
                        Button("Rename") { configuration = .rename(session.id) }.buttonStyle(.borderless).disabled(busy)
                    }
                }
            }
            if let error = web.configurationError { Text(error).font(.caption).foregroundStyle(.orange) }
        }
        .sheet(item: $configuration) { action in
            AgentConfigurationSheet(action: action, web: web, busy: busy) { session in
                var grid = model.agentGridLayout
                grid.add(session.id.gridID)
                guard model.setAgentGrid(grid) else { throw AppFailure.blocked(model.error ?? "Could not add the bot to your grid.") }
                expanded.insert(session.id)
            }
        }
    }
}

struct GrokBotSettingsView: View {
    @ObservedObject var session: WebAgentSession
    let busy: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle(isOn: Binding(get: { session.isEnabled }, set: { session.setEnabled($0); if $0 { session.connect() } })) {
                HStack(spacing: 12) {
                    AgentAvatar(agent: AgentArtwork.agent(for: session), name: session.name, size: 32)
                        .accessibilityHidden(true)
                    Text("Enable \(session.name)")
                }
            }
            .toggleStyle(.switch)
            .disabled(busy || session.configuringGrokBot)

            GrokBotSetupView(session: session, busy: busy)
        }
    }
}

struct GrokBotSetupView: View {
    @ObservedObject var session: WebAgentSession
    let busy: Bool
    var selectAfterConnecting = true
    @State private var webhookURL = ""
    @State private var webhookKey = ""
    @State private var saved = false

    private func openGrokBot() {
        let workspace = NSWorkspace.shared
        if let app = workspace.urlForApplication(withBundleIdentifier: "com.anysphere.sand"), workspace.open(app) { return }
        workspace.open(WebProvider.grokbot.homeURL)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if session.fixture {
                Label("Demo setup · connection and replies are simulated", systemImage: "testtube.2")
                    .font(.caption).foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("1. Create your msgblast routine").font(.headline)
                    Spacer()
                    if !session.fixture {
                        Button("Open Grok Bot", action: openGrokBot)
                            .buttonStyle(.plain).foregroundStyle(.blue)
                    }
                }
                Text("Copy this prompt and paste it into your Grok Bot.")
                    .font(.caption).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 12) {
                    Text(GrokBotService.routineInstructions)
                        .font(.system(size: 12, design: .monospaced))
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("Grok Bot setup prompt")
                    Button("Copy prompt") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(GrokBotService.routineInstructions, forType: .string)
                    }
                }
                .padding(12)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.2)))
                Text("In Grok Bot, click “msgblast” next to “Created routine” to open the routine panel.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("2. Connect your Bot").font(.headline)
                Text("Copy “POST to” into Webhook URL and “key” into Webhook key.")
                    .font(.caption).foregroundStyle(.secondary)
                if session.fixture {
                    Text("This demo does not create a routine, use a webhook, or start a reply tunnel.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("Simulate Grok Bot connection") {
                        Task {
                            saved = await session.configureGrokBot(
                                webhookURL: "https://example.invalid/msgblast-demo",
                                webhookKey: String(repeating: "demo", count: 8), selectAfterConnecting: selectAfterConnecting)
                        }
                    }.disabled(busy || session.configuringGrokBot)
                } else {
                    TextField("Webhook URL", text: $webhookURL).accessibilityLabel("Grok Bot webhook URL")
                        .textFieldStyle(.roundedBorder).disabled(session.configuringGrokBot)
                    SecureField("Webhook key", text: $webhookKey).accessibilityLabel("Grok Bot webhook key")
                        .textFieldStyle(.roundedBorder).disabled(session.configuringGrokBot)
                    Text("Paste only the key. msgblast adds the Authorization header automatically.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button(session.grokBotConnectionActivity?.title ?? "Connect \(session.name)") {
                        Task {
                            saved = await session.configureGrokBot(webhookURL: webhookURL, webhookKey: webhookKey, selectAfterConnecting: selectAfterConnecting)
                            if saved { webhookKey = "" }
                        }
                    }.disabled(busy || session.configuringGrokBot || session.hasPendingGrokBotRequests || webhookKey.isEmpty)
                }

                if saved {
                    Label(session.fixture ? "Demo connection ready" : "Ready to send", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else if !session.fixture, session.grokBotIsConfigured {
                    Text(session.grokBotRemembersConnection ? "Connection saved on this Mac" : "Connected for this session")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let activity = session.grokBotConnectionActivity {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text(activity.detail).font(.caption).foregroundStyle(.secondary)
                    }
                }
                if !session.fixture, session.grokBotNeedsKeychainRetry {
                    Button("Retry saved connection") {
                        Task {
                            if await session.retryGrokBotSavedConnection() {
                                webhookURL = session.grokBotWebhookURL; webhookKey = ""; saved = false
                            }
                        }
                    }.disabled(busy || session.configuringGrokBot)
                }
                if !session.fixture, session.grokBotIsConfigured && !session.grokBotRemembersConnection {
                    Text("The connection could not be saved securely. It lasts until you quit.")
                        .font(.caption).foregroundStyle(.orange)
                }
                if !session.fixture {
                    Text("Replies return through a temporary connection. Keep msgblast open and this Mac awake while waiting.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if session.hasPendingGrokBotRequests {
                    Text("Wait for pending replies before changing this connection.").font(.caption).foregroundStyle(.secondary)
                }
                if let error = session.error { Text(error).font(.caption).foregroundStyle(.orange).textSelection(.enabled) }
            }
        }
        .onAppear { webhookURL = session.grokBotWebhookURL }
        .onChange(of: session.grokBotWebhookURL) { previous, current in
            if !current.isEmpty, webhookURL.isEmpty || webhookURL == previous { webhookURL = current }
        }
    }
}
