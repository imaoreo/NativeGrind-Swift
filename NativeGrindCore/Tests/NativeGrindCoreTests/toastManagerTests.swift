//
//  toastManagerTests.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 01/07/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import NativeGrindCore

@Suite("Toast Manager Tests", .serialized)
@MainActor
struct toastManagerTests {
    
    init() {
        toastManager.shared.dismiss()
    }
    
    @Test("Verifies toastStyle enum maps to correct colors")
    func testToastStyleColors() {
        #expect(toastStyle.error.themeColor == Color.red)
        #expect(toastStyle.warn.themeColor == Color.orange)
        #expect(toastStyle.info.themeColor == Color.blue)
    }
    
    @Test("Verifies toastStyle enum maps to correct SF Symbol icons")
    func testToastStyleIcons() {
        #expect(toastStyle.error.iconName == "exclamationmark.triangle.fill")
        #expect(toastStyle.warn.iconName == "exclamationmark.circle.fill")
        #expect(toastStyle.info.iconName == "info.circle.fill")
    }
    
    @Test("Verifies show() instantly pushes a new toast item to the published property")
    func testShowToastInstantlyUpdatesProperty() {
        let manager = toastManager.shared
        
        manager.show(style: .info, header: "Test Header", message: "Test Message")
        
        #expect(manager.currentToast != nil)
        #expect(manager.currentToast?.style == .info)
        #expect(manager.currentToast?.header == "Test Header")
        #expect(manager.currentToast?.message == "Test Message")
    }
    
    @Test("Verifies dismiss() instantly removes the current toast")
    func testManualDismissal() {
        let manager = toastManager.shared
        
        manager.show(style: .warn, header: "Warning", message: "Memory Low")
        #expect(manager.currentToast != nil)
        
        manager.dismiss()
        #expect(manager.currentToast == nil)
    }
    
    @Test("Verifies the toast automatically dismisses after 4 seconds")
    func testAutoDismissalTiming() async throws {
        let manager = toastManager.shared
        
        manager.show(style: .error, header: "Error", message: "Network Failed")
        #expect(manager.currentToast != nil)
        
        try await Task.sleep(nanoseconds: 4_200_000_000)
        
        #expect(manager.currentToast == nil)
    }
    
    @Test("Verifies triggering a new toast cancels the previous dismissal timer")
    func testToastTimerCancellation() async throws {
        let manager = toastManager.shared
        
        manager.show(style: .info, header: "Toast 1", message: "First")
        
        try await Task.sleep(nanoseconds: 2_000_000_000)
        
        manager.show(style: .warn, header: "Toast 2", message: "Second")
        
        try await Task.sleep(nanoseconds: 2_500_000_000)
        
        #expect(manager.currentToast != nil)
        #expect(manager.currentToast?.header == "Toast 2")
        
        try await Task.sleep(nanoseconds: 2_000_000_000)
        
        #expect(manager.currentToast == nil)
    }
}
