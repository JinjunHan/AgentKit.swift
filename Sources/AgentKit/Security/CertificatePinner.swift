// CertificatePinner.swift
// AgentKit
//
// SPDX-License-Identifier: MIT

import Foundation
import Security
import CryptoKit

/// A utility for TLS certificate pinning via `URLSessionDelegate`.
///
/// `CertificatePinner` intercepts authentication challenges and verifies that the
/// server's public key matches one of the expected SHA-256 hashes (pins). This
/// protects against Man-In-The-Middle (MITM) attacks where an attacker might
/// have compromised a Root Certificate Authority.
///
/// ## Usage
/// ```swift
/// let pinner = CertificatePinner(pinnedKeyHashes: [
///     "api.example.com": [
///         "sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
///         "sha256/BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB="
///     ]
/// ])
///
/// let session = URLSession(
///     configuration: .default,
///     delegate: pinner,
///     delegateQueue: nil
/// )
/// ```
public final class CertificatePinner: NSObject, URLSessionDelegate, Sendable {
    
    /// A dictionary mapping domain names to an array of accepted public key hashes.
    /// Hashes should be prefixed with "sha256/" and be Base64-encoded.
    private let pinnedKeyHashes: [String: [String]]
    
    /// Creates a new certificate pinner.
    ///
    /// - Parameter pinnedKeyHashes: A dictionary of domains and their valid public key hashes.
    public init(pinnedKeyHashes: [String: [String]]) {
        self.pinnedKeyHashes = pinnedKeyHashes
    }
    
    public func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust,
              let host = challenge.protectionSpace.host as String? else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        // If the host is not in our pinning configuration, decide whether to allow.
        // For strict security, we only allow pinned hosts, but for flexibility,
        // we fallback to default handling if no pins are configured for this host.
        guard let validPins = pinnedKeyHashes[host], !validPins.isEmpty else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        var error: CFError?
        guard SecTrustEvaluateWithError(serverTrust, &error) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        // Extract the server's certificate chain
        guard let certificateChain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate],
              !certificateChain.isEmpty else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        // Extract public keys from the certificate chain and check against pins
        var isPinned = false
        
        for certificate in certificateChain {
            guard let publicKey = SecCertificateCopyKey(certificate),
                  let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, nil) as Data? else {
                continue
            }
            
            let keyHash = SHA256.hash(data: publicKeyData)
            let keyHashBase64 = Data(keyHash).base64EncodedString()
            let pinFormat = "sha256/\(keyHashBase64)"
            
            if validPins.contains(pinFormat) {
                isPinned = true
                break
            }
        }
        
        if isPinned {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}
