import Foundation

/// A single message in an agent conversation.
///
/// Messages represent the structured turns in a conversation between
/// the system, user, assistant, and tool roles.
public struct Message: Sendable, Identifiable {

    // MARK: - Role

    /// The role of the message sender.
    public enum Role: String, Sendable, Codable, CaseIterable {

        /// A system-level instruction.
        case system

        /// A user-provided message.
        case user

        /// An assistant (LLM) response.
        case assistant

        /// A tool result message.
        case tool
    }

    // MARK: - Properties

    /// The unique identifier for this message.
    public let id: String

    /// The role of the message sender.
    public let role: Role

    /// The text content of the message, if any.
    public let content: String?

    /// The optional reasoning content (e.g., from DeepSeek R1 or Claude 3.7 "Thinking" mode).
    public let reasoningContent: String?

    /// Tool calls requested by the assistant, if any.
    public let toolCalls: [ToolCall]

    /// The ID of the tool call this message responds to, if applicable.
    public let toolCallID: String?

    /// The timestamp when this message was created.
    public let createdAt: Date

    // MARK: - Initializer

    /// Creates a new message.
    ///
    /// - Parameters:
    ///   - id: A unique identifier. Defaults to a new UUID string.
    ///   - role: The sender role.
    ///   - content: Optional text content.
    ///   - reasoningContent: Optional reasoning process text (for thinking models). Defaults to nil.
    ///   - toolCalls: Tool calls from the assistant. Defaults to empty.
    ///   - toolCallID: The tool call ID this message responds to. Defaults to nil.
    ///   - createdAt: Creation timestamp. Defaults to now.
    public init(
        id: String = UUID().uuidString,
        role: Role,
        content: String? = nil,
        reasoningContent: String? = nil,
        toolCalls: [ToolCall] = [],
        toolCallID: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.reasoningContent = reasoningContent
        self.toolCalls = toolCalls
        self.toolCallID = toolCallID
        self.createdAt = createdAt
    }

    // MARK: - Factory Methods

    /// Creates a system message.
    ///
    /// - Parameter content: The system instruction text.
    /// - Returns: A message with the `.system` role.
    public static func system(_ content: String) -> Message {
        Message(role: .system, content: content)
    }

    /// Creates a user message.
    ///
    /// - Parameter content: The user's input text.
    /// - Returns: A message with the `.user` role.
    public static func user(_ content: String) -> Message {
        Message(role: .user, content: content)
    }

    /// Creates an assistant message.
    ///
    /// - Parameters:
    ///   - content: Optional response text.
    ///   - reasoningContent: Optional reasoning process text (for thinking models). Defaults to nil.
    ///   - toolCalls: Tool calls requested by the assistant. Defaults to empty.
    /// - Returns: A message with the `.assistant` role.
    public static func assistant(
        _ content: String?,
        reasoningContent: String? = nil,
        toolCalls: [ToolCall] = []
    ) -> Message {
        Message(role: .assistant, content: content, reasoningContent: reasoningContent, toolCalls: toolCalls)
    }

    /// Creates a tool result message.
    ///
    /// - Parameters:
    ///   - callID: The ID of the tool call this responds to.
    ///   - content: The tool's output.
    /// - Returns: A message with the `.tool` role.
    public static func tool(callID: String, content: String) -> Message {
        Message(role: .tool, content: content, toolCallID: callID)
    }
}
