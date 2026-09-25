//
//  albumItemViewer.swift
//  NativeGrind
//
//  Created by Jay Brammeld on 25/09/2026.
//

import SwiftUI
import AVKit
import NativeGrindCore

struct albumItemViewer: View {
    let items: [albumItem]

    @Environment(\.dismiss) private var dismiss

    @State private var currentId: String?
    @State private var isZoomed = false

    init(items: [albumItem], startId: String) {
        self.items = items
        self._currentId = State(initialValue: startId)
    }

    private var currentIndex: Int? {
        items.firstIndex { $0.id == currentId }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(items) { item in
                        albumPage(item: item, isCurrent: item.id == currentId, isZoomed: $isZoomed)
                            .containerRelativeFrame([.horizontal, .vertical])
                            .id(item.id)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $currentId)
            .scrollIndicators(.hidden)
            .scrollDisabled(isZoomed)
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
        .onChange(of: currentId) { _, _ in
            isZoomed = false
        }
    }

    private var topBar: some View {
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

            if let currentIndex, items.count > 1 {
                Text("\(currentIndex + 1) / \(items.count)")
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.5), in: Capsule())
            }

            Spacer()

            Color.clear.frame(width: 40, height: 40)
        }
        .padding(16)
    }

    #if os(macOS)
    private var arrows: some View {
        HStack {
            arrowButton(systemImage: "chevron.left", enabled: (currentIndex ?? 0) > 0) { move(by: -1) }
            Spacer()
            arrowButton(systemImage: "chevron.right", enabled: (currentIndex ?? 0) < items.count - 1) { move(by: 1) }
        }
        .padding(.horizontal, 16)
    }

    private func arrowButton(systemImage: String, enabled: Bool, action: @escaping () -> Void) -> some View {
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
    }
    #endif

    private func move(by offset: Int) {
        guard let currentIndex, !isZoomed else { return }
        let next = currentIndex + offset
        guard items.indices.contains(next) else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            currentId = items[next].id
        }
    }

}

private struct albumPage: View {
    let item: albumItem
    let isCurrent: Bool
    @Binding var isZoomed: Bool

    @State private var player: AVPlayer? = nil
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1

    var body: some View {
        Group {
            if let url = item.bestURL {
                if item.isVideo {
                    video(url)
                } else {
                    photo(url)
                }
            } else {
                ContentUnavailableView("Not Available", systemImage: "photo")
                    .foregroundStyle(.white)
            }
        }
        .onChange(of: isCurrent) { _, current in
            if current {
                player?.play()
            } else {
                player?.pause()
                scale = 1
                lastScale = 1
            }
        }
    }

    private func video(_ url: URL) -> some View {
        VideoPlayer(player: player)
            .onAppear {
                if player == nil {
                    player = AVPlayer(url: url)
                }
                if isCurrent {
                    player?.play()
                }
            }
            .onDisappear { player?.pause() }
    }

    private func photo(_ url: URL) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    #if !os(tvOS)
                    .gesture(
                        MagnifyGesture()
                            .onChanged { setScale(min(max(lastScale * $0.magnification, 1), 5)) }
                            .onEnded { _ in lastScale = scale }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.spring(duration: 0.3)) {
                            setScale(scale > 1 ? 1 : 2.5)
                            lastScale = scale
                        }
                    }
                    #endif
            case .failure:
                ContentUnavailableView("Couldn't Load Photo", systemImage: "photo")
                    .foregroundStyle(.white)
            default:
                ProgressView().tint(.white)
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
