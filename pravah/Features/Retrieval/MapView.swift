import MapKit
import SwiftUI

struct MapView: View {
    let entries: [JournalEntry]
    var onSelectEntry: (JournalEntry) -> Void = { _ in }

    @State private var cameraPosition: MapCameraPosition

    init(entries: [JournalEntry], onSelectEntry: @escaping (JournalEntry) -> Void = { _ in }) {
        self.entries = entries
        self.onSelectEntry = onSelectEntry
        _cameraPosition = State(initialValue: .region(Self.region(for: entries)))
    }

    var body: some View {
        Map(position: $cameraPosition) {
            ForEach(geotaggedEntries) { entry in
                if let coordinate = Self.coordinate(of: entry) {
                    Annotation(entry.title, coordinate: coordinate, anchor: .bottom) {
                        Button { onSelectEntry(entry) } label: {
                            EntryAnnotationBubble(entry: entry)
                        }
                        .buttonStyle(.plain)
                    }
                    .annotationTitles(.hidden)
                }
            }
        }
        .onChange(of: entries) {
            withAnimation { cameraPosition = .region(Self.region(for: entries)) }
        }
    }

    private var geotaggedEntries: [JournalEntry] {
        entries.filter { Self.coordinate(of: $0) != nil }
    }
}

private extension MapView {
    static let defaultCenter = CLLocationCoordinate2D(latitude: 37.8270, longitude: -122.4998)
    static let minimumSpan = 0.05
    static let spanPadding = 1.4

    static func coordinate(of entry: JournalEntry) -> CLLocationCoordinate2D? {
        guard let latitude = entry.latitude, let longitude = entry.longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    static func region(for entries: [JournalEntry]) -> MKCoordinateRegion {
        let coordinates = entries.compactMap(coordinate(of:))
        guard let first = coordinates.first else {
            return MKCoordinateRegion(
                center: defaultCenter,
                span: MKCoordinateSpan(latitudeDelta: minimumSpan, longitudeDelta: minimumSpan)
            )
        }
        let latitudes = coordinates.map(\.latitude)
        let longitudes = coordinates.map(\.longitude)
        let minLatitude = latitudes.min() ?? first.latitude
        let maxLatitude = latitudes.max() ?? first.latitude
        let minLongitude = longitudes.min() ?? first.longitude
        let maxLongitude = longitudes.max() ?? first.longitude

        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: (minLatitude + maxLatitude) / 2,
                longitude: (minLongitude + maxLongitude) / 2
            ),
            span: MKCoordinateSpan(
                latitudeDelta: max((maxLatitude - minLatitude) * spanPadding, minimumSpan),
                longitudeDelta: max((maxLongitude - minLongitude) * spanPadding, minimumSpan)
            )
        )
    }
}

private struct EntryAnnotationBubble: View {
    let entry: JournalEntry

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: entry.solarPhase.mapSymbolName)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(entry.solarPhase.badgeColor, in: .circle)
            Text(entry.title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        }
        .padding(.leading, 4)
        .padding(.trailing, 10)
        .padding(.vertical, 4)
        .background(.regularMaterial, in: .capsule)
        .shadow(radius: 2, y: 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.title), \(entry.solarPhase.displayName)")
    }
}

private extension SolarPhase {
    var mapSymbolName: String {
        switch self {
        case .day: "sun.max.fill"
        case .goldenHour: "sun.horizon.fill"
        case .night: "moon.stars.fill"
        }
    }

    var badgeColor: Color {
        switch self {
        case .day: .blue
        case .goldenHour: .orange
        case .night: .indigo
        }
    }
}

#Preview {
    MapView(
        entries: [
            JournalEntry(
                title: "Golden Hour Trail Sketch",
                body: "Observations near the stream.",
                latitude: 37.8270,
                longitude: -122.4998,
                locationName: "Marin Headlands, CA",
                solarPhase: .goldenHour
            ),
            JournalEntry(
                title: "Noon at the Bridge",
                body: "",
                latitude: 37.8199,
                longitude: -122.4783,
                solarPhase: .day
            ),
            JournalEntry(
                title: "Night Fog",
                body: "",
                latitude: 37.7749,
                longitude: -122.4194,
                solarPhase: .night
            )
        ]
    )
}
