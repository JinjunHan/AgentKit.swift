// WorkflowStep.swift
// AgentKit
//
// SPDX-License-Identifier: MIT

import Foundation

/// A protocol defining a single executable step in a workflow pipeline.
///
/// Steps are designed to be composable. They process a standard input type-erased
/// JSON value and return a JSON result, throwing an error if execution fails.
public protocol WorkflowStep: Sendable {

    /// The unique name of this step.
    var name: String { get }

    /// Executes the step's logic.
    ///
    /// - Parameter input: The input data represented as ``JSONValue``.
    /// - Returns: The step's output data as ``JSONValue``.
    /// - Throws: Any error during execution.
    func execute(input: JSONValue) async throws -> JSONValue
}
