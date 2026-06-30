/// An ordered collection of messages forming an agent conversation.
///
/// `Conversation` is a value type that supports both functional-style
/// (returning new instances) and imperative-style (mutating) message appending.
public struct Conversation: Sendable {

    // MARK: - Properties

    /// The ordered list of messages in this conversation.
    public private(set) var messages: [Message]

    // MARK: - Initializer

    /// Creates a new conversation.
    ///
    /// - Parameter messages: The initial messages. Defaults to empty.
    public init(messages: [Message] = []) {
        self.messages = messages
    }

    // MARK: - Functional API

    /// Returns a new conversation with the given message appended.
    ///
    /// - Parameter message: The message to append.
    /// - Returns: A new `Conversation` containing all existing messages plus the new one.
    public func appending(_ message: Message) -> Conversation {
        Conversation(messages: messages + [message])
    }

    // MARK: - Mutating API

    /// Appends a message to this conversation in place.
    ///
    /// - Parameter message: The message to append.
    public mutating func append(_ message: Message) {
        messages.append(message)
    }

    // MARK: - Computed Properties

    /// Whether this conversation contains no messages.
    public var isEmpty: Bool {
        messages.isEmpty
    }

    /// The number of messages in this conversation.
    public var count: Int {
        messages.count
    }

    /// The most recent message, or `nil` if the conversation is empty.
    public var lastMessage: Message? {
        messages.last
    }
}
