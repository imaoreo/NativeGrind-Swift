//
//  appEnviroment.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 02/07/2026.
//

import Foundation

public enum appEnvironment {
    public static var isTesting: Bool {
        if NSClassFromString("XCTestObservationCenter") != nil {
            return true
        }
        
        let env = ProcessInfo.processInfo.environment
        if env["XCTestConfigurationFilePath"] != nil ||
           env["XCTestBundlePath"] != nil ||
           env["XCTestSessionIdentifier"] != nil ||
           env["XCTestBundleInjectPath"] != nil {
            return true
        }
        
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-isTesting") {
            return true
        }
        
        if args.contains(where: { $0.contains("swiftpm-testing-helper") || $0.contains("swift-testing") || $0.contains(".xctest/") }) {
            return true
        }
        
        let processName = ProcessInfo.processInfo.processName.lowercased()
        if processName.contains("xctest") || processName.contains("swiftpm-testing-helper") {
            return true
        }
        
        return false
    }

    private static let lock = NSLock()
    private nonisolated(unsafe) static var _isServerEnabled: Bool = false

    public static var isServerEnabled: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _isServerEnabled
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _isServerEnabled = newValue
        }
    }
}
