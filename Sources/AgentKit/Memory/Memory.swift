// Memory.swift
// AgentKit
//
// SPDX-License-Identifier: MIT

import Foundation

/// Coordinates multi-layered agent memory (Working, Session, User, Semantic).
///
/// `Memory` provides simplified accessors to store and retrieve agent contexts
/// from various memory scopes. It interfaces with an underlying ``MemoryStore``.
public actor Memory {

    // MARK: - Properties

    private let store: any MemoryStore
    private let sessionID: String
    private var workingMemory: [String: String] = [:]

    // MARK: - Initialization

    /// Creates a new memory coordinator.
    ///
    /// - Parameters:
    ///   - sessionID: The identifier of the active session.
    ///   - store: The pluggable memory store.
    public init(sessionID: String, store: any MemoryStore) {
        self.sessionID = sessionID
        self.store = store
    }

    // MARK: - Working Memory (Ephemeral Key-Value)

    /// Saves a key-value pair in ephemeral working memory.
    public func setWorkingMemory(key: String, value: String) {
        workingMemory[key] = value
    }

    /// Retrieves a value from ephemeral working memory.
    public func getWorkingMemory(key: String) -> String? {
        workingMemory[key]
    }

    /// Clears ephemeral working memory.
    public func clearWorkingMemory() {
        workingMemory.removeAll()
    }

    // MARK: - Session Memory

    /// Saves a session-specific memory entry.
    public func saveSessionMemory(_ content: String) async throws(AgentKitError) {
        let entry = MemoryEntry(
            content: content,
            tags: ["session:\(sessionID)", "session"]
        )
        try await store.save(entry)
    }

    /// Retrieves recent session-specific memory entries.
    public func getSessionMemory(limit: Int = 10) async throws(AgentKitError) -> [MemoryEntry] {
        try await store.query(
            tags: ["session:\(sessionID)"],
            queryText: nil,
            limit: limit
        )
    }

    // MARK: - User Memory

    /// Saves a user preference or fact to user memory.
    public func saveUserMemory(_ content: String) async throws(AgentKitError) {
        let entry = MemoryEntry(
            content: content,
            tags: ["user"]
        )
        try await store.save(entry)
    }

    /// Retrieves user memory entries.
    public func getUserMemory(limit: Int = 10) async throws(AgentKitError) -> [MemoryEntry] {
        try await store.query(tags: ["user"], queryText: nil, limit: limit)
    }

    // MARK: - Semantic Memory / Query

    /// Searches memory entries matching a search query.
    public func searchMemory(
        query: String,
        limit: Int = 5
    ) async throws(AgentKitError) -> [MemoryEntry] {
        try await store.query(tags: nil, queryText: query, limit: limit)
    }
}
