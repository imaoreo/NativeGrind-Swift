//
//  toastOverview.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 17/06/2026.
//

import SwiftUI

struct toastOverlay: ViewModifier {
    @ObservedObject private var _toastManager = toastManager.shared

    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content
                .zIndex(0)
            
            if let toast = _toastManager.currentToast {
                HStack(spacing: 12) {
                    Image(systemName: toast.style.iconName)
                        .font(.title3)
                        .foregroundColor(toast.style.themeColor)
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(toast.header)
                            .font(.system(.subheadline).bold())
                            .foregroundColor(.white)
                        
                        Text(toast.message)
                            .font(.system(.footnote))
                            .foregroundColor(.white.opacity(0.85))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Spacer()
                    
                    Button(action: { _toastManager.dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.caption2.bold())
                            .foregroundColor(.white.opacity(0.5))
                            .padding(6)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(red: 0.08, green: 0.08, blue: 0.1))
                        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(toast.style.themeColor.opacity(0.35), lineWidth: 1)
                )
                .padding(.horizontal, 16)
                .padding(.top, safeAreaTopPadding)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(1)
            }
        }
        .animation(.bouncy(duration: 0.35), value: _toastManager.currentToast)
    }
    
    private var safeAreaTopPadding: CGFloat {
        #if os(iOS)
            let scenes = UIApplication.shared.connectedScenes
            let windowScene = scenes.first as? UIWindowScene
            let topPadding = windowScene?.windows.first?.safeAreaInsets.top ?? 0
            return topPadding > 0 ? topPadding : 12
        #else
            return 16
        #endif
    }
}

extension View {
    public func withToastOverlay() -> some View {
        self.modifier(toastOverlay())
    }
}
