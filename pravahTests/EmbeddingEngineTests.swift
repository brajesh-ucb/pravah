import Testing
@testable import pravah

struct EmbeddingEngineTests {
    private let engine = EmbeddingEngine()

    @Test func emptyTextProducesNoEmbedding() async {
        #expect(await engine.generateEmbedding(for: " \n\t ") == nil)
    }

    @Test func sampleSentenceProduces512DimensionalVector() async throws {
        let vector = try #require(await engine.generateEmbedding(for: "A quiet sunrise by the lake"))
        #expect(vector.count == 512)
    }

    @Test func identicalVectorsHaveSimilarityOfOne() {
        let similarity = engine.computeCosineSimilarity(between: [1, 2, 3], and: [1, 2, 3])
        #expect(abs(similarity - 1.0) < 1e-9)
    }

    @Test func orthogonalVectorsHaveSimilarityOfZero() {
        #expect(engine.computeCosineSimilarity(between: [1, 0], and: [0, 1]) == 0.0)
    }

    @Test func mismatchedLengthsReturnZero() {
        #expect(engine.computeCosineSimilarity(between: [1, 2], and: [1, 2, 3]) == 0.0)
    }

    @Test func zeroMagnitudeReturnsZero() {
        #expect(engine.computeCosineSimilarity(between: [0, 0], and: [1, 2]) == 0.0)
    }

    @Test func relatedTextsScoreHigherThanUnrelatedTexts() async throws {
        let beach = try #require(await engine.generateEmbedding(for: "A walk on the sandy beach"))
        let ocean = try #require(await engine.generateEmbedding(for: "Waves crashing on the seashore"))
        let invoice = try #require(await engine.generateEmbedding(for: "Quarterly tax invoice payment"))

        let related = engine.computeCosineSimilarity(between: beach, and: ocean)
        let unrelated = engine.computeCosineSimilarity(between: beach, and: invoice)
        #expect(related > unrelated)
    }
}
