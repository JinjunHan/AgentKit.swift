// SQLiteMemoryStore.swift
// AgentKit
//
// SPDX-License-Identifier: MIT

import Foundation
import SQLite3

/// A Sendable wrapper around SQLite database pointer.
struct SQLiteConnection: @unchecked Sendable {
    let pointer: OpaquePointer
}

/// A persistent database-backed implementation of ``MemoryStore`` using SQLite.
///
/// `SQLiteMemoryStore` stores agent memories in a local SQLite file, enabling
/// long-term retention of session logs and user facts across application launches.
public actor SQLiteMemoryStore: MemoryStore {

    // MARK: - Properties

    private let db: SQLiteConnection?
    private let dbPath: String

    // MARK: - Initialization

    /// Creates a new SQLite memory store.
    ///
    /// - Parameter dbPath: The file system path to the SQLite file.
    /// - Throws: ``AgentKitError`` if the database cannot be opened or initialized.
    public init(dbPath: String = "agent_memory.db") throws(AgentKitError) {
        self.dbPath = dbPath

        var dbPointer: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        let status = sqlite3_open_v2(dbPath, &dbPointer, flags, nil)
        
        guard status == SQLITE_OK, let dbPointer else {
            throw .invalidConfiguration("Failed to open SQLite database at \(dbPath), status: \(status)")
        }
        self.db = SQLiteConnection(pointer: dbPointer)

        // Create memory table
        let createTableSQL = """
        CREATE TABLE IF NOT EXISTS agent_memory (
            id TEXT PRIMARY KEY,
            content TEXT,
            tags TEXT,
            created_at REAL
        );
        """
        
        var errorMsg: UnsafeMutablePointer<Int8>?
        let execStatus = sqlite3_exec(dbPointer, createTableSQL, nil, nil, &errorMsg)
        
        if execStatus != SQLITE_OK {
            let msg = errorMsg.map { String(cString: $0) } ?? "Unknown error"
            sqlite3_free(errorMsg)
            throw .invalidConfiguration("Failed to initialize SQLite schema: \(msg)")
        }
    }

    deinit {
        if let db {
            sqlite3_close_v2(db.pointer)
        }
    }

    // MARK: - MemoryStore Conformance

    public func save(_ entry: MemoryEntry) async throws(AgentKitError) {
        let sql = "INSERT OR REPLACE INTO agent_memory (id, content, tags, created_at) VALUES (?, ?, ?, ?);"
        var stmt: OpaquePointer?

        guard sqlite3_prepare_v2(db?.pointer, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw .networkError("Failed to prepare SQLite statement: \(getErrorMessage())")
        }
        defer { sqlite3_finalize(stmt) }

        // Format tags as a comma-separated wrapper: ,tag1,tag2, for simpler LIKE querying
        let tagString = entry.tags.isEmpty ? "" : "," + entry.tags.joined(separator: ",") + ","

        sqlite3_bind_text(stmt, 1, (entry.id as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 2, (entry.content as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 3, (tagString as NSString).utf8String, -1, nil)
        sqlite3_bind_double(stmt, 4, entry.createdAt.timeIntervalSince1970)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw .networkError("Failed to insert/replace SQLite memory: \(getErrorMessage())")
        }
    }

    public func query(
        tags: [String]?,
        queryText: String?,
        limit: Int
    ) async throws(AgentKitError) -> [MemoryEntry] {
        var sql = "SELECT id, content, tags, created_at FROM agent_memory"
        var conditions: [String] = []

        if let tags, !tags.isEmpty {
            let tagConditions = tags.map { "tags LIKE '%,\($0),%'" }
            conditions.append("(" + tagConditions.joined(separator: " OR ") + ")")
        }

        if let queryText, !queryText.isEmpty {
            conditions.append("content LIKE '%" + queryText.replacingOccurrences(of: "'", with: "''") + "%'")
        }

        if !conditions.isEmpty {
            sql += " WHERE " + conditions.joined(separator: " AND ")
        }

        sql += " ORDER BY created_at DESC LIMIT ?;"

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db?.pointer, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw .networkError("Failed to prepare query statement: \(getErrorMessage())")
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_int(stmt, 1, Int32(limit))

        var results: [MemoryEntry] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = String(cString: sqlite3_column_text(stmt, 0))
            let content = String(cString: sqlite3_column_text(stmt, 1))
            let rawTags = String(cString: sqlite3_column_text(stmt, 2))
            let timeInterval = sqlite3_column_double(stmt, 3)

            // De-serialize tags wrapper (,tag1,tag2, -> [tag1, tag2])
            let parsedTags = rawTags
                .split(separator: ",")
                .map { String($0) }
                .filter { !$0.isEmpty }

            results.append(
                MemoryEntry(
                    id: id,
                    content: content,
                    tags: parsedTags,
                    createdAt: Date(timeIntervalSince1970: timeInterval)
                )
            )
        }

        return results
    }

    public func delete(id: String) async throws(AgentKitError) {
        let sql = "DELETE FROM agent_memory WHERE id = ?;"
        var stmt: OpaquePointer?

        guard sqlite3_prepare_v2(db?.pointer, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw .networkError("Failed to prepare delete statement: \(getErrorMessage())")
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, (id as NSString).utf8String, -1, nil)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw .networkError("Failed to delete memory: \(getErrorMessage())")
        }
    }

    public func clear() async throws(AgentKitError) {
        let sql = "DELETE FROM agent_memory;"
        var errorMsg: UnsafeMutablePointer<Int8>?

        guard sqlite3_exec(db?.pointer, sql, nil, nil, &errorMsg) == SQLITE_OK else {
            let msg = errorMsg.map { String(cString: $0) } ?? "Unknown error"
            sqlite3_free(errorMsg)
            throw .networkError("Failed to clear database: \(msg)")
        }
    }

    // MARK: - Private Helpers

    private func getErrorMessage() -> String {
        guard let dbPointer = db?.pointer else { return "No database reference" }
        return String(cString: sqlite3_errmsg(dbPointer))
    }
}
