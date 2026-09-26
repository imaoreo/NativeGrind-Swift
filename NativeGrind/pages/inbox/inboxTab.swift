//
//  inboxTab.swift
//  NativeGrind
//
//  Created by Jay Brammeld on 24/09/2026.
//

import SwiftUI
import NativeGrindCore

/// Conversations and chat side by side on macOS and iPad landscape, a normal push stack everywhere else
struct inboxTab: View {
    @Binding var path: [protectedRoute]

    @State private var selection: inboxSelection? = Self.demoSelection

    #if DEBUG
    private static var forceSplit: Bool { demoMode.forceSplit }
    private static var demoSelection: inboxSelection? {
        demoMode.forceSplit ? inboxSelection(conversationId: "1000:2000", otherProfileId: 2000, title: "Alex") : nil
    }
    #else
    private static let forceSplit = false
    private static let demoSelection: inboxSelection? = nil
    #endif

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    var body: some View {
        #if os(macOS)
        splitView
        #elseif os(iOS)
        GeometryReader { geometry in
            if horizontalSizeClass == .regular && (geometry.size.width > geometry.size.height || Self.forceSplit) {
                splitView
            } else {
                stackView
            }
        }
        #else
        stackView
        #endif
    }

    private var stackView: some View {
        NavigationStack(path: $path) {
            protectedRoute.inbox
                .navigationDestination(for: protectedRoute.self) { route in
                    route
                }
        }
    }

    private var splitView: some View {
        NavigationSplitView {
            inboxView(selection: $selection)
                .navigationSplitViewColumnWidth(min: 280, ideal: 340, max: 420)
        } detail: {
            NavigationStack {
                if let selection {
                    chatView(
                        conversationId: selection.conversationId,
                        otherProfileId: selection.otherProfileId,
                        title: selection.title,
                        presentation: .split
                    )
                    // Fresh chat state per conversation
                    .id(selection.conversationId)
                } else {
                    emptyStateView(
                        "No Conversation Selected",
                        systemImage: "bubble.left.and.bubble.right",
                        description: Text("Pick a conversation from the list.")
                    )
                }
            }
        }
    }
}
