import SwiftUI
import msgblastCore
import UniformTypeIdentifiers

struct BenchmarkSettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var controller: BenchmarkController
    var initialComparisonID: String? = nil
    @State private var selected = ""
    @State private var context = "unknown"
    @State private var uploadConsent = false
    @State private var publication: ComparisonPublication?
    @State private var includePrivate = false
    @State private var includeUnknown = false
    @State private var includeRevisions = false
    @State private var includeFeedback = true
    @State private var publishConsent = false
    @State private var contributionConsent = false
    @State private var evidenceConsent = false
    @State private var contributionRevision = 1
    @State private var confirmDeleteAccount = false
    @State private var previewError: String?
    @State private var selectArtifact = false
    private var comparisons: [String] { Array(Set(model.performance.events.map(\.comparisonID))).sorted() }
    private var owner: String? { controller.account.account?.accountID }
    private var selectedLineage: BenchmarkSyncLineage? { controller.lineages.first { $0.comparisonID == selected && $0.owner == owner } }
    var body: some View {
        Form {
            accountSection
            selectionSection
            publicationSection
            if owner != nil { syncSection; contributionSection; recordsSection }
            Section("Status") {
                Text(controller.status).textSelection(.enabled)
                if let error = controller.error ?? controller.account.errorMessage ?? previewError { Text(error).foregroundStyle(.red).textSelection(.enabled) }
            }
        }.formStyle(.grouped)
        .task { await controller.restore() }
        .onAppear {
            if let initialComparisonID, selected.isEmpty { selected = initialComparisonID }
        }
        .onChange(of: selected) { _, _ in clearPreview() }
        .onChange(of: owner) { _, _ in uploadConsent = false; contributionConsent = false; clearPreview() }
        .onChange(of: includePrivate) { _, _ in clearPreview() }
        .onChange(of: includeUnknown) { _, _ in clearPreview() }
        .onChange(of: includeRevisions) { _, _ in clearPreview() }
        .onChange(of: includeFeedback) { _, _ in clearPreview() }
        .fileImporter(isPresented: $selectArtifact, allowedContentTypes: [.plainText, .png, .jpeg]) { result in
            do {
                let url = try result.get(); let granted = url.startAccessingSecurityScopedResource(); defer { if granted { url.stopAccessingSecurityScopedResource() } }
                let type = try url.resourceValues(forKeys: [.contentTypeKey]).contentType
                let mime = type == .png ? "image/png" : type == .jpeg ? "image/jpeg" : "text/plain"
                let handle = try FileHandle(forReadingFrom: url); defer { try? handle.close() }
                let bytes = try handle.read(upToCount: 262145) ?? Data()
                let artifact = try ComparisonPublication.Artifact(id: UUID().uuidString, name: "Selected artifact", type: mime, bytes: bytes)
                publication?.artifacts.append(artifact); publishConsent = false
            } catch { previewError = error.localizedDescription }
        }
        .confirmationDialog("Delete your benchmark account and cloud records?", isPresented: $confirmDeleteAccount) {
            Button("Delete benchmark account", role: .destructive) { Task { await controller.deleteAccount() } }
        } message: { Text("This revokes links and withdraws contributions immediately. Cloud content and managed identity cleanup continue asynchronously. Local comparisons and My Stats remain on this Mac.") }
    }
    private var accountSection: some View {
        Section("Benchmark account") {
            if controller.account.configuration?.demoFixture == true {
                Text("Synthetic Demo: OAuth browser and credential storage are simulated. Cloud requests use a loopback Worker.").foregroundStyle(.secondary)
            }
            if let identity = controller.account.account {
                Text("Connected account: \(identity.accountID.prefix(12))").textSelection(.enabled)
                Button("Sign out") { controller.signOut() }
            } else {
                Text("My Stats stays on this Mac. A benchmark account is optional.")
                Button("Sign in with browser") { Task { await controller.signIn() } }
                    .disabled(!controller.account.isConfigured || controller.account.isWorking)
                if !controller.account.isConfigured { Text("Managed sign-in is not configured in this build. Deployment requires an OIDC native client, API audience, callback and service URL.").foregroundStyle(.secondary) }
            }
            Text("Private sync, direct-link publication, and benchmark contribution are separate choices. Signing in does not upload recordings.").foregroundStyle(.secondary)
        }
    }
    private var selectionSection: some View {
        Section("Select recorded comparison") {
            Picker("Comparison", selection: $selected) {
                Text("Choose a comparison").tag("")
                ForEach(comparisons, id: \.self) { id in
                    Text(model.performance.events.first(where: { $0.comparisonID == id && $0.kind == .turnStarted })?.text.map { String($0.prefix(60)) } ?? String(id.prefix(12))).tag(id)
                }
            }
            Picker("Provider context", selection: $context) {
                Text("Unknown").tag("unknown"); Text("Fresh conversation").tag("fresh")
                Text("Earlier provider history").tag("prior"); Text("Earlier history omitted").tag("omitted")
            }
            Text("Use the context that actually applies. Earlier provider history was not recorded and cannot be reconstructed.").foregroundStyle(.secondary)
        }
    }
    private var syncSection: some View {
        Section("Private sync") {
            Text(controller.paused ? "Paused" : "Enabled for explicitly selected uploads")
            Toggle("Privately sync future recordings for this account", isOn: Binding(get: { controller.futureSync }, set: { controller.setFutureSync($0) })).disabled(controller.working)
            Text("Off by default. New comparisons recorded after enabling sync queue automatically. Existing comparisons require explicit selection. Later private revisions do not update shared pages or contribution selections.").foregroundStyle(.secondary)

            Toggle("Upload this comparison's complete captured event prefix privately", isOn: $uploadConsent)
            Text("Includes captured private prompts, reply revisions, identifiers, and feedback. Original local bytes are retained. With future sync off, later events require another selection.").foregroundStyle(.secondary)
            HStack {
                Button("Upload selected snapshot") {
                    Task { await controller.upload(events: model.performance.events, comparisonID: selected, context: context); uploadConsent = false }
                }.disabled(selected.isEmpty || !uploadConsent || controller.working)
                Button("Pause sync") { controller.pause() }
                Button("Resume saved selections") { Task { await controller.resumeSaved() } }.disabled(controller.working)
            }
            if let lineage = selectedLineage {
                Text("Revision \(lineage.revision) · selected through event \(lineage.selectedSequenceEnd) · \(lineage.finalized ? "finalized" : "saved retry")")
                Button("Delete selected cloud record", role: .destructive) { Task { await controller.delete(lineage) } }.disabled(controller.working)
            }
        }
    }
    private var publicationSection: some View {
        Section("Review and share") {
            Text("Sharing works independently of private sync or contribution. Default preview excludes private prompts, unknown scope, earlier history, attachments, and earlier streaming revisions.").foregroundStyle(.secondary)
            Toggle("Include captured private turns", isOn: $includePrivate)
            Toggle("Include captured unknown-scope turns with uncertainty labels", isOn: $includeUnknown)
            Toggle("Include observed earlier reply revisions", isOn: $includeRevisions)
            Toggle("Include my per-message feedback", isOn: $includeFeedback)
            Button("Prepare redacted preview") { preparePreview() }.disabled(selected.isEmpty || controller.working)
            if publication != nil {
                publicationEditor
                Button("Select a text, PNG, or JPEG artifact for this preview") { selectArtifact = true }
                Text("Artifacts are uploaded exactly as selected. Inspect images for private content; filenames are replaced with a generic public label.").foregroundStyle(.secondary)
                Toggle("I reviewed the exact preview and approve publishing these bytes", isOn: $publishConsent)
                Button("Publish reviewed comparison") {
                    guard let approved = publication else { return }
                    Task { await controller.publish(approved); publishConsent = false }
                }.disabled(!publishConsent || controller.working || owner == nil)
            }
            ForEach(controller.publicationLinks, id: \.id) { link in
                HStack {
                    Link("Open shared comparison", destination: link.url)
                    Button("Copy link") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(link.url.absoluteString, forType: .string) }
                    Button("Revoke link", role: .destructive) { Task { await controller.revoke(link.id) } }
                }
            }
        }
    }
    private var publicationEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Public title", text: Binding(get: { publication?.title ?? "" }, set: { publication?.title = $0; publishConsent = false }))
            if let p = publication {
                ForEach(p.participants.indices, id: \.self) { i in
                    TextField("Agent label", text: Binding(get: { publication?.participants[i].label ?? "" }, set: { publication?.participants[i].label = $0; publishConsent = false }))
                }
                ForEach(p.turns.indices, id: \.self) { i in
                    Text("\(turnLabel(p.turns[i].kind)) · \(p.turns[i].scope.rawValue)").font(.headline)
                    TextEditor(text: Binding(get: { publication?.turns[i].prompt ?? "" }, set: { publication?.turns[i].prompt = $0; publishConsent = false })).frame(minHeight: 70)
                    ForEach(p.turns[i].replies.indices, id: \.self) { j in
                        Text("\(p.participants.first(where: { $0.id == p.turns[i].replies[j].agentID })?.label ?? "Agent"): \(outcomeLabel(p.turns[i].replies[j].outcome))")
                        ForEach(p.turns[i].replies[j].messages.indices, id: \.self) { k in
                            TextEditor(text: Binding(get: { publication?.turns[i].replies[j].messages[k].text ?? "" }, set: { publication?.turns[i].replies[j].messages[k].text = $0; publishConsent = false })).frame(minHeight: 100)
                            Text(p.turns[i].replies[j].messages[k].timingLabel).font(.caption)
                            if let revisions = p.turns[i].replies[j].messages[k].revisions {
                                ForEach(revisions.indices, id: \.self) { r in
                                    Text("Earlier observed revision \(r + 1)").font(.caption)
                                    TextEditor(text: Binding(get: { publication?.turns[i].replies[j].messages[k].revisions?[r].text ?? "" }, set: { publication?.turns[i].replies[j].messages[k].revisions?[r].text = $0; publishConsent = false })).frame(minHeight: 70)
                                }
                            }

                        }
                    }
                }
                ForEach(p.artifacts.indices, id: \.self) { i in
                    HStack {
                        TextField("Public artifact label", text: Binding(get: { publication?.artifacts[i].name ?? "" }, set: { publication?.artifacts[i].name = $0; publishConsent = false }))
                        Button("Remove artifact") { publication?.artifacts.remove(at: i); publishConsent = false }
                    }
                    if let bytes = Data(base64Encoded: p.artifacts[i].base64) {
                        if p.artifacts[i].type == "text/plain" { Text(String(decoding: bytes, as: UTF8.self)).textSelection(.enabled) }
                        else if let image = NSImage(data: bytes) { Image(nsImage: image).resizable().scaledToFit().frame(maxHeight: 220) }
                    }
                }
                ForEach(p.omissions, id: \.self) { Text($0).foregroundStyle(.secondary) }
                ForEach(p.limitations, id: \.self) { Text($0).foregroundStyle(.secondary) }
                DisclosureGroup("Exact publication JSON") {
                    Text(String(decoding: (try? p.previewBytes()) ?? Data(), as: UTF8.self)).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                    Text("SHA-256: \((try? p.previewHash()) ?? "unavailable")").font(.caption).textSelection(.enabled)
                }
            }
        }
    }
    private var contributionSection: some View {
        Section("Benchmark contribution") {
            Text("Voluntary selected samples are not representative rankings. Timing measures local observation, not token generation. Fixture recordings are ineligible. No rewards or public scores are assigned.").foregroundStyle(.secondary)
            Toggle("Upload this comparison's captured event prefix for contribution validation", isOn: $evidenceConsent)
            Text("Includes private captured evidence and identifiers. This separate selection does not enable private sync or publish a link.").foregroundStyle(.secondary)
            Button("Prepare selected contribution evidence") {
                Task { await controller.prepareContribution(events: model.performance.events, comparisonID: selected, context: context); evidenceConsent = false }
            }.disabled(selected.isEmpty || !evidenceConsent || controller.working)
            if let lineage = selectedLineage, lineage.snapshotID != nil {
                Text("Selected finalized private snapshot: revision \(lineage.revision), event \(lineage.finalizedSequenceEnd)")
                Stepper("Contribution revision \(contributionRevision)", value: $contributionRevision, in: 1...10000)
                Toggle("Contribute this finalized snapshot to benchmark statistics", isOn: $contributionConsent)
                Button("Request contribution") {
                    Task { await controller.contribute(lineage, contributionRevision: contributionRevision); contributionConsent = false }
                }.disabled(!contributionConsent || controller.working)
                Button("Withdraw this lineage's contribution", role: .destructive) { Task { await controller.withdraw(lineage) } }
            } else { Text("Upload and finalize a selected snapshot before contributing it.") }
            ForEach(controller.contributionSummaries) { item in
                VStack(alignment: .leading) {
                    Text("Contribution revision \(item.revision): \(item.status)").font(.headline)
                    Text("Snapshot \(item.snapshotID.prefix(12)) · \(item.completeness ?? "validation pending")")
                    ForEach(item.reasons, id: \.self) { Text($0).foregroundStyle(.secondary) }
                }
            }
            DisclosureGroup("Contribution history and eligibility") { Text(controller.contributionHistory).font(.system(.caption, design: .monospaced)).textSelection(.enabled) }
        }
    }
    private var recordsSection: some View {
        Section("Cloud records and deletion") {
            Button("Refresh cloud records and contribution history") { Task { await controller.refreshRecords() } }.disabled(controller.working)
            ForEach(controller.remoteRecords) { record in
                HStack { Text("Comparison \(record.local_id.prefix(12)): \(record.status)\(record.fixture == 1 ? " · fixture" : "")"); Button("Delete cloud record", role: .destructive) { Task { await controller.deleteRemoteRecord(record) } } }
            }
            ForEach(controller.remotePublications.filter { $0.revoked_at == nil }) { record in
                HStack { Text("Publication created \(record.created_at)"); Button("Revoke publication", role: .destructive) { Task { await controller.revoke(record.id) } } }
            }
            DisclosureGroup("Private cloud records") { Text(controller.cloudSessions).font(.system(.caption, design: .monospaced)).textSelection(.enabled) }
            Button("Delete benchmark account", role: .destructive) { confirmDeleteAccount = true }.disabled(controller.working)
            Button("Check account deletion status") { Task { await controller.deletionStatus() } }.disabled(controller.working)
        }
    }
    private func turnLabel(_ kind: String) -> String { kind == "initial" ? "Initial prompt" : kind == "followUp" ? "Follow-up" : "Unaligned request" }
    private func outcomeLabel(_ outcome: String) -> String {
        ["observedCompletion": "Answer completion observed", "observedReply": "Reply observed", "missing": "No reply observed", "timeout": "Timed out", "failed": "Failed", "canceled": "Canceled", "uncertain": "Outcome uncertain"][outcome] ?? "Outcome unknown"
    }
    private func clearPreview() { evidenceConsent = false; contributionConsent = false; uploadConsent = false; publication = nil; publishConsent = false; previewError = nil }
    private func preparePreview() {
        do {
            var options = ComparisonPublicationOptions(); options.includePrivate = includePrivate; options.includeUnknownScope = includeUnknown
            options.includesStreamingRevisions = includeRevisions; options.includeFeedback = includeFeedback
            publication = try ComparisonPublicationBuilder.build(events: model.performance.events, comparisonID: selected, options: options)
            publishConsent = false; previewError = nil
        } catch { previewError = error.localizedDescription }
    }
}

struct ComparisonShareButton: View {
    @ObservedObject var model: AppModel
    let comparisonID: UUID
    @State private var showingShare = false
    var body: some View {
        Button("Review and share") { showingShare = true }
            .disabled(!model.performance.events.contains { $0.comparisonID == comparisonID.uuidString })
            .help("Prepare a separate redacted publication; private sync and contribution are separate choices")
            .sheet(isPresented: $showingShare) {
                VStack {
                    BenchmarkSettingsView(model: model, controller: model.benchmarks, initialComparisonID: comparisonID.uuidString)
                    Button("Done") { showingShare = false }.padding(.bottom)
                }.frame(width: 800, height: 700)
            }
    }
}
