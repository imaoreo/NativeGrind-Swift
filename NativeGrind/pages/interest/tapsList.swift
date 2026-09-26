//
//  tapsList.swift
//  NativeGrind
//
//  Created by Jay Brammeld on 25/09/2026.
//

import SwiftUI
import NativeGrindCore

struct tapsList: View {
    @State private var taps: [tapProfileV2]? = nil
    @State private var isLoading = false
    @State private var selectedProfile: identifiableId? = nil

    var body: some View {
        Group {
            if let taps {
                if taps.isEmpty {
                    emptyStateView("No Taps Yet", systemImage: "flame", description: Text("Taps you receive show up here."))
                } else {
                    list(taps)
                }
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                emptyStateView("Couldn't Load Taps", systemImage: "flame", description: Text("Pull to try again."))
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
        .onReceive(wsController.shared.publisher(for: .onTap)) { _ in
            Task { await load() }
        }
        .sheetWithToast(item: $selectedProfile) { item in
            profileDetailView(profileId: item.id)
        }
    }

    private func list(_ taps: [tapProfileV2]) -> some View {
        List {
            Section {
                ForEach(taps) { tap in
                    Button {
                        selectedProfile = identifiableId(id: tap.profileId)
                    } label: {
                        interestRow(
                            name: tap.displayName ?? "Someone",
                            mediaHash: tap.profileImageMediaHash,
                            details: [interestRow<EmptyView>.distanceText(tap.distance), interestRow<EmptyView>.agoText(tap.date)].compactMap { $0 },
                            isOnline: tap.isOnline
                        ) {
                            trailing(for: tap)
                        }
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text(taps.count == 1 ? "1 tap" : "\(taps.count) taps")
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #endif
    }

    @ViewBuilder
    private func trailing(for tap: tapProfileV2) -> some View {
        HStack(spacing: 10) {
            Text(Self.emoji(for: tap.tapType))
                .font(.title2)
        }
    }

    static func emoji(for type: tapType) -> String {
        switch type {
            case .friendly: return "👋"
            case .hot: return "🔥"
            case .looking: return "😈"
            case .none: return ""
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        if let fresh = await interestController.shared.fetchTaps() {
            taps = fresh
        }
    }
}
