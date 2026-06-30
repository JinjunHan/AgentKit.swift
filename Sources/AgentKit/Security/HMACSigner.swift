// HMACSigner.swift
// AgentKit
//
// SPDX-License-Identifier: MIT

import Foundation
import CryptoKit

/// A ``RequestInterceptor`` that signs outbound requests using HMAC-SHA256.
///
/// This interceptor calculates a cryptographic signature of the request's
/// HTTP method, URL path, timestamp, and body (if present). It adds the
/// signature, a timestamp, and a random nonce to the HTTP headers.
///
/// This provides protection against tampering and replay attacks.
///
/// ## Added Headers
/// - `X-Signature`: The base64-encoded HMAC-SHA256 signature.
/// - `X-Timestamp`: Unix timestamp (seconds) when the signature was generated.
/// - `X-Nonce`: A UUID string to ensure uniqueness of the signature.
public struct HMACSigner: RequestInterceptor {
    
    private let secretKey: SymmetricKey
    
    /// Creates a new HMAC signer.
    ///
    /// - Parameter secretKeyString: The secret key used for signing, as a UTF-8 string.
    public init(secretKeyString: String) {
        let keyData = Data(secretKeyString.utf8)
        self.secretKey = SymmetricKey(data: keyData)
    }
    
    /// Creates a new HMAC signer.
    ///
    /// - Parameter secretKey: The symmetric key used for signing.
    public init(secretKey: SymmetricKey) {
        self.secretKey = secretKey
    }
    
    public func intercept(_ request: URLRequest) async throws -> URLRequest {
        var modifiedRequest = request
        
        let timestamp = String(Int(Date().timeIntervalSince1970))
        let nonce = UUID().uuidString
        
        // Build the string to sign
        // Format: METHOD + \n + PATH + \n + TIMESTAMP + \n + NONCE + \n + BODY_HASH
        
        let method = request.httpMethod ?? "GET"
        let path = request.url?.path ?? "/"
        
        var bodyHashString = ""
        if let bodyData = request.httpBody {
            let hash = SHA256.hash(data: bodyData)
            bodyHashString = hash.compactMap { String(format: "%02x", $0) }.joined()
        }
        
        let stringToSign = [
            method,
            path,
            timestamp,
            nonce,
            bodyHashString
        ].joined(separator: "\n")
        
        // Calculate HMAC-SHA256
        let dataToSign = Data(stringToSign.utf8)
        let signature = HMAC<SHA256>.authenticationCode(for: dataToSign, using: secretKey)
        let signatureBase64 = Data(signature).base64EncodedString()
        
        // Add headers
        modifiedRequest.setValue(signatureBase64, forHTTPHeaderField: "X-Signature")
        modifiedRequest.setValue(timestamp, forHTTPHeaderField: "X-Timestamp")
        modifiedRequest.setValue(nonce, forHTTPHeaderField: "X-Nonce")
        
        return modifiedRequest
    }
}
