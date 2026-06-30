// AESEncryptor.swift
// AgentKit
//
// SPDX-License-Identifier: MIT

import Foundation
import CryptoKit

/// A ``RequestInterceptor`` that encrypts the HTTP body using AES-GCM.
///
/// This interceptor encrypts the outbound request payload, providing both
/// confidentiality and integrity. It replaces the original `httpBody` with
/// a Base64-encoded string of the encrypted payload, which includes the
/// AES-GCM combined representation (nonce + ciphertext + authentication tag).
///
/// ## Added Headers
/// - `X-Encryption`: Set to `AES-GCM-256`.
/// - `X-Nonce`: The 12-byte nonce used for encryption, encoded in Base64.
///
/// > Important: AES-GCM provides Authenticated Encryption with Associated Data (AEAD),
/// > so an additional HMAC signature for the payload is unnecessary if this
/// > interceptor is used.
public struct AESEncryptor: RequestInterceptor {
    
    private let symmetricKey: SymmetricKey
    
    /// Creates a new AES encryptor.
    ///
    /// - Parameter symmetricKeyBase64: The 256-bit symmetric key, encoded in Base64.
    /// - Throws: An error if the key is not a valid Base64 string or is the wrong size.
    public init(symmetricKeyBase64: String) throws {
        guard let keyData = Data(base64Encoded: symmetricKeyBase64) else {
            throw EncryptionError.invalidKeyData
        }
        self.symmetricKey = SymmetricKey(data: keyData)
    }
    
    /// Creates a new AES encryptor.
    ///
    /// - Parameter symmetricKey: The symmetric key used for encryption.
    public init(symmetricKey: SymmetricKey) {
        self.symmetricKey = symmetricKey
    }
    
    public func intercept(_ request: URLRequest) async throws -> URLRequest {
        var modifiedRequest = request
        
        guard let bodyData = request.httpBody else {
            return request // Nothing to encrypt
        }
        
        do {
            // AES-GCM encryption
            let sealedBox = try AES.GCM.seal(bodyData, using: symmetricKey)
            
            guard let combinedData = sealedBox.combined else {
                throw EncryptionError.encryptionFailed
            }
            
            let base64EncryptedPayload = combinedData.base64EncodedString()
            let base64Nonce = Data(sealedBox.nonce).base64EncodedString()
            
            // Replace the body with the encrypted payload
            modifiedRequest.httpBody = Data(base64EncryptedPayload.utf8)
            
            // Add encryption headers
            modifiedRequest.setValue("AES-GCM-256", forHTTPHeaderField: "X-Encryption")
            modifiedRequest.setValue(base64Nonce, forHTTPHeaderField: "X-Nonce")
            
            // Update Content-Type to indicate encrypted payload
            modifiedRequest.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
            
            return modifiedRequest
            
        } catch {
            throw EncryptionError.encryptionFailed
        }
    }
    
    /// Errors that can occur during encryption.
    public enum EncryptionError: Error, LocalizedError {
        case invalidKeyData
        case encryptionFailed
        
        public var errorDescription: String? {
            switch self {
            case .invalidKeyData: return "The provided Base64 key data is invalid."
            case .encryptionFailed: return "Failed to encrypt the request payload."
            }
        }
    }
}
