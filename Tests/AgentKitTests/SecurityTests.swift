// SecurityTests.swift
// AgentKit
//
// SPDX-License-Identifier: MIT

import XCTest
import CryptoKit
@testable import AgentKit

final class SecurityTests: XCTestCase {
    
    func testHMACSigner() async throws {
        let secret = "test-secret-key"
        let signer = HMACSigner(secretKeyString: secret)
        
        var request = URLRequest(url: URL(string: "https://api.example.com/v1/chat")!)
        request.httpMethod = "POST"
        request.httpBody = Data("{\"prompt\":\"hello\"}".utf8)
        
        let signedRequest = try await signer.intercept(request)
        
        XCTAssertNotNil(signedRequest.value(forHTTPHeaderField: "X-Signature"))
        XCTAssertNotNil(signedRequest.value(forHTTPHeaderField: "X-Timestamp"))
        XCTAssertNotNil(signedRequest.value(forHTTPHeaderField: "X-Nonce"))
        
        // Ensure original request details are unchanged
        XCTAssertEqual(signedRequest.httpMethod, "POST")
        XCTAssertEqual(signedRequest.url?.absoluteString, "https://api.example.com/v1/chat")
        XCTAssertEqual(signedRequest.httpBody, request.httpBody)
    }
    
    func testAESEncryptor() async throws {
        // Generate a valid 256-bit key in Base64
        let symmetricKey = SymmetricKey(size: .bits256)
        let keyData = symmetricKey.withUnsafeBytes { Data($0) }
        let keyBase64 = keyData.base64EncodedString()
        
        let encryptor = try AESEncryptor(symmetricKeyBase64: keyBase64)
        
        var request = URLRequest(url: URL(string: "https://api.example.com")!)
        let originalBody = "secret payload"
        request.httpBody = Data(originalBody.utf8)
        
        let encryptedRequest = try await encryptor.intercept(request)
        
        XCTAssertNotNil(encryptedRequest.httpBody)
        XCTAssertNotEqual(encryptedRequest.httpBody, request.httpBody)
        XCTAssertEqual(encryptedRequest.value(forHTTPHeaderField: "X-Encryption"), "AES-GCM-256")
        XCTAssertNotNil(encryptedRequest.value(forHTTPHeaderField: "X-Nonce"))
        XCTAssertEqual(encryptedRequest.value(forHTTPHeaderField: "Content-Type"), "application/octet-stream")
        
        // Verify decryption capability
        if let base64BodyString = String(data: encryptedRequest.httpBody!, encoding: .utf8),
           let combinedData = Data(base64Encoded: base64BodyString) {
            let sealedBox = try AES.GCM.SealedBox(combined: combinedData)
            let decryptedData = try AES.GCM.open(sealedBox, using: symmetricKey)
            let decryptedString = String(data: decryptedData, encoding: .utf8)
            XCTAssertEqual(decryptedString, originalBody)
        } else {
            XCTFail("Failed to decode encrypted body back from base64")
        }
    }
    
    func testInterceptorChain() async throws {
        struct DummyInterceptorA: RequestInterceptor {
            func intercept(_ request: URLRequest) async throws -> URLRequest {
                var req = request
                req.setValue("ValueA", forHTTPHeaderField: "HeaderA")
                return req
            }
        }
        
        struct DummyInterceptorB: RequestInterceptor {
            func intercept(_ request: URLRequest) async throws -> URLRequest {
                var req = request
                req.setValue("ValueB", forHTTPHeaderField: "HeaderB")
                return req
            }
        }
        
        let chain = InterceptorChain(interceptors: [DummyInterceptorA(), DummyInterceptorB()])
        let request = URLRequest(url: URL(string: "https://example.com")!)
        
        let finalRequest = try await chain.execute(request: request)
        
        XCTAssertEqual(finalRequest.value(forHTTPHeaderField: "HeaderA"), "ValueA")
        XCTAssertEqual(finalRequest.value(forHTTPHeaderField: "HeaderB"), "ValueB")
    }
}
