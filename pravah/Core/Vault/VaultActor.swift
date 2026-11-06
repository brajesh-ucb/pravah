import Foundation
import SwiftUI


enum VaultError: Error, Sendable {
    case fileNotFound(URL)
    case directoryCreationFailed(URL)
    case writeFailed(URL)
    case readFailed(URL)
}

actor VaultActor {
    private static let assetsDirectoryName = "Assets"

    let vaultURL: URL
    private var assetsURL: URL { vaultURL.appending(path: Self.assetsDirectoryName, directoryHint: .isDirectory) }

    init(vaultURL: URL? = nil) {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let resolvedURL = vaultURL ?? documentsURL.appending(path: "Vault", directoryHint: .isDirectory)
        self.vaultURL = resolvedURL
        try? FileManager.default.createDirectory(
            at: resolvedURL.appending(path: Self.assetsDirectoryName, directoryHint: .isDirectory),
            withIntermediateDirectories: true
        )
    }

    func saveEntry(_ entry: JournalEntry) async throws -> URL {
        let monthURL = vaultURL.appending(path: Self.monthFolderName(for: entry.createdAt), directoryHint: .isDirectory)
        try createDirectory(at: monthURL)

        let fileURL = monthURL.appending(path: "\(entry.id.uuidString).md", directoryHint: .notDirectory)
        let markdown = YAMLSerializer.exportToMarkdown(entry)
        try write(Data(markdown.utf8), to: fileURL)
        return fileURL
    }

    func loadEntry(at url: URL) async throws -> JournalEntry {
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else {
            throw VaultError.fileNotFound(url)
        }
        guard let markdown = try? String(contentsOf: url, encoding: .utf8) else {
            throw VaultError.readFailed(url)
        }
        return try YAMLSerializer.parseFromMarkdown(markdown)
    }

    func fetchAllEntries() async throws -> [JournalEntry] {
        let vaultPath = vaultURL.path(percentEncoded: false)
        guard let relativePaths = try? FileManager.default.subpathsOfDirectory(atPath: vaultPath) else {
            throw VaultError.readFailed(vaultURL)
        }

        var entries: [JournalEntry] = []
        for relativePath in relativePaths where relativePath.hasSuffix(".md") {
            let fileURL = vaultURL.appending(path: relativePath, directoryHint: .notDirectory)
            entries.append(try await loadEntry(at: fileURL))
        }
        return entries.sorted { $0.createdAt > $1.createdAt }
    }

    func saveAssetData(_ data: Data, fileExtension: String) async throws -> String {
        try createDirectory(at: assetsURL)

        let fileName = "asset_\(UUID().uuidString).\(fileExtension)"
        try write(data, to: assetsURL.appending(path: fileName, directoryHint: .notDirectory))
        return "\(Self.assetsDirectoryName)/\(fileName)"
    }

    func loadAssetData(relativePath: String) async throws -> Data {
        let url = vaultURL.appending(path: relativePath, directoryHint: .notDirectory).standardizedFileURL
        guard url.path(percentEncoded: false).hasPrefix(assetsURL.standardizedFileURL.path(percentEncoded: false)) else {
            throw VaultError.readFailed(url)
        }
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else {
            throw VaultError.fileNotFound(url)
        }
        guard let data = try? Data(contentsOf: url) else {
            throw VaultError.readFailed(url)
        }
        return data
    }
}

private extension VaultActor {
    static func monthFolderName(for date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", components.year ?? 0, components.month ?? 0)
    }

    func createDirectory(at url: URL) throws {
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        } catch {
            throw VaultError.directoryCreationFailed(url)
        }
    }

    func write(_ data: Data, to url: URL) throws {
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw VaultError.writeFailed(url)
        }
    }
}

#Preview("Vault File I/O Test") {
    struct PreviewHarness: View {
        @State private var statusMessage = "Tap button to test vault storage"
        @State private var savedTitle = ""
        @State private var totalCount = 0
        var body: some View {
            VStack(spacing: 20) {
                Button("Test Save &amp; Load Entry") {
                    Task {
                        let vault = VaultActor()
                        let testEntry = JournalEntry(
                        title: "San Francisco Coastal Walk",
                        body: "Tested filesystem vault writing under Swift 6 actor isolation.",
                        latitude: 37.7749,
                        longitude: -122.4194,
                        locationName: "San Francisco",
                        solarPhase: .day,
                        tags: ["test", "filesystem"] )
                    do {
                        let fileURL = try await vault.saveEntry(testEntry)
                        let loaded = try await vault.loadEntry(at: fileURL)
                        let all = try await vault.fetchAllEntries()
                        statusMessage = "✅ Saved to:\\n\\(fileURL.lastPathComponent)"
                        savedTitle = loaded.title
                        totalCount = all.count
                        } catch {
                            statusMessage = "❌ Error: \\(error.localizedDescription)"
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                VStack(alignment: .leading, spacing: 8) {
                    Text(statusMessage) .font(.caption) .foregroundStyle(.secondary)
                    if !savedTitle.isEmpty {
                        Text("Loaded Title: \\(savedTitle)")
                        .font(.headline)
                        Text("Total Vault Entries: \\(totalCount)")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .padding()
        }
    }
    return PreviewHarness()
}
