/// Events emitted during an agent's execution lifecycle.
///
/// Subscribe to `AgentEvent` via an `AsyncStream` to observe the agent's
/// progress, including streaming deltas, tool executions, and completion.
public enum AgentEvent: Sendable {

    /// The agent run has started.
    case started

    /// An incremental text chunk received from the LLM.
    case streamDelta(String)

    /// An incremental reasoning chunk (thinking process) received from the LLM.
    case streamReasoningDelta(String)

    /// A tool call is about to be executed.
    case toolCallStarted(ToolCall)

    /// A tool call completed with a result.
    case toolCallCompleted(ToolCall, result: String)

    /// A full assistant message has been assembled.
    case messageCompleted(Message)

    /// A non-fatal error occurred during the run.
    case error(AgentKitError)

    /// The agent run has finished.
    case completed
}
