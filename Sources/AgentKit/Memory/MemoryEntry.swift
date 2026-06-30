// MemoryEntry.swift
// AgentKit
//
// SPDX-License-Identifier: MIT

import Foundation

/// A record stored within the Agent's memory manager.
///
/// `MemoryEntry` contains text content, categorization tags, and creation
/// timestamp to support storage and retrieval across different memory tiers.
public struct MemoryEntry: Codable, Sendable, Identifiable, Equatable {

    // MARK: - Properties

    /// The unique identifier of the memory record.
    public let id: String

    /// The textual content stored in this entry.
    public let content: String

    /// Semantic categorization tags (e.g., "user_preference", "summary").
    public let tags: [String]

    /// The timestamp when this memory entry was recorded.
    public let createdAt: Date

    // MARK: - Initialization

    /// Creates a new memory record.
    ///
    /// - Parameters:
    ///   - id: Unique identifier. Defaults to a new UUID.
    ///   - content: The textual content of the entry.
    ///   - tags: Categorization tags. Defaults to empty.
    ///   - createdAt: The timestamp of creation. Defaults to the current date.
    public init(
        id: String = UUID().uuidString,
        content: String,
        tags: [String] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.content = content
        self.tags = tags
        self.createdAt = createdAt
    }
}
