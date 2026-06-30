// AgentConfiguration.swift
// AgentKit
//
// SPDX-License-Identifier: MIT

/// Configuration options for an ``Agent``.
///
/// Controls the agent's behavior including its system prompt,
/// maximum tool-call loop iterations, and streaming preference.
///
/// ## Usage
/// ```swift
/// let config = AgentConfiguration(
///     systemPrompt: "You are a helpful assistant.",
///     maxIterations: 5,
///     streamingEnabled: true
/// )
/// ```
public struct AgentConfiguration: Sendable {

    /// An optional system prompt prepended to the conversation.
    ///
    /// This message sets the assistant's behavior and persona.
    public let systemPrompt: String?

    /// The maximum number of tool-call loop iterations before the agent
    /// stops and yields a ``AgentKitError/maxIterationsReached(_:)`` error.
    ///
    /// Defaults to `10`.
    public let maxIterations: Int

    /// Whether streaming responses are enabled.
    ///
    /// When `true`, the agent uses `streamChat` and yields
    /// ``AgentEvent/streamDelta(_:)`` events incrementally.
    /// When `false`, it uses `sendChat` for complete responses.
    ///
    /// Defaults to `true`.
    public let streamingEnabled: Bool

    /// The list of custom skills configured for this agent.
    public let skills: [Skill]

    /// The memory store backing the session's memory manager.
    public let memoryStore: any MemoryStore

    /// The list of custom plugins configured for this agent.
    public let plugins: [any AgentPlugin]
    
    /// The tool retriever used to dynamically select relevant tools per iteration.
    public let toolRetriever: (any ToolRetriever)?

    /// Creates a new agent configuration.
    ///
    /// - Parameters:
    ///   - systemPrompt: An optional system prompt for the conversation. Defaults to `nil`.
    ///   - maxIterations: Maximum tool-call loop iterations. Defaults to `10`.
    ///   - streamingEnabled: Whether to stream responses. Defaults to `true`.
    ///   - skills: Custom skills to enable on the agent. Defaults to empty.
    ///   - memoryStore: The storage backend for memory. Defaults to a new ``InMemoryMemoryStore``.
    ///   - plugins: Custom plugins to hook into the agent's events. Defaults to empty.
    ///   - toolRetriever: The tool retriever used to dynamically select relevant tools. Defaults to `nil`.
    public init(
        systemPrompt: String? = nil,
        maxIterations: Int = 10,
        streamingEnabled: Bool = true,
        skills: [Skill] = [],
        memoryStore: any MemoryStore = InMemoryMemoryStore(),
        plugins: [any AgentPlugin] = [],
        toolRetriever: (any ToolRetriever)? = nil
    ) {
        self.systemPrompt = systemPrompt
        self.maxIterations = maxIterations
        self.streamingEnabled = streamingEnabled
        self.skills = skills
        self.memoryStore = memoryStore
        self.plugins = plugins
        self.toolRetriever = toolRetriever
    }
}
