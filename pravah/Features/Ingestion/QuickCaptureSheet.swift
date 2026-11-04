import SwiftUI

struct QuickCaptureSheet: View {
    let onSave: @Sendable () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var contextEngine = ContextEngine()
    @State private var title = ""
    @State private var entryBody = ""
    @State private var tagsText = ""
    @State private var isSaving = false
    @State private var saveErrorMessage: String?

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
                    ContextBannerCard(
                        solarPhase: contextEngine.solarPhase,
                        locationName: contextEngine.locationName,
                        coordinate: contextEngine.currentLocation?.coordinate,
                        isFetching: contextEngine.isFetching
                    )
                }
            }
            .navigationTitle("Quick Capture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .task { await contextEngine.fetchCurrentContext() }
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
            latitude: coordinate?.latitude,
            longitude: coordinate?.longitude,
            locationName: contextEngine.locationName,
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
