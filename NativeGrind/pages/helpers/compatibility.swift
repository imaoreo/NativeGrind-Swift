//
//  compatibility.swift
//  NativeGrind
//
//  Created by Jay Brammeld on 26/09/2026.
//

import SwiftUI

struct emptyStateView: View {
    let title: String
    let systemImage: String
    var description: Text? = nil

    init(_ title: String, systemImage: String, description: Text? = nil) {
        self.title = title
        self.systemImage = systemImage
        self.description = description
    }

    var body: some View {
        if #available(iOS 17, *) {
            ContentUnavailableView(title, systemImage: systemImage, description: description)
        } else {
            VStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 44))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.title3.bold())
                if let description {
                    description
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

extension View {
    @ViewBuilder
    func onChangeCompat<Value: Equatable>(of value: Value, perform action: @escaping (_ oldValue: Value, _ newValue: Value) -> Void) -> some View {
        if #available(iOS 17, *) {
            onChange(of: value) { oldValue, newValue in action(oldValue, newValue) }
        } else {
            modifier(legacyChangeObserver(value: value, action: action))
        }
    }

    @ViewBuilder
    func startsAtBottom() -> some View {
        if #available(iOS 17, *) {
            defaultScrollAnchor(.bottom)
        } else {
            self
        }
    }

    @ViewBuilder
    func impactFeedback(trigger: Bool) -> some View {
        #if os(tvOS)
        self
        #else
        if #available(iOS 17, *) {
            sensoryFeedback(.impact, trigger: trigger) { _, new in new }
        } else {
            self
        }
        #endif
    }
}

var separatorStyle: AnyShapeStyle {
    if #available(iOS 17, *) {
        return AnyShapeStyle(.separator)
    }
    return AnyShapeStyle(Color.gray.opacity(0.3))
}

private struct legacyChangeObserver<Value: Equatable>: ViewModifier {
    let value: Value
    let action: (Value, Value) -> Void

    @State private var previous: Value? = nil

    func body(content: Content) -> some View {
        content
            .onAppear { previous = value }
            .onChange(of: value) { newValue in
                action(previous ?? newValue, newValue)
                previous = newValue
            }
    }
}

#if !os(tvOS)
func pinchGesture(changed: @escaping (CGFloat) -> Void, ended: @escaping () -> Void) -> AnyGesture<Void> {
    if #available(iOS 17, *) {
        return AnyGesture(MagnifyGesture()
            .onChanged { changed($0.magnification) }
            .onEnded { _ in ended() }
            .map { _ in () })
    } else {
        return AnyGesture(MagnificationGesture()
            .onChanged { changed($0) }
            .onEnded { _ in ended() }
            .map { _ in () })
    }
}
#endif
