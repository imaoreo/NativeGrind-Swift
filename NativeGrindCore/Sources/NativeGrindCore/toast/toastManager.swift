//
//  toastManager.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 17/06/2026.
//

import SwiftUI
import Combine

public enum toastStyle {
    case error
    case warn
    case info
    
    var themeColor: Color {
        switch self {
            case .error: return Color.red
            case .warn: return Color.orange
            case .info: return Color.blue
        }
    }
    
    var iconName: String {
        switch self {
            case .error: return "exclamationmark.triangle.fill"
            case .warn: return "exclamationmark.circle.fill"
            case .info: return "info.circle.fill"
        }
    }
}

public struct toastItem: Identifiable, Equatable {
    public let id = UUID()
    public let style: toastStyle
    public let header: String
    public let message: String
}

@MainActor
public final class toastManager: ObservableObject {
    public static let shared = toastManager()
    
    @Published public var currentToast: toastItem? = nil
    private var dismissTask: Task<Void, Never>? = nil
    
    private init() {}
    
    /// Shows a Toast with the specified information
    /// - Parameters:
    ///   - style: ToastStyle, .info, .warning etc
    ///   - header: Header at the top bold
    ///   - message: descriptive message
    public func show(style: toastStyle, header: String, message: String) {
        // Cancel any active auto-dismiss countdowns for existing toasts
        dismissTask?.cancel()
            
        // Push the new layout metadata structure
        self.currentToast = toastItem(style: style, header: header, message: message)
        
        // Removes the toast after 4 seconds
        dismissTask = Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000) // 4 seconds
            guard !Task.isCancelled else { return }
            withAnimation {
                self.currentToast = nil
            }
        }
    }
    
    public func dismiss() {
        dismissTask?.cancel()
        withAnimation {
            self.currentToast = nil
        }
    }
}
