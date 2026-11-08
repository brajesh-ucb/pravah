import Foundation
import NaturalLanguage

actor EmbeddingEngine {
    private lazy var embeddingModel = NLEmbedding.sentenceEmbedding(for: .english)

    func generateEmbedding(for text: String) async -> [Double]? {
        let cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedText.isEmpty else { return nil }
        return embeddingModel?.vector(for: cleanedText)
    }

    nonisolated func computeCosineSimilarity(between vectorA: [Double], and vectorB: [Double]) -> Double {
        guard vectorA.count == vectorB.count else { return 0.0 }

        var dotProduct = 0.0
        var squaredMagnitudeA = 0.0
        var squaredMagnitudeB = 0.0
        for (valueA, valueB) in zip(vectorA, vectorB) {
            dotProduct += valueA * valueB
            squaredMagnitudeA += valueA * valueA
            squaredMagnitudeB += valueB * valueB
        }

        let magnitudeProduct = squaredMagnitudeA.squareRoot() * squaredMagnitudeB.squareRoot()
        guard magnitudeProduct > 0 else { return 0.0 }
        return dotProduct / magnitudeProduct
    }
}
