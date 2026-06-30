// RequestInterceptor.swift
// AgentKit
//
// SPDX-License-Identifier: MIT

import Foundation

/// A protocol for intercepting and modifying outbound URL requests.
///
/// Interceptors can be used to add security headers, perform request signing,
/// encrypt payloads, or inject authentication tokens before a request is sent
/// to the language model provider.
///
/// ## Usage
/// ```swift
/// struct CustomHeaderInterceptor: RequestInterceptor {
///     func intercept(_ request: URLRequest) async throws -> URLRequest {
///         var modified = request
///         modified.addValue("MyApp/1.0", forHTTPHeaderField: "User-Agent")
///         return modified
///     }
/// }
/// ```
public protocol RequestInterceptor: Sendable {
    
    /// Intercepts and potentially modifies an outbound URL request.
    ///
    /// - Parameter request: The original URL request.
    /// - Returns: The modified URL request.
    /// - Throws: An error if the interception fails (e.g., encryption failure).
    func intercept(_ request: URLRequest) async throws -> URLRequest
}
