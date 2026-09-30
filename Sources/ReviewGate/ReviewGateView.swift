#if canImport(SwiftUI)
import SwiftUI

/// The demo screen: every fixture PR with its verdict, and the itemised reasons on tap.
public struct ReviewGateView: View {
    private let summary: BatchSummary
    private let packets: [PullRequestPacket]
    @State private var presenceOnly = false

    public init(packets: [PullRequestPacket] = Fixtures.all, policy: ReviewPolicy = ReviewPolicy()) {
        self.packets = packets
        self.summary = BatchSummary(packets: packets, policy: policy)
    }

    public var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("Presence-only checklist", isOn: $presenceOnly)
                    Text(headline).font(.subheadline).foregroundStyle(.secondary)
                }
                Section("Pull requests") {
                    ForEach(packets, id: \.id) { packet in
                        if let report = summary.reports.first(where: { $0.packetID == packet.id }) {
                            NavigationLink {
                                DetailView(packet: packet, report: report)
                            } label: {
                                Row(packet: packet, ok: passes(report))
                            }
                        }
                    }
                }
            }
            .navigationTitle("Definition of reviewable")
        }
    }

    private func passes(_ report: ReadinessReport) -> Bool {
        presenceOnly ? report.missingCount == 0 : report.verdict == .reviewable
    }

    private var headline: String {
        let n = presenceOnly ? summary.reviewableIfPresenceOnly : summary.reviewable
        return "\(n) of \(summary.total) reach a human. Presence-only lets \(summary.waveThroughs) more through than the gate."
    }

    private struct Row: View {
        let packet: PullRequestPacket
        let ok: Bool
        var body: some View {
            HStack {
                Image(systemName: ok ? "checkmark.circle.fill" : "xmark.octagon.fill")
                    .foregroundStyle(ok ? .green : .red)
                VStack(alignment: .leading) {
                    Text(packet.id).font(.caption.monospaced()).foregroundStyle(.secondary)
                    Text(packet.title)
                }
                Spacer()
                Text(packet.author.rawValue).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private struct DetailView: View {
        let packet: PullRequestPacket
        let report: ReadinessReport
        var body: some View {
            List(Array(report.findings.enumerated()), id: \.offset) { _, f in
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(f.surface.rawValue) · \(f.status.rawValue)").font(.headline)
                    Text(f.reason).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .overlay { if report.findings.isEmpty { Text("Nothing on the hook.").foregroundStyle(.secondary) } }
            .navigationTitle(packet.id)
        }
    }
}
#endif
