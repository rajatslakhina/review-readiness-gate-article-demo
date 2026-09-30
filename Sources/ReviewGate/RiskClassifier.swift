import Foundation

/// Decides which surfaces a diff touches, from file paths and added lines only.
/// Deliberately dumb: a reviewer must be able to predict its answer.
public struct RiskClassifier: Sendable {
    public var hotPathPrefixes: [String]
    public var concurrencyMarkers: [String]

    public init(hotPathPrefixes: [String] = ["Sources/Feed/", "Sources/Render/"],
                concurrencyMarkers: [String] = [
                    "@MainActor", "nonisolated", "Task.detached", "@unchecked Sendable",
                    "actor ", "Task {", "DispatchQueue", "withTaskGroup"
                ]) {
        self.hotPathPrefixes = hotPathPrefixes
        self.concurrencyMarkers = concurrencyMarkers
    }

    /// The files that put a surface on the hook, so evidence can be checked against them.
    public func triggers(in files: [ChangedFile]) -> [Surface: [ChangedFile]] {
        var out: [Surface: [ChangedFile]] = [:]
        for file in files {
            for surface in surfaces(of: file) { out[surface, default: []].append(file) }
        }
        return out
    }

    public func surfaces(of file: ChangedFile) -> Set<Surface> {
        var found: Set<Surface> = []
        let path = file.path
        if path.hasSuffix(".entitlements") || path.hasSuffix("Info.plist")
            || path.hasSuffix("PrivacyInfo.xcprivacy") {
            found.insert(.entitlements)
        }
        guard path.hasSuffix(".swift") else { return found }
        if path.hasSuffix("View.swift") || path.contains("/Views/")
            || file.addedLines.contains(where: { $0.contains("import SwiftUI") || $0.contains(": View {") || $0.contains("UIViewController") }) {
            found.insert(.ui)
        }
        if file.addedLines.contains(where: { line in concurrencyMarkers.contains(where: line.contains) }) {
            found.insert(.concurrency)
        }
        if hotPathPrefixes.contains(where: path.hasPrefix) { found.insert(.hotPath) }
        return found
    }
}
