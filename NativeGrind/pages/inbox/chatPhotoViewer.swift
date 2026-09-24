//
//  chatPhotoViewer.swift
//  NativeGrind
//
//  Created by Jay Brammeld on 24/09/2026.
//

import SwiftUI
import NativeGrindCore

extension EnvironmentValues {
    @Entry var openChatPhoto: @MainActor (chatMessage) -> Void = { _ in }
}

struct chatPhotoViewer: View {
    let message: chatMessage
    let loadImage: (chatMessage) async -> Data?

    @Environment(\.dismiss) private var dismiss

    @State private var image: Image? = nil
    @State private var failed = false

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var dismissOffset: CGFloat = 0

    private let maxScale: CGFloat = 5
    private let doubleTapScale: CGFloat = 2.5
    private let dismissDistance: CGFloat = 120

    var body: some View {
        ZStack {
            Color.black
                .opacity(1 - min(abs(dismissOffset) / 400, 0.6))
                .ignoresSafeArea()

            content
        }
        .overlay(alignment: .top) {
            toolbar
        }
        .task {
            await load()
        }
        #if os(macOS)
        .frame(minWidth: 640, idealWidth: 900, minHeight: 520, idealHeight: 700)
        #endif
    }

    @ViewBuilder
    private var content: some View {
        if let image {
            image
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .offset(x: offset.width, y: offset.height + dismissOffset)
                #if !os(tvOS)
                .gesture(dragGesture.simultaneously(with: magnifyGesture))
                .onTapGesture(count: 2) {
                    withAnimation(.spring(duration: 0.3)) {
                        if scale > 1 {
                            resetZoom()
                        } else {
                            scale = doubleTapScale
                            lastScale = doubleTapScale
                        }
                    }
                }
                #endif
        } else if failed {
            ContentUnavailableView("Couldn't Load Photo", systemImage: "photo")
                .foregroundStyle(.white)
        } else {
            ProgressView()
                .tint(.white)
        }
    }

    private var toolbar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(.black.opacity(0.5), in: Circle())
            }
            .buttonStyle(.plain)
            #if !os(tvOS)
            .keyboardShortcut(.cancelAction)
            #endif

            Spacer()

            #if !os(tvOS)
            if let image {
                ShareLink(item: image, preview: SharePreview("Photo", image: image)) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(.black.opacity(0.5), in: Circle())
                }
                .buttonStyle(.plain)
            }
            #endif
        }
        .padding(16)
        .opacity(dismissOffset == 0 ? 1 : 0)
    }

    #if !os(tvOS)
    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                scale = min(max(lastScale * value.magnification, 1), maxScale)
            }
            .onEnded { _ in
                lastScale = scale
                if scale <= 1 {
                    withAnimation(.spring(duration: 0.3)) { resetZoom() }
                }
            }
    }

    // Pans when zoomed in, otherwise a vertical drag dismisses
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if scale > 1 {
                    offset = CGSize(
                        width: lastOffset.width + value.translation.width,
                        height: lastOffset.height + value.translation.height
                    )
                } else {
                    dismissOffset = value.translation.height
                }
            }
            .onEnded { _ in
                if scale > 1 {
                    lastOffset = offset
                } else if abs(dismissOffset) > dismissDistance {
                    dismiss()
                } else {
                    withAnimation(.spring(duration: 0.3)) { dismissOffset = 0 }
                }
            }
    }
    #endif

    private func resetZoom() {
        scale = 1
        lastScale = 1
        offset = .zero
        lastOffset = .zero
    }

    private func load() async {
        guard let data = await loadImage(message),
              let platformImage = PlatformImage(data: data) else {
            failed = true
            return
        }

        #if canImport(UIKit)
        image = Image(uiImage: platformImage)
        #elseif canImport(AppKit)
        image = Image(nsImage: platformImage)
        #endif
    }
}
