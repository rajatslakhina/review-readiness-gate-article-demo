import XCTest
@testable import ReviewGate

final class ReviewGateTests: XCTestCase {

    private func report(_ id: String) throws -> ReadinessReport {
        let packet = try XCTUnwrap(Fixtures.all.first { $0.id == id })
        return ReviewGate.evaluate(packet)
    }

    private func status(_ r: ReadinessReport, _ s: Surface) -> FindingStatus? {
        r.findings.first { $0.surface == s }?.status
    }

    func testDocsOnlyChangeIsReviewableWithNoEvidence() throws {
        let r = try report("PR-101")
        XCTAssertEqual(r.verdict, .reviewable)
        XCTAssertTrue(r.findings.isEmpty)
    }

    func testWrongScreenshotIsVacuousNotMissing() throws {
        let r = try report("PR-103")
        XCTAssertEqual(status(r, .ui), .vacuous)
    }

    func testShortIsolationNoteAndNoneAssumptionsAreVacuous() throws {
        let r = try report("PR-104")
        XCTAssertEqual(status(r, .concurrency), .vacuous)
        XCTAssertEqual(status(r, .assumptions), .vacuous)
        XCTAssertEqual(r.verdict, .notReviewable)
    }

    func testEntitlementWithoutNoteIsMissing() throws {
        XCTAssertEqual(status(try report("PR-105"), .entitlements), .missing)
        XCTAssertEqual(status(try report("PR-107"), .entitlements), .satisfied)
    }

    func testBenchmarkNeedsBaselineAndRuns() throws {
        XCTAssertEqual(status(try report("PR-106"), .hotPath), .vacuous)   // no baseline, 1 run
        XCTAssertEqual(status(try report("PR-112"), .hotPath), .vacuous)   // 3 runs < 5
    }

    func testFullyEvidencedAgentPRsPass() throws {
        XCTAssertEqual(try report("PR-102").verdict, .reviewable)
        XCTAssertEqual(try report("PR-110").verdict, .reviewable)
    }

    func testZeroChangedSnapshotsStillCountsAsCoveringTheView() throws {
        XCTAssertEqual(try report("PR-108").verdict, .reviewable)
    }

    func testHumanSmallPRNeedsNoAssumptionsButAgentLargePRDoes() throws {
        XCTAssertNil(status(try report("PR-105"), .assumptions))
        XCTAssertEqual(status(try report("PR-109"), .assumptions), .missing)
    }

    func testAgentBelowFileThresholdIsNotAskedForAssumptions() {
        let p = PullRequestPacket(id: "X", title: "t", author: .agent,
                                  files: [ChangedFile(path: "a.swift"), ChangedFile(path: "b.swift")], evidence: [])
        XCTAssertNil(ReviewGate.evaluate(p).findings.first { $0.surface == .assumptions })
    }

    func testPolicyClampsNonsenseThresholds() {
        let p = ReviewPolicy(minBenchmarkRuns: -4, minNoteLength: -1, assumptionsRequiredFromFiles: 0)
        XCTAssertEqual(p.minBenchmarkRuns, 1)
        XCTAssertEqual(p.minNoteLength, 0)
        XCTAssertEqual(p.assumptionsRequiredFromFiles, 1)
    }

    func testNegativeBenchmarkCandidateIsVacuous() {
        let p = PullRequestPacket(id: "X", title: "t", author: .human,
                                  files: [ChangedFile(path: "Sources/Render/A.swift")],
                                  evidence: [.benchmarkDelta(metric: "m", baseline: 5, candidate: -1, runs: 20)])
        XCTAssertEqual(ReviewGate.evaluate(p).findings.first?.status, .vacuous)
    }

    func testFileStemHandlesDotfilesAndNoExtension() {
        XCTAssertEqual(ChangedFile(path: "a/b/FeedView.swift").stem, "FeedView")
        XCTAssertEqual(ChangedFile(path: "Makefile").stem, "Makefile")
        XCTAssertEqual(ChangedFile(path: "dir/.gitignore").stem, ".gitignore")
    }

    func testBatchSummaryNumbers() {
        let s = BatchSummary(packets: Fixtures.all)
        XCTAssertEqual(s.total, 12)
        XCTAssertEqual(s.reviewable, 6)
        XCTAssertEqual(s.reviewableIfPresenceOnly, 10)
        XCTAssertEqual(s.waveThroughs, 4)
        XCTAssertEqual(s.missingFindings, 2)
        XCTAssertEqual(s.vacuousFindings, 6)
        XCTAssertEqual(s.discoveryMinutesBlocked, 104)
        XCTAssertEqual(s.reports.count, 12)
        XCTAssertEqual(s.reviewableIfPresenceOnly - s.reviewable, s.waveThroughs)
        for r in s.reports { print("PR \(r.packetID) \(r.verdict.rawValue) " + r.findings.map { "\($0.surface.rawValue):\($0.status.rawValue)" }.joined(separator: ",")) }
        print("SUMMARY total=\(s.total) reviewable=\(s.reviewable) presenceOnly=\(s.reviewableIfPresenceOnly) waveThroughs=\(s.waveThroughs) missing=\(s.missingFindings) vacuous=\(s.vacuousFindings) minutes=\(s.discoveryMinutesBlocked)")
    }

    func testPacketRoundTripsThroughJSON() throws {
        let data = try JSONEncoder().encode(Fixtures.all)
        let back = try JSONDecoder().decode([PullRequestPacket].self, from: data)
        XCTAssertEqual(back.count, Fixtures.all.count)
        XCTAssertEqual(ReviewGate.evaluate(back[2]).verdict, ReviewGate.evaluate(Fixtures.all[2]).verdict)
    }
}
