// SemanticToolRetriever.swift
// AgentKit
//
// SPDX-License-Identifier: MIT

import Foundation
@preconcurrency import NaturalLanguage

/// A semantic tool retriever that uses Apple's native `NaturalLanguage` framework
/// to retrieve tools based on vector embedding cosine similarity.
///
/// This implements the "RAG for Tools" pattern natively on-device,
/// ensuring that only the most relevant tools are passed to the LLM.
/// This drastically reduces context token consumption and improves precision
/// when managing large numbers of tools or skills.
public actor SemanticToolRetriever: ToolRetriever {

    // MARK: - Properties

    /// The maximum number of tools to return.
    public let maxTools: Int
    
    /// The minimum similarity distance threshold.
    /// Note: `NLEmbedding.distance` returns a value where 0.0 means identical,
    /// and 2.0 means completely dissimilar.
    /// For threshold filtering, lower distances are more similar.
    public let distanceThreshold: Double
    
    /// The underlying embedding model.
    private let embedding: NLEmbedding?
    
    // Cache to avoid re-embedding tool descriptions
    private var toolDescriptionEmbeddings: [String: [Double]] = [:]

    // MARK: - Initialization

    /// Creates a semantic tool retriever.
    ///
    /// - Parameters:
    ///   - maxTools: The maximum number of relevant tools to return (default: 5).
    ///   - distanceThreshold: The maximum allowable distance (0.0 to 2.0). 
    ///     Tools with a distance higher than this will be ignored. Default is `1.2`.
    ///   - language: The language for the sentence embedding. Default is `.english`.
    public init(maxTools: Int = 5, distanceThreshold: Double = 1.2, language: NLLanguage = .english) {
        self.maxTools = maxTools
        self.distanceThreshold = distanceThreshold
        // Use sentence embedding for comparing full descriptions
        self.embedding = NLEmbedding.sentenceEmbedding(for: language)
    }

    // MARK: - ToolRetriever

    public func retrieveTools(for input: String, from availableTools: [any Tool]) async throws -> [any Tool] {
        guard let embedding = embedding, !availableTools.isEmpty else {
            // Fallback: If embedding model isn't available on this platform/language,
            // or there are no tools, return everything up to maxTools.
            return Array(availableTools.prefix(maxTools))
        }

        // 1. Embed the user input
        guard let inputVector = embedding.vector(for: input) else {
            return Array(availableTools.prefix(maxTools))
        }

        // 2. Score each tool
        var scoredTools: [(tool: any Tool, distance: Double)] = []
        
        for tool in availableTools {
            // Include both name and description in the semantic representation
            let toolText = "\(tool.name): \(tool.description)"
            
            // Look up cache or compute vector
            let toolVector: [Double]
            if let cached = toolDescriptionEmbeddings[tool.name] {
                toolVector = cached
            } else if let computed = embedding.vector(for: toolText) {
                toolVector = computed
                toolDescriptionEmbeddings[tool.name] = computed
            } else {
                continue
            }
            
            // Compute cosine distance
            let dist = cosineDistance(vectorA: inputVector, vectorB: toolVector)
            
            // Filter by threshold
            if dist <= distanceThreshold {
                scoredTools.append((tool, dist))
            }
        }
        
        // 3. Sort by distance (lowest is best match) and take Top K
        let topK = scoredTools
            .sorted { $0.distance < $1.distance }
            .prefix(maxTools)
            .map { $0.tool }

        // If no tools met the strict threshold but the user input *is* short or ambiguous,
        // we might return an empty list. The LLM will just chat normally.
        return topK
    }
    
    // MARK: - Math Helpers
    
    /// Computes the cosine distance between two vectors.
    /// Range is [0.0, 2.0] where 0.0 is identical and 2.0 is opposite.
    private func cosineDistance(vectorA: [Double], vectorB: [Double]) -> Double {
        guard vectorA.count == vectorB.count, !vectorA.isEmpty else { return 2.0 }
        
        var dotProduct: Double = 0
        var normA: Double = 0
        var normB: Double = 0
        
        for i in 0..<vectorA.count {
            dotProduct += vectorA[i] * vectorB[i]
            normA += vectorA[i] * vectorA[i]
            normB += vectorB[i] * vectorB[i]
        }
        
        guard normA > 0, normB > 0 else { return 2.0 }
        
        let similarity = dotProduct / (sqrt(normA) * sqrt(normB))
        return 1.0 - similarity // Convert similarity [-1.0, 1.0] to distance [0.0, 2.0]
    }
}
