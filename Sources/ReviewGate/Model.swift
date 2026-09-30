import Foundation

/// Who produced the change. The gate is stricter for agents because an agent
/// makes assumptions silently; a human usually mentions them in the PR thread.
public enum Author: String, Codable, Sendable { case human, agent }

/// The parts of an iOS change that are expensive for a person to discover on
/// their own. Each one maps to exactly one kind of evidence.
public enum Surface: String, Codable, Sendable, CaseIterable, Comparable {
    case ui, concurrency, entitlements, hotPath, assumptions

    public static func < (l: Surface, r: Surface) -> Bool { l.order < r.order }
    private var order: Int { Surface.allCases.firstIndex(of: self) ?? Int.max }
}

public struct ChangedFile: Codable, Sendable, Hashable {
    public let path: String
    public let addedLines: [String]
    public init(path: String, addedLines: [String] = []) {
        self.path = path
        self.addedLines = addedLines
    }
    /// File name without directory or extension: "FeedView" for "Sources/Feed/FeedView.swift".
    public var stem: String {
        let name = path.split(separator: "/").last.map(String.init) ?? path
        if let dot = name.lastIndex(of: "."), dot != name.startIndex {
            return String(name[..<dot])
        }
        return name
    }
}

/// One piece of evidence attached to a PR. Every case says what it covers,
/// because evidence that covers nothing in the diff is the failure to catch.
public enum Evidence: Codable, Sendable, Hashable {
    case screenshot(covers: [String])
    case snapshotDiff(covers: [String], changedSnapshots: Int)
    case isolationNote(text: String)
    case entitlementNote(text: String)
    case benchmarkDelta(metric: String, baseline: Double?, candidate: Double?, runs: Int)
    case assumptions([String])
}

public struct PullRequestPacket: Codable, Sendable {
    public let id: String
    public let title: String
    public let author: Author
    public let files: [ChangedFile]
    public let evidence: [Evidence]
    public init(id: String, title: String, author: Author,
                files: [ChangedFile], evidence: [Evidence]) {
        self.id = id
        self.title = title
        self.author = author
        self.files = files
        self.evidence = evidence
    }
}
