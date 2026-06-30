// MemoryStore.swift
// AgentKit
//
// SPDX-License-Identifier: MIT

import Foundation

/// A pluggable storage protocol for persisting and querying memory entries.
///
/// Implement this protocol to plug in SQLite, Vector database, or Keychain storage
/// options. The default implementation is ``InMemoryMemoryStore``.
public protocol MemoryStore: Sendable {

    /// Saves a memory entry to the store.
    ///
    /// - Parameter entry: The memory entry to save.
    /// - Throws: ``AgentKitError`` if storage fails.
    func save(_ entry: MemoryEntry) async throws(AgentKitError)

    /// Queries memory entries matching the tags and optional search query text.
    ///
    /// - Parameters:
    ///   - tags: Categorization tags to filter by. Nil or empty matches any tag.
    ///   - queryText: Substring text search. Nil or empty returns matches by tags only.
    ///   - limit: Maximum number of entries to return.
    /// - Returns: A list of matching memory entries.
    /// - Throws: ``AgentKitError`` if query execution fails.
    func query(
        tags: [String]?,
        queryText: String?,
        limit: Int
    ) async throws(AgentKitError) -> [MemoryEntry]

    /// Deletes a specific memory entry by identifier.
    ///
    /// - Parameter id: The unique entry identifier.
    /// - Throws: ``AgentKitError`` if deletion fails.
    func delete(id: String) async throws(AgentKitError)

    /// Clears all entries from this store.
    ///
    /// - Throws: ``AgentKitError`` if clearing fails.
    func clear() async throws(AgentKitError)
}
