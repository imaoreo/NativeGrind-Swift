//
//  albumView.swift
//  NativeGrind
//
//  Created by Jay Brammeld on 25/09/2026.
//

import SwiftUI
import NativeGrindCore

struct albumTarget: Identifiable, Hashable {
    let albumId: String
    let ownerProfileId: String?

    var id: String { albumId }
}

extension EnvironmentValues {
    @Entry var openAlbum: @MainActor (albumTarget) -> Void = { _ in }
}

struct albumView: View {
    let target: albumTarget

    @Environment(\.dismiss) private var dismiss

    @State private var snapshot: albumSnapshot? = nil
    @State private var hasLoaded = false
    @State private var selectedItem: albumItem? = nil

    #if os(macOS)
    private let columns = [GridItem(.adaptive(minimum: 160, maximum: 240), spacing: 8)]
    private let gridSpacing: CGFloat = 8
    #else
    private let columns = [GridItem(.adaptive(minimum: 110, maximum: 180), spacing: 4)]
    private let gridSpacing: CGFloat = 4
    #endif

    var body: some View {
        #if os(macOS)
        // Sheet toolbars end up as buttons along the bottom on macOS, so use a header instead
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .frame(minWidth: 560, idealWidth: 760, minHeight: 520, idealHeight: 720)
        .task { await load() }
        .sheet(item: $selectedItem) { item in
            albumItemViewer(items: snapshot?.items ?? [item], startId: item.id)
        }
        #else
        NavigationStack {
            content
                .navigationTitle("Album")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { dismiss() }
                    }
                }
        }
        .task { await load() }
        .fullScreenCover(item: $selectedItem) { item in
            albumItemViewer(items: snapshot?.items ?? [item], startId: item.id)
        }
        #endif
    }

    @ViewBuilder
    private var content: some View {
        if let snapshot {
            ScrollView {
                LazyVGrid(columns: columns, spacing: gridSpacing) {
                    ForEach(snapshot.items) { item in
                        albumThumbnail(item: item)
                            .onTapGesture { selectedItem = item }
                    }
                }
                .padding(gridSpacing)
            }
        } else if hasLoaded {
            emptyStateView(
                "Album Unavailable",
                systemImage: "photo.on.rectangle.angled",
                description: Text("It may have expired or been unshared, and there's no backup of it yet.")
            )
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    #if os(macOS)
    private var header: some View {
        HStack {
            Text("Album")
                .font(.headline)

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
            .help("Close")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.bar)
    }
    #endif

    private func load() async {
        snapshot = await albumController.shared.loadAlbum(albumId: target.albumId, ownerProfileId: target.ownerProfileId)
        hasLoaded = true
    }
}

private struct albumThumbnail: View {
    let item: albumItem

    @State private var isHovering = false

    #if os(macOS)
    private let cornerRadius: CGFloat = 10
    #else
    private let cornerRadius: CGFloat = 0
    #endif

    var body: some View {
        Color.gray.opacity(0.2)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                // A backup-only video has no still preview, just show the play icon
                if let url = item.previewURL, !(item.isVideo && item.thumbURL == nil) {
                    AsyncImage(url: url) { phase in
                        if case .success(let image) = phase {
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else if case .failure = phase {
                            Image(systemName: "photo").foregroundColor(.secondary)
                        } else {
                            ProgressView()
                        }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(alignment: .center) {
                if item.isVideo {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(.white, .black.opacity(0.4))
                }
                if item.isProcessing {
                    ProgressView()
                }
            }
            .overlay(alignment: .topTrailing) {
                if item.isOnlyInBackup {
                    Image(systemName: "server.rack")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(width: 24, height: 24)
                        .background(.black.opacity(0.55), in: Circle())
                        .padding(6)
                        .help("Only in the NativeServer backup")
                } else if let views = item.remainingViews, views >= 0 {
                    Label("\(views)", systemImage: "eye")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.black.opacity(0.55), in: Capsule())
                        .foregroundColor(.white)
                        .padding(6)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.white.opacity(isHovering ? 0.08 : 0))
            }
            .scaleEffect(isHovering ? 1.02 : 1)
            .animation(.easeOut(duration: 0.15), value: isHovering)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
            #if os(macOS)
            .onHover { isHovering = $0 }
            #endif
    }
}
