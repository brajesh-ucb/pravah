import SwiftUI

struct JournalEntryCard: View {
    let entry: JournalEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(entry.title)
                    .font(.headline)
                Spacer(minLength: 8)
                Label(entry.solarPhase.displayName, systemImage: entry.solarPhase.symbolName)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.tint.opacity(0.15), in: .capsule)
            }
            Text(entry.createdAt, format: .relative(presentation: .named))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if !entry.body.isEmpty {
                Text(entry.body)
                    .font(.subheadline)
                    .lineLimit(2)
            }
            Label(locationText, systemImage: "mappin.and.ellipse")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 18))
    }

    private var locationText: String {
        if let locationName = entry.locationName { return locationName }
        guard let latitude = entry.latitude, let longitude = entry.longitude else { return "Unknown location" }
        return String(format: "%.4f, %.4f", latitude, longitude)
    }
}

#Preview {
    JournalEntryCard(
        entry: JournalEntry(
            title: "Golden Hour Trail Sketch",
            body: "Recorded ambient observations near the stream.",
            latitude: 37.8270,
            longitude: -122.4998,
            locationName: "Marin Headlands, CA",
            solarPhase: .goldenHour
        )
    )
    .padding()
}
