import SwiftUI
import MapKit
import CoreLocation

struct LocationPickerView: View {
    let initialCoordinate: CLLocationCoordinate2D?
    let initialLocationName: String?
    let onConfirmLocation: @Sendable (CLLocationCoordinate2D, String) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var searchQuery = ""
    @State private var suggestions: [LocationSuggestion] = []
    @State private var cameraPosition: MapCameraPosition
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var selectedLocationName: String
    @State private var searchTask: Task<Void, Never>?
    @State private var geocodeTask: Task<Void, Never>?
    @FocusState private var isSearchFocused: Bool

    init(
        initialCoordinate: CLLocationCoordinate2D? = nil,
        initialLocationName: String? = nil,
        onConfirmLocation: @escaping @Sendable (CLLocationCoordinate2D, String) -> Void
    ) {
        self.initialCoordinate = initialCoordinate
        self.initialLocationName = initialLocationName
        self.onConfirmLocation = onConfirmLocation
        _selectedCoordinate = State(initialValue: initialCoordinate)
        _selectedLocationName = State(initialValue: initialLocationName ?? "")
        _cameraPosition = State(initialValue: Self.cameraPosition(for: initialCoordinate))
    }

    var body: some View {
        NavigationStack {
            mapReader
                .overlay(alignment: .top) { suggestionList }
                .safeAreaInset(edge: .top) { searchBar }
                .safeAreaInset(edge: .bottom) { confirmationBar }
                .navigationTitle("Choose Location")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
        }
    }
}

private extension LocationPickerView {
    struct LocationSuggestion: Identifiable, Sendable {
        let id = UUID()
        let title: String
        let subtitle: String
        let coordinate: CLLocationCoordinate2D
    }

    static func cameraPosition(for coordinate: CLLocationCoordinate2D?) -> MapCameraPosition {
        guard let coordinate else { return .automatic }
        return .region(MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 1000,
            longitudinalMeters: 1000
        ))
    }

    func centerCamera(on coordinate: CLLocationCoordinate2D) {
        withAnimation(.easeInOut) {
            cameraPosition = Self.cameraPosition(for: coordinate)
        }
    }

    var mapReader: some View {
        MapReader { mapProxy in
            Map(position: $cameraPosition) {
                if let selectedCoordinate {
                    Marker(
                        selectedLocationName.isEmpty ? "Selected Location" : selectedLocationName,
                        coordinate: selectedCoordinate
                    )
                }
            }
            .mapFeatureSelectionDisabled { _ in true }
            .onTapGesture { screenPoint in
                guard let tappedCoordinate = mapProxy.convert(screenPoint, from: .local) else { return }
                dropPin(at: tappedCoordinate)
            }
        }
    }

    var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search address, city, or landmark...", text: $searchQuery)
                .textInputAutocapitalization(.words)
                .focused($isSearchFocused)
                .submitLabel(.search)
                .onSubmit { scheduleSearch(debounce: false) }
            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .foregroundStyle(.secondary)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .onChange(of: searchQuery) { scheduleSearch(debounce: true) }
    }

    @ViewBuilder
    var suggestionList: some View {
        if !suggestions.isEmpty {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(suggestions) { suggestion in
                        suggestionRow(suggestion)
                        Divider()
                    }
                }
            }
            .frame(maxHeight: 260)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
            .padding(.top, 64)
        }
    }

    func suggestionRow(_ suggestion: LocationSuggestion) -> some View {
        Button {
            select(suggestion)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(suggestion.title)
                    .font(.body)
                if !suggestion.subtitle.isEmpty {
                    Text(suggestion.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    var confirmationBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(selectedLocationName.isEmpty ? "Tap the map to drop a pin" : selectedLocationName)
                    .font(.headline)
                if let selectedCoordinate {
                    Text(Self.coordinateText(selectedCoordinate))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            Button("Confirm Location", action: confirm)
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .disabled(selectedCoordinate == nil)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
    }

    static func coordinateText(_ coordinate: CLLocationCoordinate2D) -> String {
        String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude)
    }

    func scheduleSearch(debounce: Bool) {
        searchTask?.cancel()
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            suggestions = []
            return
        }
        searchTask = Task {
            if debounce { try? await Task.sleep(for: .milliseconds(300)) }
            guard !Task.isCancelled else { return }
            let results = await Self.search(query: query)
            guard !Task.isCancelled else { return }
            suggestions = results
        }
    }

    static func search(query: String) async -> [LocationSuggestion] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        guard let response = try? await MKLocalSearch(request: request).start() else { return [] }
        return response.mapItems.map { result in
            let fullAddress = result.address?.fullAddress
            return LocationSuggestion(
                title: result.name ?? fullAddress ?? "Selected Location",
                subtitle: fullAddress ?? "",
                coordinate: result.location.coordinate
            )
        }
    }

    func select(_ suggestion: LocationSuggestion) {
        geocodeTask?.cancel()
        searchTask?.cancel()
        suggestions = []
        searchQuery = ""
        selectedCoordinate = suggestion.coordinate
        selectedLocationName = suggestion.title
        isSearchFocused = false
        centerCamera(on: suggestion.coordinate)
    }

    func dropPin(at coordinate: CLLocationCoordinate2D) {
        suggestions = []
        isSearchFocused = false
        selectedCoordinate = coordinate
        selectedLocationName = ""
        centerCamera(on: coordinate)
        geocodeTask?.cancel()
        geocodeTask = Task {
            let placeName = await Self.placeName(at: coordinate)
            guard !Task.isCancelled else { return }
            selectedLocationName = placeName
        }
    }

    static func placeName(at coordinate: CLLocationCoordinate2D) async -> String {
        await PlaceNameResolver.placeName(at: coordinate) ?? coordinateText(coordinate)
    }

    func confirm() {
        guard let selectedCoordinate else { return }
        let resolvedName = selectedLocationName.isEmpty
            ? Self.coordinateText(selectedCoordinate)
            : selectedLocationName
        onConfirmLocation(selectedCoordinate, resolvedName)
        dismiss()
    }
}

#Preview {
    LocationPickerView(
        initialCoordinate: CLLocationCoordinate2D(latitude: 12.9716, longitude: 77.5946),
        initialLocationName: "Bengaluru",
        onConfirmLocation: { _, _ in }
    )
}
