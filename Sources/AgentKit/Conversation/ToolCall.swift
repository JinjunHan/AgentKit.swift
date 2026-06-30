import Foundation

/// Represents an LLM-requested tool invocation.
///
/// A `ToolCall` captures the tool's identifier and its function metadata,
/// including the raw JSON argument string from the model.
public struct ToolCall: Sendable, Codable, Identifiable, Hashable {

    /// The unique identifier for this tool call.
    public let id: String

    /// The function to invoke.
    public let function: Function

    // MARK: - Nested Types

    /// Describes the function name and its raw JSON arguments.
    public struct Function: Sendable, Codable, Hashable {

        /// The name of the function to call.
        public let name: String

        /// The raw JSON string of the function arguments.
        public let arguments: String
    }

    // MARK: - Factory

    /// Creates a new `ToolCall` with the given parameters.
    ///
    /// - Parameters:
    ///   - id: A unique identifier. Defaults to a new UUID string.
    ///   - name: The function name.
    ///   - arguments: The raw JSON arguments string.
    /// - Returns: A configured `ToolCall`.
    public static func make(
        id: String = UUID().uuidString,
        name: String,
        arguments: String
    ) -> ToolCall {
        ToolCall(
            id: id,
            function: Function(name: name, arguments: arguments)
        )
    }
}
