import CoreLocation
import Foundation
import SwiftUI

struct SolarPhaseCalculator: Sendable {
    private static let goldenHourRange = -4.0...6.0

    func phase(at date: Date, coordinate: CLLocationCoordinate2D?) -> SolarPhase {
        guard let coordinate else { return phaseFromLocalHour(of: date) }
        let elevation = solarElevationDegrees(at: date, coordinate: coordinate)
        if elevation < Self.goldenHourRange.lowerBound { return .night }
        if elevation <= Self.goldenHourRange.upperBound { return .goldenHour }
        return .day
    }

    private func phaseFromLocalHour(of date: Date) -> SolarPhase {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 20..., ..<6: return .night
        case 6, 19: return .goldenHour
        default: return .day
        }
    }

    private func solarElevationDegrees(at date: Date, coordinate: CLLocationCoordinate2D) -> Double {
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        let dayOfYear = Double(utcCalendar.ordinality(of: .day, in: .year, for: date) ?? 1)
        let components = utcCalendar.dateComponents([.hour, .minute, .second], from: date)
        let utcMinutes = Double(components.hour ?? 0) * 60
            + Double(components.minute ?? 0)
            + Double(components.second ?? 0) / 60

        let yearAngle = 2 * Double.pi * (dayOfYear - 81) / 364
        let equationOfTimeMinutes = 9.87 * sin(2 * yearAngle) - 7.53 * cos(yearAngle) - 1.5 * sin(yearAngle)
        let declination = (23.44 * sin(yearAngle)).radians

        let solarMinutes = utcMinutes + 4 * coordinate.longitude + equationOfTimeMinutes
        let hourAngle = (solarMinutes / 4 - 180).radians
        let latitude = coordinate.latitude.radians

        let sineOfElevation = sin(latitude) * sin(declination)
            + cos(latitude) * cos(declination) * cos(hourAngle)
        return asin(max(-1, min(1, sineOfElevation))) * 180 / .pi
    }
}

private extension Double {
    var radians: Double { self * .pi / 180 }
}



#Preview("Context Engine Triangulation Test") {
    struct ContextPreviewHarness: View {
        @State private var engine = ContextEngine()

        var body: some View {
            VStack(spacing: 18) {
                Image(systemName: engine.solarPhase == .goldenHour ? "sun.haze.fill" : (engine.solarPhase == .night ? "moon.stars.fill" : "sun.max.fill"))
                    .font(.system(size: 48))
                    .foregroundStyle(engine.solarPhase == .goldenHour ? .orange : (engine.solarPhase == .night ? .indigo : .yellow))

                Text("Solar Phase: \(engine.solarPhase.rawValue.capitalized)")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Location Name:")
                            .bold()
                        Spacer()
                        Text(engine.locationName ?? "Not Geocoded")
                            .foregroundStyle(.secondary)
                    }
                    Divider()
                    HStack {
                        Text("Coordinates:")
                            .bold()
                        Spacer()
                        if let loc = engine.currentLocation {
                            Text(String(format: "%.4f, %.4f", loc.coordinate.latitude, loc.coordinate.longitude))
                                .font(.caption.monospaced())
                        } else {
                            Text("No GPS Signal")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                Button(action: {
                    Task {
                        await engine.fetchCurrentContext()
                    }
                }) {
                    HStack {
                        if engine.isFetching {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "location.fill")
                            Text("Fetch Context")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }

    return ContextPreviewHarness()
}

