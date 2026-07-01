//
//  appEnviroment.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 02/07/2026.
//

import Foundation

public enum appEnvironment {
    public static var isTesting: Bool {
        let args = ProcessInfo.processInfo.arguments.joined(separator: " ").uppercased()
        let env = ProcessInfo.processInfo.environment.keys.joined(separator: " ").uppercased()
        return args.contains("TEST") || env.contains("TEST") || NSClassFromString("XCTestObservationCenter") != nil
    }
}
