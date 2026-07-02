//
//  appEnviroment.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 02/07/2026.
//

import Foundation

public enum appEnvironment {
    public static var isTesting: Bool {
        // Checking for XCTest injection is the safest way to detect a unit/UI test run
        if NSClassFromString("XCTestObservationCenter") != nil {
            return true
        }
        
        // If you manually pass a launch argument in your Test scheme, check for it explicitly:
        return ProcessInfo.processInfo.arguments.contains("-isTesting")
    }
}
