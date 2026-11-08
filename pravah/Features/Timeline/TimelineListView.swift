import SwiftUI

struct TimelineListView: View {
    let entries: [JournalEntry]
    var semanticMatchedIDs: Set<UUID> = []

    var body: some View {
        if entries.isEmpty {
            ContentUnavailableView(
                "No Entries Yet",
                systemImage: "book.closed",
                description: Text("No field journal entries yet. Tap + to capture your first entry.")
            )
        } else {
            List {
                ForEach(entries) { entry in
                    NavigationLink(value: entry) {
                        JournalEntryCard(entry: entry)
                            .overlay(alignment: .topTrailing) {
                                if semanticMatchedIDs.contains(entry.id) {
                                    Image(systemName: "sparkles")
                                        .font(.caption)
                                        .foregroundStyle(.tint)
                                        .padding(8)
                                        .accessibilityLabel("Semantic match")
                                }
                            }
                    }
                    .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
        }
    }
}

#Preview("Entries") {
    TimelineListView(entries: [
        JournalEntry(title: "Sunrise at the ghats", body: "Mist over the river.", solarPhase: .day)
    ])
}

#Preview("Empty") {
    TimelineListView(entries: [])
}
