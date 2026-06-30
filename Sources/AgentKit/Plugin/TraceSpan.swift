// TraceSpan.swift
// AgentKit
//
// SPDX-License-Identifier: MIT

import Foundation

/// Represents a single timed unit of work during the Agent's execution loop.
///
/// `TraceSpan` records latency, metadata, and cost metrics for specific tasks
/// such as LLM chat requests or Tool calls.
public struct TraceSpan: Codable, Sendable, Identifiable {

    // MARK: - Properties

    /// The unique identifier of this trace span.
    public let id: String

    /// The name of the operation (e.g. "LLM Chat Request", "Tool Call: get_weather").
    public let name: String

    /// The timestamp when the operation started.
    public let startTime: Date

    /// The timestamp when the operation ended.
    public var endTime: Date?

    /// Arbitrary diagnostics metadata (e.g., token usage, model names).
    public var metadata: [String: String]

    /// Calculates the duration of the span. Returns elapsed time up to now if not ended.
    public var duration: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime)
    }

    // MARK: - Initialization

    /// Creates a new trace span record.
    ///
    /// - Parameters:
    ///   - id: Unique identifier. Defaults to a new UUID.
    ///   - name: Name of the traced operation.
    ///   - startTime: The time the span started. Defaults to the current date.
    ///   - metadata: Key-value diagnostics metadata. Defaults to empty.
    public init(
        id: String = UUID().uuidString,
        name: String,
        startTime: Date = Date(),
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.name = name
        self.startTime = startTime
        self.metadata = metadata
    }
}
