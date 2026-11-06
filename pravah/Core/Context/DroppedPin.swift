import Foundation

struct DroppedPin: Equatable, Sendable {
    let latitude: Double
    let longitude: Double
    var placeName: String

    var displayName: String {
        placeName.isEmpty ? String(format: "%.5f, %.5f", latitude, longitude) : placeName
    }
}
