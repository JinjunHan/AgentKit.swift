/// Typed error enum for all AgentKit operations.
///
/// Use `AgentKitError` with typed throws (`throws(AgentKitError)`) to provide
/// compile-time guarantees about error handling throughout the SDK.
public enum AgentKitError: Error, Sendable, CustomStringConvertible {

    /// The LLM provider returned an error.
    case providerError(String)

    /// The requested tool name was not found in the registry.
    case toolNotFound(String)

    /// A tool execution threw an error.
    case toolExecutionFailed(toolName: String, reason: String)

    /// JSON encoding or decoding failed.
    case encodingError(String)

    /// A network or HTTP-level failure occurred.
    case networkError(String)

    /// The operation was cancelled.
    case cancelled

    /// The configuration is invalid.
    case invalidConfiguration(String)

    /// The agent loop exceeded the maximum allowed iterations.
    case maxIterationsReached(Int)

    // MARK: - CustomStringConvertible

    public var description: String {
        switch self {
        case .providerError(let message):
            "Provider error: \(message)"
        case .toolNotFound(let name):
            "Tool not found: '\(name)'"
        case .toolExecutionFailed(let toolName, let reason):
            "Tool '\(toolName)' execution failed: \(reason)"
        case .encodingError(let message):
            "Encoding error: \(message)"
        case .networkError(let message):
            "Network error: \(message)"
        case .cancelled:
            "Operation cancelled"
        case .invalidConfiguration(let message):
            "Invalid configuration: \(message)"
        case .maxIterationsReached(let count):
            "Max iterations reached: \(count)"
        }
    }
}
