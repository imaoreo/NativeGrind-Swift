//
//  profilePhotoViewer.swift
//  NativeGrind
//
//  Created by Jay Brammeld on 26/09/2026.
//

import SwiftUI
import NativeGrindCore

struct profilePhotoGallery: Identifiable {
    let hashes: [String]
    let startIndex: Int

    var id: String { "\(startIndex)-\(hashes.joined())" }
}

struct profilePhotoViewer: View {
    let hashes: [String]

    @Environment(\.dismiss) private var dismiss

    @State private var currentHash: String?
    @State private var isZoomed = false

    init(gallery: profilePhotoGallery) {
        self.hashes = gallery.hashes
        let start = gallery.hashes.indices.contains(gallery.startIndex) ? gallery.startIndex : 0
        self._currentHash = State(initialValue: gallery.hashes.isEmpty ? nil : gallery.hashes[start])
    }

    private var currentIndex: Int? {
        hashes.firstIndex { $0 == currentHash }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            pager
        }
        .overlay(alignment: .top) {
            topBar
        }
        #if os(macOS)
        .overlay {
            arrows
        }
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(.leftArrow) { move(by: -1); return .handled }
        .onKeyPress(.rightArrow) { move(by: 1); return .handled }
        .frame(minWidth: 640, idealWidth: 900, minHeight: 520, idealHeight: 700)
        #elseif os(tvOS)
        .focusable()
        .onMoveCommand { direction in
            if direction == .left { move(by: -1) }
            if direction == .right { move(by: 1) }
        }
        #endif
        .onChangeCompat(of: currentHash) { _, _ in
            isZoomed = false
        }
    }

    @ViewBuilder
    private var pager: some View {
        #if os(iOS)
        if #available(iOS 17, *) {
            scrollPager
        } else {
            TabView(selection: $currentHash) {
                ForEach(hashes, id: \.self) { hash in
                    profilePhotoPage(mediaHash: hash, isCurrent: hash == currentHash, isZoomed: $isZoomed)
                        .tag(Optional(hash))
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        #else
        scrollPager
        #endif
    }

    @available(iOS 17, *)
    private var scrollPager: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(hashes, id: \.self) { hash in
                    profilePhotoPage(mediaHash: hash, isCurrent: hash == currentHash, isZoomed: $isZoomed)
                        .containerRelativeFrame([.horizontal, .vertical])
                        .id(hash)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $currentHash)
        .scrollIndicators(.hidden)
        .scrollDisabled(isZoomed)
    }

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(.black.opacity(0.5), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
            #if !os(tvOS)
            .keyboardShortcut(.cancelAction)
            #endif

            Spacer()

            if let currentIndex, hashes.count > 1 {
                Text("\(currentIndex + 1) / \(hashes.count)")
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.5), in: Capsule())
                    .accessibilityLabel("Photo \(currentIndex + 1) of \(hashes.count)")
            }

            Spacer()

            Color.clear.frame(width: 44, height: 44)
        }
        .padding(16)
    }

    #if os(macOS)
    private var arrows: some View {
        HStack {
            arrowButton(systemImage: "chevron.left", label: "Previous Photo", enabled: (currentIndex ?? 0) > 0) { move(by: -1) }
            Spacer()
            arrowButton(systemImage: "chevron.right", label: "Next Photo", enabled: (currentIndex ?? 0) < hashes.count - 1) { move(by: 1) }
        }
        .padding(.horizontal, 16)
    }

    private func arrowButton(systemImage: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(.black.opacity(0.5), in: Circle())
        }
        .buttonStyle(.plain)
        .opacity(enabled ? 1 : 0)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }
    #endif

    private func move(by offset: Int) {
        guard let currentIndex, !isZoomed else { return }
        let next = currentIndex + offset
        guard hashes.indices.contains(next) else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            currentHash = hashes[next]
        }
    }
}

private struct profilePhotoPage: View {
    let mediaHash: String
    let isCurrent: Bool
    @Binding var isZoomed: Bool

    @State private var image: Image? = nil
    @State private var failed = false
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1

    var body: some View {
        Group {
            if let image {
                image
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    #if !os(tvOS)
                    .gesture(
                        pinchGesture { setScale(min(max(lastScale * $0, 1), 5)) } ended: { lastScale = scale }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.spring(duration: 0.3)) {
                            setScale(scale > 1 ? 1 : 2.5)
                            lastScale = scale
                        }
                    }
                    #endif
                    .accessibilityLabel("Profile photo")
            } else if failed {
                emptyStateView("Couldn't Load Photo", systemImage: "photo")
                    .foregroundStyle(.white)
            } else {
                ProgressView().tint(.white)
            }
        }
        .task(id: mediaHash) {
            guard image == nil else { return }
            if let data = await profileController.shared.fetchProfileImage(size: .size2048, mediaHash: mediaHash),
               let platformImage = PlatformImage(data: data) {
                image = Image(platformImage: platformImage)
            } else {
                failed = true
            }
        }
        .onChangeCompat(of: isCurrent) { _, current in
            if !current {
                scale = 1
                lastScale = 1
            }
        }
    }

    private func setScale(_ newScale: CGFloat) {
        scale = newScale
        if isCurrent {
            isZoomed = newScale > 1
        }
    }
}
