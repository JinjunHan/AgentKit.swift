// InMemoryMemoryStore.swift
// AgentKit
//
// SPDX-License-Identifier: MIT

import Foundation

/// A simple, thread-safe, in-memory implementation of ``MemoryStore``.
///
/// This store does not persist data across application launches. It is suitable
/// for ephemeral session storage and testing purposes.
public actor InMemoryMemoryStore: MemoryStore {

    // MARK: - Properties

    private var entries: [MemoryEntry] = []

    // MARK: - Initialization

    /// Creates a new in-memory store.
    public init() {}

    // MARK: - MemoryStore Conformance

    /// Saves a memory entry. Overwrites an entry if the ID already exists.
    public func save(_ entry: MemoryEntry) async throws(AgentKitError) {
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index] = entry
        } else {
            entries.append(entry)
        }
    }

    /// Queries memory entries matching the tags and/or query text.
    public func query(
        tags: [String]?,
        queryText: String?,
        limit: Int
    ) async throws(AgentKitError) -> [MemoryEntry] {
        var filtered = entries

        // Filter by tags if specified
        if let tags, !tags.isEmpty {
            let filterTags = Set(tags)
            filtered = filtered.filter { entry in
                !filterTags.isDisjoint(with: Set(entry.tags))
            }
        }

        // Filter by query text if specified
        if let queryText, !queryText.isEmpty {
            let lowerQuery = queryText.lowercased()
            filtered = filtered.filter { entry in
                entry.content.lowercased().contains(lowerQuery)
            }
        }

        // Sort by date descending and apply limit
        let sorted = filtered.sorted(by: { $0.createdAt > $1.createdAt })
        return Array(sorted.prefix(limit))
    }

    /// Deletes a specific memory entry.
    public func delete(id: String) async throws(AgentKitError) {
        entries.removeAll { $0.id == id }
    }

    /// Clears all memory entries.
    public func clear() async throws(AgentKitError) {
        entries.removeAll()
    }
}
