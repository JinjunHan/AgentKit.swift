// NetworkLoggerProtocol.swift
// AgentKit-iOSDemo
//
// SPDX-License-Identifier: MIT

import Foundation

/// A custom URLProtocol that intercepts and logs all HTTP requests and responses.
public final class NetworkLoggerProtocol: URLProtocol {

    private static let handledKey = "NetworkLoggerProtocolHandledKey"

    public override class func canInit(with request: URLRequest) -> Bool {
        guard let scheme = request.url?.scheme, scheme.hasPrefix("http") else { return false }
        if URLProtocol.property(forKey: handledKey, in: request) != nil {
            return false
        }
        return true
    }

    public override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    public override func startLoading() {
        guard let mutableRequest = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest else { return }
        URLProtocol.setProperty(true, forKey: Self.handledKey, in: mutableRequest)

        // Log Request
        logRequest(mutableRequest as URLRequest)

        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        let task = session.dataTask(with: mutableRequest as URLRequest)
        task.resume()
    }

    public override func stopLoading() {
        // No-op
    }

    // MARK: - Logging Logic

    private func logRequest(_ request: URLRequest) {
        print("\n--- 🚀 OUTGOING REQUEST ---")
        if let method = request.httpMethod, let url = request.url {
            print("\(method) \(url.absoluteString)")
        }
        if let headers = request.allHTTPHeaderFields, !headers.isEmpty {
            print("Headers:")
            for (key, value) in headers {
                // Mask sensitive keys
                if key.lowercased().contains("authorization") || key.lowercased().contains("api-key") {
                    print("  \(key): <MASKED>")
                } else {
                    print("  \(key): \(value)")
                }
            }
        }
        if let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8) {
            print("Body:\n\(bodyString)")
        }
        print("---------------------------\n")
    }

    private func logResponse(_ response: URLResponse) {
        print("\n--- 📥 INCOMING RESPONSE ---")
        if let httpResponse = response as? HTTPURLResponse {
            if let url = httpResponse.url {
                print("URL: \(url.absoluteString)")
            }
            print("Status Code: \(httpResponse.statusCode)")
            if let headers = httpResponse.allHeaderFields as? [String: Any], !headers.isEmpty {
                print("Headers:")
                for (key, value) in headers {
                    print("  \(key): \(value)")
                }
            }
        }
        print("----------------------------\n")
    }
}

extension NetworkLoggerProtocol: URLSessionDataDelegate {
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        logResponse(response)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        completionHandler(.allow)
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        client?.urlProtocol(self, didLoad: data)
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            print("\n--- ❌ REQUEST FAILED ---")
            print("URL: \(task.originalRequest?.url?.absoluteString ?? "Unknown")")
            print("Error: \(error.localizedDescription)")
            print("-------------------------\n")
            client?.urlProtocol(self, didFailWithError: error)
        } else {
            client?.urlProtocolDidFinishLoading(self)
        }
    }
}
