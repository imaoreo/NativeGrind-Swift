//
//  viewersList.swift
//  NativeGrind
//
//  Created by Jay Brammeld on 25/09/2026.
//

import SwiftUI
import NativeGrindCore

struct viewersList: View {
    @State private var response: viewsResponseV7? = nil
    @State private var isLoading = false
    @State private var selectedProfile: identifiableId? = nil

    private var viewers: [profileViewsResponseV7] {
        (response?.profiles ?? []).sorted { ($0.lastViewed ?? 0) > ($1.lastViewed ?? 0) }
    }

    var body: some View {
        Group {
            if let response {
                if response.profiles.isEmpty && response.previews.isEmpty {
                    ContentUnavailableView("No Views Yet", systemImage: "eye", description: Text("People who view your profile show up here."))
                } else {
                    list(response)
                }
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView("Couldn't Load Views", systemImage: "eye.slash", description: Text("Pull to try again."))
            }
        }
        .refreshable {
            await load()
        }
        #if os(macOS)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await load() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        #endif
        .task {
            await load()
        }
        .onReceive(wsController.shared.publisher(for: .onNewView)) { _ in
            Task { await load() }
        }
        .sheetWithToast(item: $selectedProfile) { item in
            profileDetailView(profileId: item.id)
        }
    }

    private func list(_ response: viewsResponseV7) -> some View {
        List {
            Section {
                ForEach(viewers) { viewer in
                    Button {
                        selectedProfile = identifiableId(id: viewer.profileId)
                    } label: {
                        interestRow(
                            name: viewer.displayName ?? "Someone",
                            mediaHash: viewer.profileImageMediaHash,
                            details: details(for: viewer),
                            isOnline: viewer.isOnline
                        ) {
                            badges(for: viewer)
                        }
                    }
                    .buttonStyle(.plain)
                }

                ForEach(Array(response.previews.enumerated()), id: \.offset) { _, preview in
                    interestRow(
                        name: preview.isSecretAdmirer ? "Secret admirer" : "Hidden viewer",
                        mediaHash: preview.profileImageMediaHash,
                        details: [interestRow<EmptyView>.distanceText(preview.distance), interestRow<EmptyView>.agoText(preview.lastViewedDate)].compactMap { $0 },
                        isBlurred: true
                    ) {
                        EmptyView()
                    }
                }
            } header: {
                Text(response.totalViewers == 1 ? "1 viewer" : "\(response.totalViewers) viewers")
            } footer: {
                if !response.previews.isEmpty {
                    Text("Grindr only shows who these are on paid accounts.")
                }
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #endif
    }

    private func details(for viewer: profileViewsResponseV7) -> [String] {
        [
            viewer.showAge ? viewer.age.map(String.init) : nil,
            viewer.showDistance ? interestRow<EmptyView>.distanceText(viewer.distance) : nil,
            interestRow<EmptyView>.agoText(viewer.lastViewedDate)
        ].compactMap { $0 }
    }

    @ViewBuilder
    private func badges(for viewer: profileViewsResponseV7) -> some View {
        HStack(spacing: 6) {
            if let count = viewer.viewedCount?.totalCount, count > 1 {
                Text("×\(count)")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
            }
            if viewer.isFavorite {
                Image(systemName: "star.fill").foregroundColor(.yellow)
            }
            if viewer.isNew {
                Text("NEW")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue, in: Capsule())
                    .foregroundColor(.white)
            }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        if let fresh = await interestController.shared.fetchViews() {
            response = fresh
        }
    }
}
