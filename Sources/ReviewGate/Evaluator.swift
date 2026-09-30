import Foundation

public enum FindingStatus: String, Codable, Sendable {
    /// Required and present, and it says something about this diff.
    case satisfied
    /// Required and absent.
    case missing
    /// Present, but it cannot support the claim it is standing in for.
    case vacuous
}

public struct Finding: Codable, Sendable, Hashable {
    public let surface: Surface
    public let status: FindingStatus
    public let reason: String
}

public enum Verdict: String, Codable, Sendable { case reviewable, notReviewable }

public struct ReadinessReport: Codable, Sendable {
    public let packetID: String
    public let verdict: Verdict
    public let findings: [Finding]

    public var blocking: [Finding] { findings.filter { $0.status != .satisfied } }
    public var missingCount: Int { findings.filter { $0.status == .missing }.count }
    public var vacuousCount: Int { findings.filter { $0.status == .vacuous }.count }
}

public enum ReviewGate {

    public static func evaluate(_ packet: PullRequestPacket,
                                policy: ReviewPolicy = ReviewPolicy()) -> ReadinessReport {
        let triggers = policy.classifier.triggers(in: packet.files)
        var findings: [Finding] = []

        for surface in Surface.allCases where surface != .assumptions {
            guard let files = triggers[surface], !files.isEmpty else { continue }
            findings.append(check(surface, files: files, packet: packet, policy: policy))
        }
        if packet.author == .agent, packet.files.count >= policy.assumptionsRequiredFromFiles {
            findings.append(checkAssumptions(packet: packet, policy: policy))
        }
        let blocked = findings.contains { $0.status != .satisfied }
        return ReadinessReport(packetID: packet.id,
                               verdict: blocked ? .notReviewable : .reviewable,
                               findings: findings.sorted { $0.surface < $1.surface })
    }

    /// Minutes of reviewer discovery a packet would have cost if it had gone to a
    /// person with these findings unresolved.
    public static func discoveryMinutes(of report: ReadinessReport, policy: ReviewPolicy = ReviewPolicy()) -> Int {
        report.blocking.reduce(0) { $0 + (policy.discoveryMinutes[$1.surface] ?? 0) }
    }

    // MARK: - Per-surface checks

    private static func check(_ surface: Surface, files: [ChangedFile],
                              packet: PullRequestPacket, policy: ReviewPolicy) -> Finding {
        let stems = Set(files.map(\.stem))
        let paths = Set(files.map(\.path))
        switch surface {
        case .ui:
            let visual = packet.evidence.compactMap { ev -> [String]? in
                switch ev {
                case .screenshot(let covers): return covers
                case .snapshotDiff(let covers, _): return covers
                default: return nil
                }
            }
            if visual.isEmpty {
                return Finding(surface: .ui, status: .missing,
                               reason: "UI changed in \(list(stems)) with no screenshot or snapshot diff.")
            }
            let covered = visual.contains { covers in covers.contains { stems.contains($0) || paths.contains($0) } }
            return covered
                ? Finding(surface: .ui, status: .satisfied, reason: "Visual evidence covers a changed view.")
                : Finding(surface: .ui, status: .vacuous,
                          reason: "Visual evidence covers none of the changed views (\(list(stems))).")

        case .concurrency:
            let notes = packet.evidence.compactMap { ev -> String? in
                if case .isolationNote(let t) = ev { return t } else { return nil }
            }
            if notes.isEmpty {
                return Finding(surface: .concurrency, status: .missing,
                               reason: "Isolation-relevant code in \(list(stems)) with no isolation note.")
            }
            let named = notes.contains { note in
                note.count >= policy.minNoteLength && stems.contains(where: note.contains)
            }
            return named
                ? Finding(surface: .concurrency, status: .satisfied, reason: "Isolation note names a changed type.")
                : Finding(surface: .concurrency, status: .vacuous,
                          reason: "Isolation note is too short or names none of \(list(stems)).")

        case .entitlements:
            let notes = packet.evidence.compactMap { ev -> String? in
                if case .entitlementNote(let t) = ev { return t } else { return nil }
            }
            if notes.isEmpty {
                return Finding(surface: .entitlements, status: .missing,
                               reason: "\(list(stems)) changed with no entitlement or privacy note.")
            }
            let named = notes.contains { $0.count >= policy.minNoteLength && stems.contains(where: $0.contains) }
            return named
                ? Finding(surface: .entitlements, status: .satisfied, reason: "Note names the changed file.")
                : Finding(surface: .entitlements, status: .vacuous,
                          reason: "Entitlement note is too short or names none of \(list(stems)).")

        case .hotPath:
            let deltas = packet.evidence.compactMap { ev -> (Double?, Double?, Int)? in
                if case .benchmarkDelta(_, let b, let c, let runs) = ev { return (b, c, runs) } else { return nil }
            }
            if deltas.isEmpty {
                return Finding(surface: .hotPath, status: .missing,
                               reason: "Hot-path change in \(list(stems)) with no benchmark delta.")
            }
            let solid = deltas.contains { d in
                guard let b = d.0, let c = d.1, b > 0, c >= 0 else { return false }
                return d.2 >= policy.minBenchmarkRuns
            }
            return solid
                ? Finding(surface: .hotPath, status: .satisfied, reason: "Benchmark has a baseline, a candidate and enough runs.")
                : Finding(surface: .hotPath, status: .vacuous,
                          reason: "Benchmark lacks a baseline/candidate or has fewer than \(policy.minBenchmarkRuns) runs.")

        case .assumptions:
            return checkAssumptions(packet: packet, policy: policy)
        }
    }

    private static func checkAssumptions(packet: PullRequestPacket, policy: ReviewPolicy) -> Finding {
        let lists = packet.evidence.compactMap { ev -> [String]? in
            if case .assumptions(let a) = ev { return a } else { return nil }
        }
        if lists.isEmpty {
            return Finding(surface: .assumptions, status: .missing,
                           reason: "Agent PR of \(packet.files.count) files lists no assumptions.")
        }
        let real = lists.flatMap { $0 }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty && !policy.emptyAssumptionPhrases.contains($0) }
        return real.isEmpty
            ? Finding(surface: .assumptions, status: .vacuous, reason: "Assumptions list says only \"none\".")
            : Finding(surface: .assumptions, status: .satisfied, reason: "\(real.count) assumption(s) listed.")
    }

    private static func list(_ stems: Set<String>) -> String {
        stems.sorted().joined(separator: ", ")
    }
}
