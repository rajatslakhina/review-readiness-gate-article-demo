import Foundation

/// Runs a batch of packets through the gate and through a presence-only check,
/// so the difference between "has evidence" and "has evidence about this diff"
/// is a number and not an opinion.
public struct BatchSummary: Sendable {
    public let total: Int
    public let reviewable: Int
    /// What a checklist that only asks "is there a screenshot / note / benchmark / list?" would let through.
    public let reviewableIfPresenceOnly: Int
    public let missingFindings: Int
    public let vacuousFindings: Int
    public let discoveryMinutesBlocked: Int
    public let reports: [ReadinessReport]

    /// Packets a presence-only checklist would wave through that the gate stops.
    public var waveThroughs: Int { reviewableIfPresenceOnly - reviewable }

    public init(packets: [PullRequestPacket], policy: ReviewPolicy = ReviewPolicy()) {
        let reports = packets.map { ReviewGate.evaluate($0, policy: policy) }
        self.reports = reports
        self.total = packets.count
        self.reviewable = reports.filter { $0.verdict == .reviewable }.count
        self.reviewableIfPresenceOnly = reports.filter { $0.missingCount == 0 }.count
        self.missingFindings = reports.reduce(0) { $0 + $1.missingCount }
        self.vacuousFindings = reports.reduce(0) { $0 + $1.vacuousCount }
        self.discoveryMinutesBlocked = reports.reduce(0) { $0 + ReviewGate.discoveryMinutes(of: $1, policy: policy) }
    }
}
