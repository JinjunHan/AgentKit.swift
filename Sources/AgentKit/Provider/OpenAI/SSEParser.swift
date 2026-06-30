// SSEParser.swift
// AgentKit
//
// SPDX-License-Identifier: MIT

import Foundation

/// Parses Server-Sent Events (SSE) from raw async bytes into decoded
/// Decodable model structures.
///
/// The parser handles the standard SSE wire format:
/// - Lines prefixed with `data: ` contain JSON payloads.
/// - Empty lines and comment lines (prefixed with `:`) are skipped.
/// - The sentinel `[DONE]` signals the end of the stream.
struct SSEParser: Sendable {

    /// Parse SSE events from ``URLSession`` async bytes.
    ///
    /// - Parameters:
    ///   - bytes: The raw byte stream from `URLSession.bytes(for:)`.
    ///   - decodingType: The Decodable type to decode JSON payloads into.
    /// - Returns: An asynchronous throwing stream of decoded responses.
    static func events<T: Decodable & Sendable>(
        from bytes: URLSession.AsyncBytes,
        decodingType: T.Type
    ) -> AsyncThrowingStream<T, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                let decoder = JSONDecoder()
                do {
                    for try await line in bytes.lines {
                        // Skip empty lines and SSE comments.
                        guard !line.isEmpty, !line.hasPrefix(":") else {
                            continue
                        }

                        // Only process lines with the "data: " prefix.
                        guard line.hasPrefix("data: ") else {
                            continue
                        }

                        let payload = String(line.dropFirst(6))

                        // The sentinel value signals end-of-stream.
                        guard payload != "[DONE]" else {
                            break
                        }

                        guard let jsonData = payload.data(using: .utf8) else {
                            continue
                        }

                        let response = try decoder.decode(
                            T.self,
                            from: jsonData
                        )
                        continuation.yield(response)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
