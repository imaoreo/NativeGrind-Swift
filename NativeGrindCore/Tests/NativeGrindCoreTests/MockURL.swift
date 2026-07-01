//
//  MockURL.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 01/07/2026.
//

import Foundation

// Just here to make Swift 6 happy
final class MockHandlerContainer: @unchecked Sendable {
    private let lock = NSLock()
    private var _handler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?
    
    var handler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _handler
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _handler = newValue
        }
    }
}

// Intercepter for the testing
class MockURLProtocol: URLProtocol {
    static let shared = MockHandlerContainer()
    
    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override func startLoading() {
        guard let handler = MockURLProtocol.shared.handler else {
            fatalError("Handler is unavailable.")
        }
        
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    
    override func stopLoading() {}
}
