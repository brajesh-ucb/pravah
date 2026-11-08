import Foundation

actor VectorStoreActor {
    private var vectorIndex: [UUID: [Double]] = [:]
    private let storageURL: URL

    init(storageURL: URL? = nil) {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.storageURL = storageURL ?? documentsURL
            .appending(path: "Vault", directoryHint: .isDirectory)
            .appending(path: ".vectors.json", directoryHint: .notDirectory)
    }

    func setVector(_ vector: [Double], for entryID: UUID) {
        vectorIndex[entryID] = vector
        writeIndexToDisk()
    }

    func removeVector(for entryID: UUID) {
        guard vectorIndex.removeValue(forKey: entryID) != nil else { return }
        writeIndexToDisk()
    }

    func search(
        queryVector: [Double],
        topK: Int = 10,
        threshold: Double = 0.4,
        engine: EmbeddingEngine = EmbeddingEngine()
    ) -> [(entryID: UUID, score: Double)] {
        vectorIndex
            .map { (entryID: $0.key, score: engine.computeCosineSimilarity(between: queryVector, and: $0.value)) }
            .filter { $0.score >= threshold }
            .sorted { $0.score > $1.score }
            .prefix(max(topK, 0))
            .map { $0 }
    }

    func loadPersistedVectors() async {
        guard let data = try? Data(contentsOf: storageURL),
              let storedVectors = try? JSONDecoder().decode([String: [Double]].self, from: data) else { return }

        vectorIndex = storedVectors.reduce(into: [:]) { index, pair in
            guard let entryID = UUID(uuidString: pair.key) else { return }
            index[entryID] = pair.value
        }
    }

    func saveIndexToDisk() async {
        writeIndexToDisk()
    }
}

private extension VectorStoreActor {
    func writeIndexToDisk() {
        let storedVectors = Dictionary(uniqueKeysWithValues: vectorIndex.map { ($0.key.uuidString, $0.value) })
        guard let data = try? JSONEncoder().encode(storedVectors) else { return }

        try? FileManager.default.createDirectory(
            at: storageURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: storageURL, options: .atomic)
    }
}
