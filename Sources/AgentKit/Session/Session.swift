// Session.swift
// AgentKit
//
// SPDX-License-Identifier: MIT

import Foundation

/// An actor that manages the state for a single agent run lifecycle.
///
/// `Session` tracks the conversation history, running state, and current
/// task reference. It ensures thread-safe access to mutable state during
/// an agent's execution loop.
///
/// ## Usage
/// ```swift
/// let session = Session(systemPrompt: "You are a helpful assistant.")
/// await session.appendMessage(.user("Hello!"))
/// ```
public actor Session {

    // MARK: - Properties

    /// A unique identifier for this session.
    public let id: String

    /// The conversation history accumulated during this session.
    public private(set) var conversation: Conversation

    /// Whether the agent is currently running within this session.
    public private(set) var isRunning: Bool

    /// The memory coordinator for this session.
    public let memory: Memory

    /// The current task reference, used for cancellation support.
    private var currentTask: Task<Void, Never>?

    // MARK: - Initialization

    /// Creates a new session.
    ///
    /// - Parameters:
    ///   - id: A unique identifier for the session. Defaults to a new UUID.
    ///   - systemPrompt: An optional system prompt to prepend to the conversation.
    ///   - memoryStore: The store to back the session's memory. Defaults to a new ``InMemoryMemoryStore``.
    public init(
        id: String = UUID().uuidString,
        systemPrompt: String? = nil,
        memoryStore: any MemoryStore = InMemoryMemoryStore()
    ) {
        self.id = id
        self.isRunning = false
        self.memory = Memory(sessionID: id, store: memoryStore)
        if let systemPrompt {
            self.conversation = Conversation(messages: [.system(systemPrompt)])
        } else {
            self.conversation = Conversation()
        }
    }

    // MARK: - Conversation Management

    /// Appends a message to the session's conversation history.
    ///
    /// - Parameter message: The message to append.
    public func appendMessage(_ message: Message) {
        conversation.append(message)
    }

    // MARK: - Lifecycle Management

    /// Marks the session as actively running.
    public func markRunning() {
        isRunning = true
    }

    /// Marks the session as completed and clears the current task reference.
    public func markCompleted() {
        isRunning = false
        currentTask = nil
    }

    /// Stores a reference to the current running task for cancellation support.
    ///
    /// - Parameter task: The task to track.
    public func setTask(_ task: Task<Void, Never>) {
        currentTask = task
    }

    /// Cancels the currently running task, if any, and clears the reference.
    public func cancelCurrentTask() {
        currentTask?.cancel()
        currentTask = nil
    }
}
