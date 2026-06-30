// Planner.swift
// AgentKit
//
// SPDX-License-Identifier: MIT

import Foundation

/// An actor that generates and executes multi-step plans using an ``Agent``.
///
/// The `Planner` decomposes a high-level user goal into a sequence of ``PlanStep``
/// values by asking the LLM to generate a structured plan. It then executes each step
/// through the agent, supporting re-planning on failure.
///
/// ## Usage
/// ```swift
/// let planner = Planner(agent: myAgent)
/// let events = await planner.execute(goal: "Research and summarize Swift concurrency")
/// for try await event in events {
///     switch event {
///     case .planGenerated(let plan):
///         print("Plan: \(plan.steps.map(\.description))")
///     case .stepCompleted(let step, let result):
///         print("✅ \(step.description): \(result)")
///     case .completed(let plan):
///         print("Done! \(plan.progressDescription)")
///     }
///     // ...
/// }
/// ```
public actor Planner {

    // MARK: - PlannerEvent

    /// Events emitted during plan generation and execution.
    public enum PlannerEvent: Sendable {
        /// A plan has been generated from the user goal.
        case planGenerated(Plan)

        /// A step is starting execution.
        case stepStarted(PlanStep)

        /// A step completed successfully with a result.
        case stepCompleted(PlanStep, result: String)

        /// A step failed with an error.
        case stepFailed(PlanStep, error: AgentKitError)

        /// The plan is being re-generated after a failure.
        case replanning(reason: String)

        /// All steps have been executed.
        case completed(Plan)

        /// The entire planning process failed.
        case failed(AgentKitError)
    }

    // MARK: - Properties

    private let agent: Agent
    private let maxReplanAttempts: Int

    // MARK: - Initialization

    /// Creates a new planner.
    ///
    /// - Parameters:
    ///   - agent: The agent used for both plan generation and step execution.
    ///   - maxReplanAttempts: Maximum number of re-plan attempts on failure. Defaults to `2`.
    public init(agent: Agent, maxReplanAttempts: Int = 2) {
        self.agent = agent
        self.maxReplanAttempts = maxReplanAttempts
    }

    // MARK: - Public API

    /// Generates and executes a plan for the given goal.
    ///
    /// - Parameter goal: The high-level user goal to decompose and execute.
    /// - Returns: An async throwing stream of ``PlannerEvent`` values.
    public func execute(goal: String) -> AsyncThrowingStream<PlannerEvent, any Error> {
        let agent = self.agent
        let maxReplanAttempts = self.maxReplanAttempts

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await Self.runPlanLoop(
                        goal: goal,
                        agent: agent,
                        maxReplanAttempts: maxReplanAttempts,
                        continuation: continuation
                    )
                } catch {
                    let wrapped = AgentKitError.providerError(error.localizedDescription)
                    continuation.yield(.failed(wrapped))
                    continuation.finish(throwing: wrapped)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    // MARK: - Plan Loop

    private static func runPlanLoop(
        goal: String,
        agent: Agent,
        maxReplanAttempts: Int,
        continuation: AsyncThrowingStream<PlannerEvent, any Error>.Continuation
    ) async throws {
        var plan = try await generatePlan(goal: goal, agent: agent)
        continuation.yield(.planGenerated(plan))

        var replanCount = 0

        for stepIndex in plan.steps.indices {
            try Task.checkCancellation()

            plan.steps[stepIndex].status = .running
            continuation.yield(.stepStarted(plan.steps[stepIndex]))

            let stepDescription = plan.steps[stepIndex].description
            let stepPrompt = """
            You are executing step \(stepIndex + 1) of \(plan.totalCount) in a plan.
            
            Overall goal: \(goal)
            Current step: \(stepDescription)
            
            Execute this step and provide a clear, concise result.
            """

            do {
                let result = try await executeStep(prompt: stepPrompt, agent: agent)
                plan.steps[stepIndex].status = .completed
                plan.steps[stepIndex].result = result
                continuation.yield(.stepCompleted(plan.steps[stepIndex], result: result))

            } catch let error as AgentKitError {
                plan.steps[stepIndex].status = .failed
                plan.steps[stepIndex].errorMessage = error.description
                continuation.yield(.stepFailed(plan.steps[stepIndex], error: error))

                // Attempt re-planning
                if replanCount < maxReplanAttempts {
                    replanCount += 1
                    let reason = "Step \(stepIndex + 1) failed: \(error.description)"
                    continuation.yield(.replanning(reason: reason))

                    // Mark remaining steps as skipped
                    for remainingIndex in (stepIndex + 1)..<plan.steps.count {
                        plan.steps[remainingIndex].status = .skipped
                    }

                    // Generate a new plan for the remaining work
                    let remainingGoal = """
                    The original goal was: \(goal)
                    
                    Steps completed so far:
                    \(plan.steps.filter { $0.status == .completed }.map { "- ✅ \($0.description)" }.joined(separator: "\n"))
                    
                    The following step failed: \(stepDescription)
                    Error: \(error.description)
                    
                    Please create a revised plan to complete the remaining work.
                    """

                    let revisedPlan = try await generatePlan(goal: remainingGoal, agent: agent)
                    continuation.yield(.planGenerated(revisedPlan))

                    // Continue with the revised plan
                    for revisedStepIndex in revisedPlan.steps.indices {
                        try Task.checkCancellation()

                        var revisedStep = revisedPlan.steps[revisedStepIndex]
                        revisedStep.status = .running
                        continuation.yield(.stepStarted(revisedStep))

                        let revisedPrompt = """
                        You are executing step \(revisedStepIndex + 1) of \(revisedPlan.totalCount) in a revised plan.
                        
                        Overall goal: \(goal)
                        Current step: \(revisedStep.description)
                        
                        Execute this step and provide a clear, concise result.
                        """

                        do {
                            let result = try await executeStep(prompt: revisedPrompt, agent: agent)
                            revisedStep.status = .completed
                            revisedStep.result = result
                            continuation.yield(.stepCompleted(revisedStep, result: result))
                        } catch let revisedError as AgentKitError {
                            revisedStep.status = .failed
                            revisedStep.errorMessage = revisedError.description
                            continuation.yield(.stepFailed(revisedStep, error: revisedError))
                        }
                    }
                    break
                }
            }
        }

        continuation.yield(.completed(plan))
        continuation.finish()
    }

    // MARK: - Plan Generation

    private static func generatePlan(
        goal: String,
        agent: Agent
    ) async throws -> Plan {
        let planPrompt = """
        Given the following goal, break it down into a sequence of concrete, actionable steps.
        
        Goal: \(goal)
        
        Respond ONLY with a JSON object in this exact format (no markdown fences):
        {"steps": ["step 1 description", "step 2 description", ...]}
        
        Keep each step concise (one sentence). Use 3-7 steps. Focus on actionable tasks.
        """

        let result = try await executeStep(prompt: planPrompt, agent: agent)

        // Parse the JSON response
        let steps = parsePlanSteps(from: result)

        guard !steps.isEmpty else {
            // Fallback: treat the entire goal as a single step
            return Plan(
                goal: goal,
                steps: [PlanStep(description: goal)]
            )
        }

        return Plan(
            goal: goal,
            steps: steps.map { PlanStep(description: $0) }
        )
    }

    // MARK: - Step Execution

    private static func executeStep(
        prompt: String,
        agent: Agent
    ) async throws -> String {
        var accumulated = ""
        let events = await agent.run(prompt)

        for try await event in events {
            switch event {
            case .streamDelta(let delta):
                accumulated += delta
            case .messageCompleted(let message):
                if let content = message.content {
                    // Prefer the final completed message over accumulated deltas
                    accumulated = content
                }
            case .error(let error):
                throw error
            default:
                break
            }
        }

        return accumulated
    }

    // MARK: - JSON Parsing

    private static func parsePlanSteps(from text: String) -> [String] {
        // Try to find JSON in the response
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Try direct JSON parsing
        if let data = trimmed.data(using: .utf8),
           let json = try? JSONDecoder().decode(PlanJSON.self, from: data) {
            return json.steps
        }

        // Try extracting JSON from markdown fences
        let pattern = /\{[\s\S]*?"steps"\s*:\s*\[[\s\S]*?\]\s*\}/
        if let match = trimmed.firstMatch(of: pattern) {
            let jsonString = String(match.output)
            if let data = jsonString.data(using: .utf8),
               let json = try? JSONDecoder().decode(PlanJSON.self, from: data) {
                return json.steps
            }
        }

        return []
    }
}

// MARK: - Internal Models

private struct PlanJSON: Decodable {
    let steps: [String]
}
