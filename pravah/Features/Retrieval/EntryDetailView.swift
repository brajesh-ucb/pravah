import SwiftUI

struct EntryDetailView: View {
    let entry: JournalEntry

    @State private var loadedImages: [UIImage] = []
    @State private var vault = VaultActor()
    @State private var selectedPreviewImage: UIImage? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if !entry.tags.isEmpty { tagRow }
                Divider()
                bodyText
                if !loadedImages.isEmpty { attachmentsSection }
                vaultPathFooter
            }
            .padding()
        }
        .task { await loadAttachedAssets() }
        .fullScreenCover(isPresented: isShowingPreview) {
            if let selectedPreviewImage {
                ImagePreviewView(image: selectedPreviewImage)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: YAMLSerializer.exportToMarkdown(entry))
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.title)
                .font(.largeTitle.bold())
            Text("\(entry.createdAt.formatted(date: .long, time: .shortened)) · \(entry.createdAt.formatted(.relative(presentation: .named)))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            contextBadges
        }
    }

    private var contextBadges: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                badge(entry.solarPhase.displayName, systemImage: entry.solarPhase.symbolName)
                if let locationName = entry.locationName {
                    badge(locationName, systemImage: "mappin")
                }
                if let coordinateText {
                    badge(coordinateText, systemImage: "location")
                }
            }
        }
    }

    private func badge(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.tint.opacity(0.15), in: .capsule)
    }

    private var tagRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(entry.tags, id: \.self) { tag in
                    Text("#\(tag)")
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.quaternary, in: .capsule)
                }
            }
        }
    }

    private var bodyText: some View {
        Text(entry.body.isEmpty ? "No content." : entry.body)
            .font(.body)
            .lineSpacing(4)
            .foregroundStyle(entry.body.isEmpty ? .secondary : .primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
            .padding(.vertical, 8)
    }

    private var attachmentsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Attachments")
                .font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(loadedImages.indices, id: \.self) { index in
                        attachmentThumbnail(loadedImages[index])
                    }
                }
                .padding(.vertical, 6)
            }
        }
    }

    private func attachmentThumbnail(_ image: UIImage) -> some View {
        Button {
            selectedPreviewImage = image
        } label: {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(height: 180)
                .clipShape(.rect(cornerRadius: 12))
                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Attached photo")
    }

    private var isShowingPreview: Binding<Bool> {
        Binding(
            get: { selectedPreviewImage != nil },
            set: { if !$0 { selectedPreviewImage = nil } }
        )
    }

    private func loadAttachedAssets() async {
        guard !entry.assetRelativePaths.isEmpty else { return }
        var images: [UIImage] = []
        for path in entry.assetRelativePaths {
            guard let data = try? await vault.loadAssetData(relativePath: path),
                  let image = UIImage(data: data) else { continue }
            images.append(image)
        }
        loadedImages = images
    }

    private var vaultPathFooter: some View {
        Text(vaultRelativePath)
            .font(.system(.footnote, design: .monospaced))
            .foregroundStyle(.secondary)
            .textSelection(.enabled)
            .padding(.top, 16)
    }

    private var coordinateText: String? {
        guard let latitude = entry.latitude, let longitude = entry.longitude else { return nil }
        return String(format: "%.4f, %.4f", latitude, longitude)
    }

    private var vaultRelativePath: String {
        let components = Calendar.current.dateComponents([.year, .month], from: entry.createdAt)
        let month = String(format: "%04d-%02d", components.year ?? 0, components.month ?? 0)
        return "/Vault/\(month)/\(entry.id.uuidString).md"
    }
}

#Preview {
    NavigationStack {
        EntryDetailView(
            entry: JournalEntry(
                title: "Golden Hour Trail Sketch",
                body: "Recorded ambient observations near the stream.\n\nThe light turned amber just past the ridge.",
                latitude: 37.8270,
                longitude: -122.4998,
                locationName: "Marin Headlands, CA",
                solarPhase: .goldenHour,
                tags: ["trail", "sketch", "light"]
            )
        )
    }
}
