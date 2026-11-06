import SwiftUI
import CoreLocation

struct QuickCaptureSheet: View {
    let onSave: @Sendable () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var contextEngine = ContextEngine()
    @State private var title = ""
    @State private var entryBody = ""
    @State private var tagsText = ""
    @State private var isSaving = false
    @State private var saveErrorMessage: String?
    @State private var isPresentingLocationPicker = false
    @State private var customLatitude: Double?
    @State private var customLongitude: Double?
    @State private var customLocationName: String?

    init(initialPin: DroppedPin? = nil, onSave: @escaping @Sendable () -> Void) {
        self.onSave = onSave
        _customLatitude = State(initialValue: initialPin?.latitude)
        _customLongitude = State(initialValue: initialPin?.longitude)
        _customLocationName = State(initialValue: initialPin?.displayName)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Entry Title", text: $title)
                    TextField("Write field notes or observations...", text: $entryBody, axis: .vertical)
                        .lineLimit(5...12)
                    TextField("Tags (comma separated)", text: $tagsText)
                        .textInputAutocapitalization(.never)
                }
                Section("Context") {
                    locationBannerButton
                }
            }
            .navigationTitle("Quick Capture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .task { await contextEngine.fetchCurrentContext() }
            .sheet(isPresented: $isPresentingLocationPicker) { locationPicker }
            .alert("Couldn't Save Entry", isPresented: isShowingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(saveErrorMessage ?? "")
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Save Entry") {
                Task { await saveEntry() }
            }
            .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
        }
    }

    private var locationBannerButton: some View {
        Button(action: {
            isPresentingLocationPicker = true
        }) {
            HStack {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundColor(.red)
                VStack(alignment: .leading) {
                    Text(customLocationName ?? contextEngine.locationName ?? "Select Location")
                        .font(.headline)
                    Text("Tap to search address or drop pin")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }

    private var locationPicker: some View {
        let currentCoordinate = contextEngine.currentLocation?.coordinate
        let latitude = customLatitude ?? currentCoordinate?.latitude
        let longitude = customLongitude ?? currentCoordinate?.longitude
        let initialCoordinate = latitude.flatMap { latitude in
            longitude.map { CLLocationCoordinate2D(latitude: latitude, longitude: $0) }
        }
        return LocationPickerView(
            initialCoordinate: initialCoordinate,
            initialLocationName: customLocationName ?? contextEngine.locationName
        ) { coordinate, name in
            Task { @MainActor in
                customLatitude = coordinate.latitude
                customLongitude = coordinate.longitude
                customLocationName = name
            }
        }
    }

    private var isShowingError: Binding<Bool> {
        Binding(
            get: { saveErrorMessage != nil },
            set: { if !$0 { saveErrorMessage = nil } }
        )
    }

    private var parsedTags: [String] {
        tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private func makeEntry() -> JournalEntry {
        let coordinate = contextEngine.currentLocation?.coordinate
        return JournalEntry(
            title: title.trimmingCharacters(in: .whitespaces),
            body: entryBody,
            latitude: customLatitude ?? coordinate?.latitude,
            longitude: customLongitude ?? coordinate?.longitude,
            locationName: customLocationName ?? contextEngine.locationName,
            solarPhase: contextEngine.solarPhase,
            tags: parsedTags
        )
    }

    private func saveEntry() async {
        isSaving = true
        defer { isSaving = false }
        do {
            _ = try await VaultActor().saveEntry(makeEntry())
            onSave()
            dismiss()
        } catch {
            saveErrorMessage = error.localizedDescription
        }
    }
}

#Preview {
    QuickCaptureSheet(onSave: { })
}
