import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: \BillSession.date, order: .reverse)
    private var sessions: [BillSession]

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty { emptyState } else { list }
            }
            .navigationTitle("History")
        }
    }

    private var list: some View {
        List {
            ForEach(sessions) { session in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.formattedTotal)
                            .font(.headline)
                        Text("\(session.dinerCount) people · \(session.date.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "camera.viewfinder")
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)
            }
            .onDelete { offsets in offsets.forEach { modelContext.delete(sessions[$0]) } }
        }
        .listStyle(.insetGrouped)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.badge.xmark")
                .font(.system(size: 52))
                .foregroundStyle(.tertiary)
            Text("No splits yet")
                .font(.title3.weight(.medium))
            Text("Completed splits will appear here.")
                .foregroundStyle(.secondary)
                .font(.subheadline)
        }
    }
}
