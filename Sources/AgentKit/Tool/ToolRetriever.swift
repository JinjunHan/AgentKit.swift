// ToolRetriever.swift
// AgentKit
//
// SPDX-License-Identifier: MIT

import Foundation

/// A protocol that defines how tools are dynamically retrieved or filtered before
/// being presented to the Large Language Model.
///
/// Implement this protocol to build custom tool routing logic, such as semantic
/// vector search (RAG for Tools), permissions checking, or rule-based filtering.
public protocol ToolRetriever: Sendable {
    
    /// Retrieves a filtered subset of tools that are most relevant to the user's input.
    ///
    /// - Parameters:
    ///   - input: The user's input text or prompt.
    ///   - availableTools: The full list of tools registered in the `ToolRegistry`.
    /// - Returns: An array of tools that the agent should consider for this run.
    func retrieveTools(for input: String, from availableTools: [any Tool]) async throws -> [any Tool]
}
