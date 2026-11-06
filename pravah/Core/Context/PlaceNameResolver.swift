import CoreLocation
import MapKit

enum PlaceNameResolver {
    static func placeName(at coordinate: CLLocationCoordinate2D) async -> String? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let request = MKReverseGeocodingRequest(location: location)
        let mapItem = try? await request?.mapItems.first
        return mapItem?.name ?? mapItem?.addressRepresentations?.cityName
    }
}
