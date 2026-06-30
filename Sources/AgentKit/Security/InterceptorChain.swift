// InterceptorChain.swift
// AgentKit
//
// SPDX-License-Identifier: MIT

import Foundation

/// A chain of ``RequestInterceptor`` instances executed sequentially.
///
/// The `InterceptorChain` takes an initial `URLRequest` and passes it through
/// a series of interceptors, where each interceptor can modify the request
/// before passing it to the next one.
public struct InterceptorChain: Sendable {
    
    private let interceptors: [any RequestInterceptor]
    
    /// Creates a new interceptor chain.
    ///
    /// - Parameter interceptors: An array of interceptors to execute in order.
    public init(interceptors: [any RequestInterceptor]) {
        self.interceptors = interceptors
    }
    
    /// Executes the interceptor chain on a given request.
    ///
    /// - Parameter request: The initial URL request.
    /// - Returns: The final modified URL request after all interceptors have run.
    /// - Throws: An error if any interceptor in the chain fails.
    public func execute(request: URLRequest) async throws -> URLRequest {
        var currentRequest = request
        for interceptor in interceptors {
            currentRequest = try await interceptor.intercept(currentRequest)
        }
        return currentRequest
    }
}
