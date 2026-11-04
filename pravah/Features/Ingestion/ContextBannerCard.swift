import CoreLocation
import SwiftUI

struct ContextBannerCard: View {
    let solarPhase: SolarPhase
    let locationName: String?
    let coordinate: CLLocationCoordinate2D?
    let isFetching: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(solarPhase.displayName, systemImage: solarPhase.symbolName)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.tint.opacity(0.15), in: .capsule)
            HStack(spacing: 6) {
                Label(locationText, systemImage: "mappin.and.ellipse")
                if isFetching { ProgressView().controlSize(.small) }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var locationText: String {
        if let locationName { return locationName }
        guard let coordinate else { return "Locating…" }
        return String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude)
    }
}

extension SolarPhase {
    var displayName: String {
        switch self {
        case .day: "Day"
        case .goldenHour: "Golden Hour"
        case .night: "Night"
        }
    }

    var symbolName: String {
        switch self {
        case .day: "sun.max"
        case .goldenHour: "sun.horizon"
        case .night: "moon.stars"
        }
    }
}

#Preview {
    ContextBannerCard(
        solarPhase: .goldenHour,
        locationName: "Marin Headlands, CA",
        coordinate: nil,
        isFetching: false
    )
    .padding()
}
