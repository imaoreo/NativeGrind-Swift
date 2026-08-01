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
        
        return ProcessInfo.processInfo.arguments.contains("-isTesting")
    }

    public nonisolated(unsafe) static var isServerEnabled: Bool = false
}
