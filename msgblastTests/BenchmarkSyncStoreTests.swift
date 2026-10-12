import XCTest
@testable import msgblastCore

@MainActor final class BenchmarkSyncStoreTests: XCTestCase {
    private func sample(_ directory: URL) throws -> (PerformanceRecorder, [PerformanceEvent]) {
        let recorder = try PerformanceRecorder(directory: directory, fixture: true)
        recorder.enabled = true
        let agent = PerformanceAgent(id: "agent", name: "Synthetic", connection: .cli)
        _ = try recorder.beginTurn(comparisonID: "comparison", agent: agent, text: "prompt", scope: .shared)
        return (recorder, recorder.events)
    }
    func testRelaunchKeepsExactRetryAndExplicitSelection() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let (recorder, events) = try sample(root)
        let store = try BenchmarkSyncStore(directory: root)
        let first = try store.prepare(events: events, comparisonID: "comparison", owner: "account-a", context: "fresh")
        XCTAssertTrue(store.paused)
        let restored = try BenchmarkSyncStore(directory: root)
        XCTAssertEqual(first, restored.lineages.first)
        try recorder.reply(comparisonID: "comparison", agent: .init(id: "agent", name: "Synthetic", connection: .cli), messageID: "reply", text: "new reply", turnID: nil)
        XCTAssertEqual(restored.lineages.first?.selectedSequenceEnd, events.count)
        let second = try restored.prepare(events: recorder.events, comparisonID: "comparison", owner: "account-a", context: "fresh")
        XCTAssertEqual(second.chunks.first, first.chunks.first)
        XCTAssertGreaterThan(second.selectedSequenceEnd, first.selectedSequenceEnd)
        XCTAssertThrowsError(try restored.prepare(events: recorder.events, comparisonID: "comparison", owner: "account-b", context: "fresh"))
    }
    func testContinuationKeepsFinalizedHeadAndRetryRequest() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let (recorder, events) = try sample(root)
        let store = try BenchmarkSyncStore(directory: root)
        var first = try store.prepare(events: events, comparisonID: "comparison", owner: "a", context: "unknown")
        first.snapshotID = "snapshot-1"; first.finalizedHash = first.chunks.last!.hash; first.finalizedSequenceEnd = first.selectedSequenceEnd
        first.chunks[0].acknowledged = true; try store.update(first)
        try recorder.reply(comparisonID: "comparison", agent: .init(id: "agent", name: "Synthetic", connection: .cli), messageID: "reply", text: "new", turnID: nil)
        let next = try store.prepare(events: recorder.events, comparisonID: "comparison", owner: "a", context: "unknown")
        XCTAssertEqual(next.revision, 2); XCTAssertNil(next.snapshotID)
        XCTAssertEqual(next.parentHash, first.finalizedHash); XCTAssertEqual(next.parentSequenceEnd, first.finalizedSequenceEnd)
        let retry = try BenchmarkSyncStore(directory: root).prepare(events: recorder.events, comparisonID: "comparison", owner: "a", context: "unknown")
        XCTAssertEqual(retry, next)
    }
    func testChangedSourceNeverReplacesSavedBytes() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let (_, events) = try sample(root)
        let store = try BenchmarkSyncStore(directory: root)
        let first = try store.prepare(events: events, comparisonID: "comparison", owner: "a", context: "fresh")
        var changed = events; changed[0].reason = "tampered"
        XCTAssertThrowsError(try store.prepare(events: changed, comparisonID: "comparison", owner: "a", context: "fresh"))
        XCTAssertEqual(store.lineages.first, first)
        try store.removeAccount("a"); XCTAssertTrue(store.lineages.isEmpty); XCTAssertTrue(store.paused)
    }
    func testFutureConsentIsOwnerBoundAndExcludesExistingPrefixesAcrossRelaunch() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let (recorder, old) = try sample(root)
        let store = try BenchmarkSyncStore(directory: root)
        XCTAssertTrue(store.futureComparisons(events: old, owner: "a").isEmpty)
        try store.setFutureSync(enabled: true, owner: "a", events: old)
        _ = try recorder.beginTurn(comparisonID: "future", agent: .init(id: "agent", name: "Synthetic", connection: .cli), text: "Future", scope: .shared)
        let restored = try BenchmarkSyncStore(directory: root)
        XCTAssertEqual(restored.futureComparisons(events: recorder.events, owner: "a"), ["future"])
        XCTAssertTrue(restored.futureComparisons(events: recorder.events, owner: "b").isEmpty)
        try restored.pause(true)
        XCTAssertTrue(restored.futureComparisons(events: recorder.events, owner: "a").isEmpty)
        try restored.pause(false)
        XCTAssertEqual(restored.futureComparisons(events: recorder.events, owner: "a"), ["future"])
        _ = try restored.prepare(events: recorder.events, comparisonID: "comparison", owner: "a", context: "unknown")
        XCTAssertEqual(restored.futureComparisons(events: recorder.events, owner: "a"), ["comparison", "future"])
        try restored.setFutureSync(enabled: false, owner: "a", events: recorder.events)
        try restored.pause(false)
        XCTAssertTrue(restored.futureComparisons(events: recorder.events, owner: "a").isEmpty)
        try restored.setFutureSync(enabled: true, owner: "b", events: recorder.events)
        XCTAssertTrue(restored.futureComparisons(events: recorder.events, owner: "a").isEmpty)
        XCTAssertTrue(restored.futureComparisons(events: recorder.events, owner: "b").isEmpty)
    }

    func testCompetingJournalAndDeletedComparisonNeverResurrect() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let (_, events) = try sample(root)
        let first = try BenchmarkSyncStore(directory: root), stale = try BenchmarkSyncStore(directory: root)
        _ = try first.prepare(events: events, comparisonID: "comparison", owner: "a", context: "unknown")
        XCTAssertThrowsError(try stale.pause(false))
        XCTAssertEqual(try BenchmarkSyncStore(directory: root).lineages.count, 1)
        try first.setFutureSync(enabled: true, owner: "a", events: [])
        try first.remove(comparisonID: "comparison", owner: "a")
        XCTAssertTrue(first.futureComparisons(events: events, owner: "a").isEmpty)
        XCTAssertThrowsError(try first.prepare(events: events, comparisonID: "comparison", owner: "a", context: "unknown"))
        XCTAssertTrue(try BenchmarkSyncStore(directory: root).lineages.isEmpty)
    }

}
