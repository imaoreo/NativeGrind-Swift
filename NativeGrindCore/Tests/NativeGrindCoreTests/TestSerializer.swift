//
//  TestSerializer.swift
//  NativeGrindCore
//
//  Created by Antigravity on 02/07/2026.
//

import Foundation

// Global lock to serialize tests that access singletons or shared mock state
public actor TestSerializer {
    public static let shared = TestSerializer()
    
    private var isLocked = false
    private var continuations: [CheckedContinuation<Void, Never>] = []
    
    private init() {}
    
    private func lock() async {
        if !isLocked {
            isLocked = true
            return
        }
        await withCheckedContinuation { continuation in
            continuations.append(continuation)
        }
    }
    
    private func unlock() {
        if continuations.isEmpty {
            isLocked = false
        } else {
            let next = continuations.removeFirst()
            next.resume()
        }
    }
    
    public func run<T: Sendable>(_ block: @MainActor @Sendable () async throws -> T) async throws -> T {
        await lock()
        defer { unlock() }
        return try await block()
    }
    
    public func run<T: Sendable>(_ block: @MainActor @Sendable () async -> T) async -> T {
        await lock()
        defer { unlock() }
        return await block()
    }
}
