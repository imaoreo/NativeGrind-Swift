//
//  chatSwipeToReply.swift
//  NativeGrind
//
//  Created by Jay Brammeld on 24/09/2026.
//

import SwiftUI

struct chatSwipeToReply: ViewModifier {
    let isEnabled: Bool
    let onReply: () -> Void

    @State private var offset: CGFloat = 0

    private let threshold: CGFloat = 60

    func body(content: Content) -> some View {
        #if os(tvOS)
        content
        #else
        content
            .offset(x: offset)
            .background(alignment: .leading) {
                Image(systemName: "arrowshape.turn.up.left.fill")
                    .foregroundColor(.secondary)
                    .opacity(Double(min(offset / threshold, 1)))
                    .padding(.leading, 4)
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 20)
                    .onChanged { value in
                        let horizontal = value.translation.width
                        
                        guard horizontal > 0, abs(horizontal) > abs(value.translation.height) else { return }
                        offset = min(horizontal, threshold * 1.3)
                    }
                    .onEnded { _ in
                        if offset >= threshold {
                            onReply()
                        }
                        withAnimation(.spring(duration: 0.25)) {
                            offset = 0
                        }
                    },
                including: isEnabled ? .all : .subviews
            )
            #if os(iOS)
            .sensoryFeedback(.impact, trigger: offset >= threshold) { _, reached in reached }
            #endif
        #endif
    }
}

extension View {
    func swipeToReply(isEnabled: Bool, perform onReply: @escaping () -> Void) -> some View {
        modifier(chatSwipeToReply(isEnabled: isEnabled, onReply: onReply))
    }
}
