// TracingPlugin.swift
// AgentKit
//
// SPDX-License-Identifier: MIT

import Foundation

/// An actor-isolated implementation of ``AgentPlugin`` that records execution traces,
/// measures operation durations, and generates performance metrics.
public actor TracingPlugin: AgentPlugin {

    // MARK: - Properties

    public let id: String
    public let name: String

    private var activeSpans: [String: TraceSpan] = [:]
    private var completedSpans: [TraceSpan] = []

    private var currentLLMSpanID: String?
    private var runSpanID: String?

    // MARK: - Initialization

    /// Creates a new tracing plugin.
    ///
    /// - Parameter id: Unique identifier. Defaults to a new UUID string.
    public init(id: String = UUID().uuidString) {
        self.id = id
        self.name = "TracingPlugin"
    }

    // MARK: - Public API

    /// Returns the collection of all recorded trace spans.
    public func getSpans() -> [TraceSpan] {
        completedSpans
    }

    /// Clears all recorded spans.
    public func clear() {
        activeSpans.removeAll()
        completedSpans.removeAll()
        currentLLMSpanID = nil
        runSpanID = nil
    }

    /// Prints a tree-like performance report of the completed run.
    public func printReport() {
        print("\n📈 AgentKit Observability Trace Report")
        print("==================================================")
        
        let runSpans = completedSpans.filter { $0.id == runSpanID }
        let totalDuration = runSpans.first?.duration ?? 0.0
        
        print("Session ID: \(id)")
        print("Total Run Duration: \(String(format: "%.2f", totalDuration))s")
        print("--------------------------------------------------")

        // Print individual spans sorted by start time
        let sortedSpans = completedSpans
            .filter { $0.id != runSpanID }
            .sorted(by: { $0.startTime < $1.startTime })

        for span in sortedSpans {
            let durationString = String(format: "%.2f", span.duration)
            print("├── \(span.name): \(durationString)s")
            for (key, val) in span.metadata.sorted(by: { $0.key < $1.key }) {
                print("│    └── \(key): \(val)")
            }
        }
        print("==================================================")
    }

    // MARK: - AgentPlugin Conformance

    public func onEvent(_ event: AgentEvent, sessionID: String) async {
        switch event {
        case .started:
            clear()
            let rSpan = TraceSpan(name: "Total Agent Run")
            runSpanID = rSpan.id
            activeSpans[rSpan.id] = rSpan
            
            // Start the first LLM generation span
            startLLMSpan()

        case .streamReasoningDelta:
            // Reasoning deltas aren't specifically timed per chunk in the trace tree,
            // but we could track reasoning vs output time in the future.
            break
        case .streamDelta(_):
            // If this is the first token, we can record Time To First Token (TTFT) metadata
            if let llmID = currentLLMSpanID, var span = activeSpans[llmID] {
                if span.metadata["ttft"] == nil {
                    let ttft = Date().timeIntervalSince(span.startTime)
                    span.metadata["ttft"] = String(format: "%.2fms", ttft * 1000)
                    activeSpans[llmID] = span
                }
            }

        case .toolCallStarted(let toolCall):
            // End the active LLM span before executing the tool
            endLLMSpan()

            let tSpan = TraceSpan(name: "Tool Call: \(toolCall.function.name)")
            activeSpans["tool:\(toolCall.id)"] = tSpan

        case .toolCallCompleted(let toolCall, let result):
            if var tSpan = activeSpans.removeValue(forKey: "tool:\(toolCall.id)") {
                tSpan.endTime = Date()
                tSpan.metadata["result_length"] = "\(result.count) chars"
                completedSpans.append(tSpan)
            }
            
            // Start the next LLM generation span after tool completion
            startLLMSpan()

        case .messageCompleted(let message):
            // End the active LLM span when the message completes
            endLLMSpan(metadata: [
                "role": message.role.rawValue,
                "has_content": String(message.content != nil),
                "tool_calls_count": "\(message.toolCalls.count)"
            ])

        case .error(let error):
            endLLMSpan()
            if let runID = runSpanID, var rSpan = activeSpans.removeValue(forKey: runID) {
                rSpan.endTime = Date()
                rSpan.metadata["error"] = error.description
                completedSpans.append(rSpan)
            }

        case .completed:
            endLLMSpan()
            if let runID = runSpanID, var rSpan = activeSpans.removeValue(forKey: runID) {
                rSpan.endTime = Date()
                rSpan.metadata["status"] = "success"
                completedSpans.append(rSpan)
            }
        }
    }

    // MARK: - Private Helpers

    private func startLLMSpan() {
        let span = TraceSpan(name: "LLM Chat Request")
        currentLLMSpanID = span.id
        activeSpans[span.id] = span
    }

    private func endLLMSpan(metadata: [String: String] = [:]) {
        guard let llmID = currentLLMSpanID, var span = activeSpans.removeValue(forKey: llmID) else {
            return
        }
        span.endTime = Date()
        for (k, v) in metadata {
            span.metadata[k] = v
        }
        completedSpans.append(span)
        currentLLMSpanID = nil
    }
}
