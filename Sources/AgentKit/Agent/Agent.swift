// Agent.swift
// AgentKit
//
// SPDX-License-Identifier: MIT

import Foundation

/// The main entry point for interacting with the AgentKit SDK.
///
/// `Agent` orchestrates a chat provider and tool registry to run
/// an agentic loop: it sends messages to a language model, executes
/// any requested tool calls, and feeds results back until the model
/// responds without tool calls or a maximum iteration limit is reached.
///
/// ## Usage
/// ```swift
/// let agent = Agent(
///     provider: OpenAIChatProvider(),
///     providerConfiguration: ProviderConfiguration(apiKey: "sk-...")
/// )
/// for try await event in await agent.run("Hello!") {
///     // handle events
/// }
/// ```
public actor Agent {

    // MARK: - Properties

    /// The chat provider used to communicate with the language model.
    private let provider: any ChatProvider

    /// Configuration for the chat provider (API key, model, etc.).
    private let providerConfiguration: ProviderConfiguration

    /// Agent-level configuration (system prompt, iterations, streaming).
    private let configuration: AgentConfiguration

    /// Registry of tools available to the agent.
    private let toolRegistry: ToolRegistry

    /// The session managing conversation state and lifecycle.
    public let session: Session

    // MARK: - Initialization

    /// Creates a new agent.
    ///
    /// - Parameters:
    ///   - provider: The chat provider for model communication.
    ///   - providerConfiguration: Configuration for the provider.
    ///   - configuration: Agent behavior configuration. Defaults to ``AgentConfiguration()``.
    ///   - tools: An array of tools available to the agent. Defaults to empty.
    public init(
        provider: any ChatProvider,
        providerConfiguration: ProviderConfiguration,
        configuration: AgentConfiguration = AgentConfiguration(),
        tools: [any Tool] = []
    ) {
        self.provider = provider
        self.providerConfiguration = providerConfiguration
        self.configuration = configuration

        // Collect all tools: base tools + tools from all skills
        var allTools = tools
        for skill in configuration.skills {
            allTools.append(contentsOf: skill.tools)
        }
        self.toolRegistry = ToolRegistry(tools: allTools)

        // Compile combined system prompt from base and skill prompts
        var compiledPrompt = configuration.systemPrompt ?? ""
        for skill in configuration.skills {
            if !compiledPrompt.isEmpty {
                compiledPrompt += "\n\n"
            }
            compiledPrompt += "## Skill: \(skill.name)\n\(skill.systemPrompt)"
        }
        let finalPrompt = compiledPrompt.isEmpty ? nil : compiledPrompt

        self.session = Session(
            systemPrompt: finalPrompt,
            memoryStore: configuration.memoryStore
        )
    }

    // MARK: - Public API

    /// Runs the agent with the given user input.
    ///
    /// Returns an `AsyncThrowingStream` of ``AgentEvent`` values that
    /// represent the lifecycle of the agent's response, including
    /// streaming text deltas, tool calls, and completion signals.
    ///
    /// - Parameter input: The user's message text.
    /// - Returns: A stream of agent events.
    public func run(_ input: String) -> AsyncThrowingStream<AgentEvent, any Error> {
        let provider = self.provider
        let providerConfig = self.providerConfiguration
        let config = self.configuration
        let registry = self.toolRegistry
        let session = self.session
        let plugins = self.configuration.plugins

        return AsyncThrowingStream { continuation in
            let dispatcher = AgentEventDispatcher(
                continuation: continuation,
                plugins: plugins,
                sessionID: session.id
            )

            let task = Task {
                do {
                    try await Self.executeRun(
                        input: input,
                        provider: provider,
                        providerConfiguration: providerConfig,
                        configuration: config,
                        toolRegistry: registry,
                        session: session,
                        dispatcher: dispatcher
                    )
                } catch let error as AgentKitError {
                    dispatcher.yield(.error(error))
                    dispatcher.finish(throwing: error)
                } catch {
                    let wrapped = AgentKitError.providerError(error.localizedDescription)
                    dispatcher.yield(.error(wrapped))
                    dispatcher.finish(throwing: wrapped)
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }

            Task { await session.setTask(task) }
        }
    }

    /// Cancels the currently running agent task, if any.
    public func cancel() {
        Task { await session.cancelCurrentTask() }
    }

    // MARK: - Core Loop

    /// Executes the main agent run loop.
    private static func executeRun(
        input: String,
        provider: any ChatProvider,
        providerConfiguration: ProviderConfiguration,
        configuration: AgentConfiguration,
        toolRegistry: ToolRegistry,
        session: Session,
        dispatcher: AgentEventDispatcher
    ) async throws {
        await session.markRunning()
        defer { Task { await session.markCompleted() } }

        dispatcher.yield(.started)
        await session.appendMessage(.user(input))

        for iteration in 0..<configuration.maxIterations {
            try Task.checkCancellation()

            var tools = await toolRegistry.allTools
            if let retriever = configuration.toolRetriever, !tools.isEmpty {
                tools = try await retriever.retrieveTools(for: input, from: tools)
            }
            
            let messages = await session.conversation.messages

            let assistantMessage: Message

            if configuration.streamingEnabled {
                assistantMessage = try await handleStreaming(
                    provider: provider,
                    messages: messages,
                    tools: tools,
                    providerConfiguration: providerConfiguration,
                    dispatcher: dispatcher
                )
            } else {
                assistantMessage = try await handleNonStreaming(
                    provider: provider,
                    messages: messages,
                    tools: tools,
                    providerConfiguration: providerConfiguration
                )
            }

            dispatcher.yield(.messageCompleted(assistantMessage))
            await session.appendMessage(assistantMessage)

            guard !assistantMessage.toolCalls.isEmpty else {
                break
            }

            await executeToolCalls(
                assistantMessage.toolCalls,
                toolRegistry: toolRegistry,
                session: session,
                dispatcher: dispatcher
            )

            // Check if we've hit the last allowed iteration
            if iteration == configuration.maxIterations - 1 {
                let error = AgentKitError.maxIterationsReached(
                    configuration.maxIterations
                )
                dispatcher.yield(.error(error))
                dispatcher.finish(throwing: error)
                return
            }
        }

        dispatcher.yield(.completed)
        dispatcher.finish()
    }

    // MARK: - Streaming

    /// Handles a streaming chat response, accumulating deltas into a message.
    private static func handleStreaming(
        provider: any ChatProvider,
        messages: [Message],
        tools: [any Tool],
        providerConfiguration: ProviderConfiguration,
        dispatcher: AgentEventDispatcher
    ) async throws -> Message {
        let stream = provider.streamChat(
            messages: messages,
            tools: tools,
            configuration: providerConfiguration
        )

        var contentAccumulator = ""
        var reasoningAccumulator = ""
        var toolCallAccumulator: [Int: (id: String, name: String, arguments: String)] = [:]
        for try await delta in stream {
            try Task.checkCancellation()

            if let text = delta.deltaContent {
                contentAccumulator += text
                dispatcher.yield(.streamDelta(text))
            }
            
            if let reasoning = delta.deltaReasoningContent {
                reasoningAccumulator += reasoning
                dispatcher.yield(.streamReasoningDelta(reasoning))
            }

            if let toolDeltas = delta.deltaToolCalls {
                for toolDelta in toolDeltas {
                    var existing = toolCallAccumulator[toolDelta.index] ?? (
                        id: "", name: "", arguments: ""
                    )
                    if let id = toolDelta.id {
                        existing.id = id
                    }
                    if let name = toolDelta.functionName {
                        existing.name = name
                    }
                    if let args = toolDelta.argumentsDelta {
                        existing.arguments += args
                    }
                    toolCallAccumulator[toolDelta.index] = existing
                }
            }
        }

        let toolCalls = toolCallAccumulator
            .sorted { $0.key < $1.key }
            .map { ToolCall.make(id: $0.value.id, name: $0.value.name, arguments: $0.value.arguments) }

        let content = contentAccumulator.isEmpty ? nil : contentAccumulator
        let reasoning = reasoningAccumulator.isEmpty ? nil : reasoningAccumulator

        return .assistant(content, reasoningContent: reasoning, toolCalls: toolCalls)
    }

    // MARK: - Non-Streaming

    /// Handles a non-streaming chat response.
    private static func handleNonStreaming(
        provider: any ChatProvider,
        messages: [Message],
        tools: [any Tool],
        providerConfiguration: ProviderConfiguration
    ) async throws -> Message {
        let response = try await provider.sendChat(
            messages: messages,
            tools: tools,
            configuration: providerConfiguration
        )
        return response.message
    }

    // MARK: - Tool Execution

    /// Executes tool calls from an assistant message, yielding events for each.
    private static func executeToolCalls(
        _ toolCalls: [ToolCall],
        toolRegistry: ToolRegistry,
        session: Session,
        dispatcher: AgentEventDispatcher
    ) async {
        for toolCall in toolCalls {
            dispatcher.yield(.toolCallStarted(toolCall))

            let result: String

            guard let tool = await toolRegistry.tool(named: toolCall.function.name) else {
                let errorMessage = "Tool '\(toolCall.function.name)' not found."
                result = errorMessage
                let error = AgentKitError.toolNotFound(toolCall.function.name)
                dispatcher.yield(.error(error))
                dispatcher.yield(.toolCallCompleted(toolCall, result: result))
                await session.appendMessage(.tool(callID: toolCall.id, content: result))
                continue
            }

            do {
                result = try await tool.call(arguments: toolCall.function.arguments)
            } catch {
                let errorMessage = "Tool execution failed: \(error)"
                result = errorMessage
                let agentError = AgentKitError.toolExecutionFailed(
                    toolName: toolCall.function.name,
                    reason: "\(error)"
                )
                dispatcher.yield(.error(agentError))
            }

            dispatcher.yield(.toolCallCompleted(toolCall, result: result))
            await session.appendMessage(.tool(callID: toolCall.id, content: result))
        }
    }
}

// MARK: - AgentEventDispatcher

/// An internal event dispatcher that distributes events to both the stream continuation
/// and all registered plugins.
struct AgentEventDispatcher: Sendable {
    let continuation: AsyncThrowingStream<AgentEvent, any Error>.Continuation
    let plugins: [any AgentPlugin]
    let sessionID: String

    func yield(_ event: AgentEvent) {
        continuation.yield(event)
        for plugin in plugins {
            Task {
                await plugin.onEvent(event, sessionID: sessionID)
            }
        }
    }

    func finish() {
        continuation.finish()
    }

    func finish(throwing error: any Error) {
        continuation.finish(throwing: error)
    }
}
