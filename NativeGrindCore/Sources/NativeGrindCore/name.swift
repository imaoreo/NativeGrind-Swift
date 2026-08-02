//
//  name.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 15/07/2026.
//

import Foundation

#if canImport(UIKit)
import UIKit
#endif

#if canImport(WatchKit)
import WatchKit
#endif

func getUniversalDeviceName() -> String {
    #if os(iOS) || os(tvOS) || os(visionOS)
    return UIDevice.current.name
    
    #elseif os(macOS)

    return Host.current().localizedName ?? ProcessInfo.processInfo.hostName
    
    #elseif os(watchOS)

    return WKInterfaceDevice.current().name
    
    #else

    return ProcessInfo.processInfo.hostName
    #endif
}
