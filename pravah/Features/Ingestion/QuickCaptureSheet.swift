import SwiftUI
import CoreLocation
import PhotosUI

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
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var selectedImageData: Data? = nil
    @State private var selectedImagePreview: Image? = nil
    @State private var didExtractText = false

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
                Section("Attachments") {
                    attachmentContent
                }
            }
            .navigationTitle("Quick Capture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .task { await contextEngine.fetchCurrentContext() }
            .onChange(of: selectedPhotoItem) { _, item in
                Task { await loadPhoto(from: item) }
            }
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

    @ViewBuilder
    private var attachmentContent: some View {
        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
            Label("Attach Photo", systemImage: "photo.badge.plus")
        }
        if let selectedImagePreview {
            selectedImagePreview
                .resizable()
                .scaledToFill()
                .frame(height: 180)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(alignment: .topTrailing) { removePhotoButton }
        }
        if didExtractText {
            Label("OCR Extracted", systemImage: "sparkles")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tint)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.tint.opacity(0.15), in: .capsule)
        }
    }

    private var removePhotoButton: some View {
        Button(action: removePhoto) {
            Image(systemName: "xmark.circle.fill")
                .font(.title2)
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .red)
        }
        .buttonStyle(.plain)
        .padding(8)
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

    private func loadPhoto(from item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self),
              let pngData = UIImage(data: data)?.pngData() else { return }
        selectedImageData = pngData
        selectedImagePreview = UIImage(data: pngData).map(Image.init(uiImage:))
        await appendExtractedText(from: pngData)
    }

    private func appendExtractedText(from imageData: Data) async {
        let recognizedText = (try? await OCREngine().recognizeText(in: imageData)) ?? ""
        let trimmedText = recognizedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        let separator = entryBody.isEmpty ? "" : "\n\n"
        entryBody += "\(separator)--- Extracted Text ---\n\(trimmedText)"
        didExtractText = true
    }

    private func removePhoto() {
        didExtractText = false
        selectedPhotoItem = nil
        selectedImageData = nil
        selectedImagePreview = nil
    }

    private func saveEntry() async {
        isSaving = true
        defer { isSaving = false }
        do {
            let vault = VaultActor()
            var entry = makeEntry()
            if let imageData = selectedImageData {
                let assetPath = try await vault.saveAssetData(imageData, fileExtension: "png")
                entry.assetRelativePaths = [assetPath]
            }
            _ = try await vault.saveEntry(entry)
            await indexEmbedding(for: entry)
            onSave()
            dismiss()
        } catch {
            saveErrorMessage = error.localizedDescription
        }
    }

    private func indexEmbedding(for entry: JournalEntry) async {
        let combinedText = [entry.title, entry.body]
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
        guard let vector = await EmbeddingEngine().generateEmbedding(for: combinedText) else { return }
        let vectorStore = VectorStoreActor()
        await vectorStore.loadPersistedVectors()
        await vectorStore.setVector(vector, for: entry.id)
    }
}

#Preview {
    QuickCaptureSheet(onSave: { })
}
