import CoreLocation
import Foundation
import MapKit
import Observation

@MainActor @Observable
final class ContextEngine: NSObject, CLLocationManagerDelegate {
    private(set) var currentLocation: CLLocation?
    private(set) var locationName: String?
    private(set) var solarPhase: SolarPhase = .day
    private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    private(set) var isFetching = false

    private static let mockLocation = CLLocation(latitude: 37.8270, longitude: -122.4998)
    private static let mockLocationName = "Marin Headlands, CA"

    @ObservationIgnored private let locationManager = CLLocationManager()
    @ObservationIgnored private let solarPhaseCalculator = SolarPhaseCalculator()
    @ObservationIgnored private var locationContinuation: CheckedContinuation<CLLocation?, Never>?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = locationManager.authorizationStatus
    }

    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    func fetchCurrentContext() async {
        guard !isFetching else { return }
        isFetching = true
        defer { isFetching = false }

        guard let location = await requestLocation() else {
            applyMockContext()
            return
        }
        currentLocation = location
        solarPhase = solarPhaseCalculator.phase(at: location.timestamp, coordinate: location.coordinate)
        locationName = await placeName(for: location)
    }

    private func applyMockContext() {
        currentLocation = Self.mockLocation
        locationName = Self.mockLocationName
        solarPhase = solarPhaseCalculator.phase(at: .now, coordinate: nil)
    }

    private func requestLocation() async -> CLLocation? {
        let isRunningInPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        let isAuthorized = authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
        guard isAuthorized, !isRunningInPreview else { return nil }
        return await withCheckedContinuation { continuation in
            locationContinuation = continuation
            locationManager.requestLocation()
        }
    }

    private func placeName(for location: CLLocation?) async -> String? {
        guard let location, let request = MKReverseGeocodingRequest(location: location) else { return nil }
        return await withCheckedContinuation { continuation in
            request.getMapItems { mapItems, _ in
                let mapItem = mapItems?.first
                continuation.resume(returning: mapItem?.name ?? mapItem?.addressRepresentations?.cityName)
            }
        }
    }

    private func finishLocationRequest(with location: CLLocation?) {
        locationContinuation?.resume(returning: location)
        locationContinuation = nil
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let latestLocation = locations.last
        Task { @MainActor in finishLocationRequest(with: latestLocation) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in finishLocationRequest(with: nil) }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in authorizationStatus = status }
    }
}
