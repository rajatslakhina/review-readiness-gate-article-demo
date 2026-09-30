import Foundation

/// The written definition of "reviewable", as data, so a hook, a CI job and a
/// SwiftUI preview all evaluate the same thing.
public struct ReviewPolicy: Sendable {
    public var classifier: RiskClassifier
    /// A benchmark delta from fewer runs than this is noise, not evidence.
    public var minBenchmarkRuns: Int
    /// An isolation or entitlement note shorter than this is a shrug.
    public var minNoteLength: Int
    /// Agent PRs touching at least this many files must list at least one assumption.
    public var assumptionsRequiredFromFiles: Int
    /// Strings that count as "I have nothing to say".
    public var emptyAssumptionPhrases: Set<String>

    public init(classifier: RiskClassifier = RiskClassifier(),
                minBenchmarkRuns: Int = 5,
                minNoteLength: Int = 40,
                assumptionsRequiredFromFiles: Int = 3,
                emptyAssumptionPhrases: Set<String> = ["none", "n/a", "na", "no assumptions", "-"]) {
        self.classifier = classifier
        self.minBenchmarkRuns = max(1, minBenchmarkRuns)
        self.minNoteLength = max(0, minNoteLength)
        self.assumptionsRequiredFromFiles = max(1, assumptionsRequiredFromFiles)
        self.emptyAssumptionPhrases = emptyAssumptionPhrases
    }

    /// Minutes a reviewer spends discovering each thing by hand. These are policy
    /// weights you set from your own team's history, not measurements.
    public var discoveryMinutes: [Surface: Int] = [
        .ui: 12, .concurrency: 18, .entitlements: 10, .hotPath: 20, .assumptions: 8
    ]
}
