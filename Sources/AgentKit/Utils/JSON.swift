import Foundation

/// A type-erased JSON value for dynamic JSON handling.
///
/// `JSONValue` provides a Sendable, Codable representation of arbitrary JSON,
/// enabling safe passage of unstructured data across concurrency boundaries.
public enum JSONValue: Sendable, Codable, Equatable, CustomStringConvertible {

    /// A JSON `null`.
    case null

    /// A JSON boolean.
    case bool(Bool)

    /// A JSON integer number.
    case int(Int)

    /// A JSON floating-point number.
    case double(Double)

    /// A JSON string.
    case string(String)

    /// A JSON array.
    case array([JSONValue])

    /// A JSON object.
    case object([String: JSONValue])

    // MARK: - Decodable

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
            return
        }

        if let boolValue = try? container.decode(Bool.self) {
            self = .bool(boolValue)
            return
        }

        if let intValue = try? container.decode(Int.self) {
            self = .int(intValue)
            return
        }

        if let doubleValue = try? container.decode(Double.self) {
            self = .double(doubleValue)
            return
        }

        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
            return
        }

        if let arrayValue = try? container.decode([JSONValue].self) {
            self = .array(arrayValue)
            return
        }

        if let objectValue = try? container.decode([String: JSONValue].self) {
            self = .object(objectValue)
            return
        }

        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Unable to decode JSONValue"
        )
    }

    // MARK: - Encodable

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        }
    }

    // MARK: - CustomStringConvertible

    /// Serializes this value to a compact JSON string.
    public var description: String {
        guard let data = try? JSONEncoder().encode(self),
              let string = String(data: data, encoding: .utf8)
        else {
            return "null"
        }
        return string
    }

    // MARK: - Static Helpers

    /// Encodes an `Encodable` value to a JSON string.
    ///
    /// - Parameter value: The value to encode.
    /// - Returns: A JSON string representation.
    /// - Throws: `AgentKitError.encodingError` if encoding fails.
    public static func encodeToString<T: Encodable>(
        _ value: T
    ) throws(AgentKitError) -> String {
        do {
            let data = try JSONEncoder().encode(value)
            guard let string = String(data: data, encoding: .utf8) else {
                throw AgentKitError.encodingError(
                    "Failed to convert encoded data to UTF-8 string"
                )
            }
            return string
        } catch let error as AgentKitError {
            throw error
        } catch {
            throw AgentKitError.encodingError(error.localizedDescription)
        }
    }

    /// Decodes a JSON string into a `Decodable` value.
    ///
    /// - Parameters:
    ///   - type: The type to decode into.
    ///   - string: The JSON string to decode.
    /// - Returns: The decoded value.
    /// - Throws: `AgentKitError.encodingError` if decoding fails.
    public static func decodeFromString<T: Decodable>(
        _ type: T.Type,
        from string: String
    ) throws(AgentKitError) -> T {
        guard let data = string.data(using: .utf8) else {
            throw AgentKitError.encodingError(
                "Failed to convert string to UTF-8 data"
            )
        }

        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw AgentKitError.encodingError(error.localizedDescription)
        }
    }
}
