// LoggerPlugin.swift
// AgentKit
//
// SPDX-License-Identifier: MIT

import Foundation

/// A default implementation of ``AgentPlugin`` that prints formatted logs
/// of the agent's lifecycle and events to the standard output.
public struct LoggerPlugin: AgentPlugin {

    // MARK: - Properties

    public let id: String
    public let name: String
    private let prefix: String

    // MARK: - Initialization

    /// Creates a new logging plugin.
    ///
    /// - Parameters:
    ///   - id: Unique identifier. Defaults to a new UUID string.
    ///   - prefix: Prefix to prepend to every log statement. Defaults to `[AgentKit]`.
    public init(id: String = UUID().uuidString, prefix: String = "[AgentKit]") {
        self.id = id
        self.name = "LoggerPlugin"
        self.prefix = prefix
    }

    // MARK: - AgentPlugin Conformance

    public func onEvent(_ event: AgentEvent, sessionID: String) async {
        let timestamp = DateFormatter.localizedString(
            from: Date(),
            dateStyle: .none,
            timeStyle: .medium
        )
        let logHeader = "\(prefix) [\(timestamp)] [Session: \(sessionID)]"

        switch event {
        case .started:
            print("\(logHeader) 🚀 Agent run started.")
        case .streamReasoningDelta(let text):
            // Optionally log reasoning deltas, but it can be very verbose
            break
        case .streamDelta(let text):
            // We usually don't print stream deltas in logger to avoid cluttering stdio,
            // but can log text size or skip. We'll log as debug:
            break
        case .toolCallStarted(let toolCall):
            print("\(logHeader) 🔧 Tool call started: '\(toolCall.function.name)' with arguments: \(toolCall.function.arguments)")
        case .toolCallCompleted(let toolCall, let result):
            print("\(logHeader) ✅ Tool call completed: '\(toolCall.function.name)'. Result length: \(result.count) chars.")
        case .messageCompleted(let message):
            let charCount = message.content?.count ?? 0
            print("\(logHeader) 💬 Message completed (role: \(message.role.rawValue)). Content length: \(charCount) chars.")
        case .error(let error):
            print("\(logHeader) ❌ Error occurred: \(error)")
        case .completed:
            print("\(logHeader) 🏁 Agent run finished successfully.")
        }
    }
}
