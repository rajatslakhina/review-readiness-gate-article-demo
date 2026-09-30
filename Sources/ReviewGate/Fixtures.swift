import Foundation

/// Twelve constructed pull requests. They are fixtures, not data from a real
/// team: each one is built to exercise exactly one branch of the policy.
public enum Fixtures {

    private static let feedVM = ChangedFile(
        path: "Sources/Feed/FeedViewModel.swift",
        addedLines: ["@MainActor final class FeedViewModel {", "  Task { await reload() }"])
    private static let feedView = ChangedFile(
        path: "Sources/Feed/FeedView.swift",
        addedLines: ["import SwiftUI", "struct FeedView: View {"])
    private static let settingsView = ChangedFile(
        path: "Sources/Settings/SettingsView.swift",
        addedLines: ["import SwiftUI", "struct SettingsView: View {"])
    private static let cache = ChangedFile(
        path: "Sources/Storage/ImageCache.swift",
        addedLines: ["actor ImageCache {", "  nonisolated func key(for url: URL) -> String { url.absoluteString }"])
    private static let entitlements = ChangedFile(path: "App/App.entitlements",
                                                  addedLines: ["<key>com.apple.developer.healthkit</key>"])
    private static let renderer = ChangedFile(path: "Sources/Render/TileRenderer.swift",
                                              addedLines: ["for tile in tiles { draw(tile) }"])
    private static let format = ChangedFile(path: "Sources/Util/DateFormat.swift",
                                            addedLines: ["static let short = ISO8601DateFormatter()"])
    private static let readme = ChangedFile(path: "docs/CHANGELOG.md", addedLines: ["- fix typo"])

    public static let all: [PullRequestPacket] = [
        PullRequestPacket(id: "PR-101", title: "Fix typo in changelog", author: .human,
                          files: [readme], evidence: []),

        PullRequestPacket(id: "PR-102", title: "Feed: reload on foreground", author: .agent,
                          files: [feedVM, feedView, format],
                          evidence: [
                            .screenshot(covers: ["FeedView"]),
                            .isolationNote(text: "FeedViewModel stays on the main actor; the reload Task inherits it and is cancelled in deinit."),
                            .benchmarkDelta(metric: "scroll hitch ms", baseline: 4.1, candidate: 3.9, runs: 10),
                            .assumptions(["Reload should not fire while a pull-to-refresh is in flight."])
                          ]),

        PullRequestPacket(id: "PR-103", title: "Settings: new toggle", author: .agent,
                          files: [settingsView, format, readme],
                          evidence: [
                            .screenshot(covers: ["FeedView"]),          // wrong screen
                            .assumptions(["Toggle default is off."])
                          ]),

        PullRequestPacket(id: "PR-104", title: "Move image cache to an actor", author: .agent,
                          files: [cache, format, readme],
                          evidence: [
                            .isolationNote(text: "Thread-safe now."),   // too short, names nothing
                            .assumptions(["none"])
                          ]),

        PullRequestPacket(id: "PR-105", title: "Enable HealthKit", author: .human,
                          files: [entitlements], evidence: []),

        PullRequestPacket(id: "PR-106", title: "Tile renderer: batch draws", author: .agent,
                          files: [renderer, format, readme],
                          evidence: [
                            .benchmarkDelta(metric: "frame ms", baseline: nil, candidate: 6.2, runs: 1),
                            .assumptions(["Tiles are already sorted by layer."])
                          ]),

        PullRequestPacket(id: "PR-107", title: "Enable HealthKit (with note)", author: .human,
                          files: [entitlements],
                          evidence: [.entitlementNote(text: "App.entitlements adds HealthKit read for step count only; the privacy manifest lists it.")]),

        PullRequestPacket(id: "PR-108", title: "Feed view refactor", author: .human,
                          files: [feedView],
                          evidence: [.snapshotDiff(covers: ["Sources/Feed/FeedView.swift"], changedSnapshots: 0),
                                     .benchmarkDelta(metric: "scroll hitch ms", baseline: 4.1, candidate: 4.1, runs: 10)]),

        PullRequestPacket(id: "PR-109", title: "Agent: rename helpers across module", author: .agent,
                          files: [format, readme, ChangedFile(path: "Sources/Util/Strings.swift", addedLines: ["let x = 1"])],
                          evidence: []),

        PullRequestPacket(id: "PR-110", title: "Feed: prefetch images", author: .agent,
                          files: [feedVM, cache, format],
                          evidence: [
                            .isolationNote(text: "ImageCache is an actor; FeedViewModel only calls its async API from the main actor."),
                            .benchmarkDelta(metric: "scroll hitch ms", baseline: 4.1, candidate: 3.2, runs: 8),
                            .assumptions(["Prefetch depth of 6 is enough on the smallest supported device."])
                          ]),

        PullRequestPacket(id: "PR-111", title: "Settings screen polish", author: .agent,
                          files: [settingsView, format, readme],
                          evidence: [
                            .snapshotDiff(covers: ["SettingsView"], changedSnapshots: 3),
                            .assumptions(["Dynamic Type sizes above AX3 are out of scope."])
                          ]),

        PullRequestPacket(id: "PR-112", title: "Renderer: cache tile paths", author: .agent,
                          files: [renderer, format, readme],
                          evidence: [
                            .benchmarkDelta(metric: "frame ms", baseline: 6.4, candidate: 5.1, runs: 3),
                            .assumptions(["n/a"])
                          ])
    ]
}
