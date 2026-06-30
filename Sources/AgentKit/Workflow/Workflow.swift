// Workflow.swift
// AgentKit
//
// SPDX-License-Identifier: MIT

import Foundation

/// A pipeline of sequential steps executed in order, supporting retries
/// and task cancellation.
///
/// Use `Workflow` to run structured chains of tasks where the output of
/// one step serves as the input to the next step.
public struct Workflow: Sendable {

    // MARK: - Types

    /// Policy determining step retry behavior upon failure.
    public struct RetryPolicy: Sendable {
        /// Maximum number of execution attempts. Defaults to `3`.
        public let maxAttempts: Int

        /// Sleep delay duration (in seconds) between attempts. Defaults to `1.0`.
        public let delaySeconds: Double

        /// Creates a retry policy.
        public init(maxAttempts: Int = 3, delaySeconds: Double = 1.0) {
            self.maxAttempts = maxAttempts
            self.delaySeconds = delaySeconds
        }
    }

    // MARK: - Properties

    /// The human-readable name of the workflow.
    public let name: String

    /// The ordered list of steps to execute.
    public let steps: [any WorkflowStep]

    /// The retry policy applied to step execution.
    public let retryPolicy: RetryPolicy

    // MARK: - Initialization

    /// Creates a new workflow pipeline.
    ///
    /// - Parameters:
    ///   - name: Name of the workflow.
    ///   - steps: Step pipeline.
    ///   - retryPolicy: Retry configuration. Defaults to a standard policy.
    public init(
        name: String,
        steps: [any WorkflowStep],
        retryPolicy: RetryPolicy = RetryPolicy()
    ) {
        self.name = name
        self.steps = steps
        self.retryPolicy = retryPolicy
    }

    // MARK: - Execution

    /// Runs the workflow sequentially from the initial input.
    ///
    /// - Parameter initialInput: Input passed to the first step.
    /// - Returns: The final output produced by the last step.
    /// - Throws: Any unrecoverable step error.
    public func run(initialInput: JSONValue) async throws -> JSONValue {
        var currentInput = initialInput

        for step in steps {
            try Task.checkCancellation()
            currentInput = try await executeWithRetry(step, input: currentInput)
        }

        return currentInput
    }

    // MARK: - Private Helpers

    private func executeWithRetry(
        _ step: any WorkflowStep,
        input: JSONValue
    ) async throws -> JSONValue {
        var lastError: (any Error)?

        for attempt in 1...retryPolicy.maxAttempts {
            try Task.checkCancellation()
            do {
                return try await step.execute(input: input)
            } catch {
                lastError = error
                if attempt < retryPolicy.maxAttempts {
                    let delayNano = UInt64(retryPolicy.delaySeconds * 1_000_000_000)
                    try await Task.sleep(nanoseconds: delayNano)
                }
            }
        }

        if let lastError {
            throw lastError
        }

        throw AgentKitError.toolExecutionFailed(
            toolName: step.name,
            reason: "Workflow step failed without returning an error"
        )
    }
}
