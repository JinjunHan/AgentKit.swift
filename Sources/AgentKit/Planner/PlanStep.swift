// PlanStep.swift
// AgentKit
//
// SPDX-License-Identifier: MIT

import Foundation

/// Represents a single step within an execution ``Plan``.
///
/// Each step captures a goal description and tracks its execution status
/// through the planning lifecycle.
public struct PlanStep: Sendable, Identifiable, Codable {

    // MARK: - Status

    /// The execution status of a plan step.
    public enum Status: String, Sendable, Codable, CaseIterable {

        /// The step has not yet started.
        case pending

        /// The step is currently being executed.
        case running

        /// The step completed successfully.
        case completed

        /// The step failed to execute.
        case failed

        /// The step was skipped (e.g., due to re-planning).
        case skipped
    }

    // MARK: - Properties

    /// The unique identifier for this step.
    public let id: String

    /// A human-readable description of the step's objective.
    public let description: String

    /// The current execution status. Defaults to ``Status/pending``.
    public var status: Status

    /// An optional result or output produced by this step.
    public var result: String?

    /// An optional error message if the step failed.
    public var errorMessage: String?

    // MARK: - Initialization

    /// Creates a new plan step.
    ///
    /// - Parameters:
    ///   - id: Unique identifier. Defaults to a new UUID string.
    ///   - description: A description of the step's goal.
    ///   - status: Initial status. Defaults to `.pending`.
    public init(
        id: String = UUID().uuidString,
        description: String,
        status: Status = .pending
    ) {
        self.id = id
        self.description = description
        self.status = status
    }
}
