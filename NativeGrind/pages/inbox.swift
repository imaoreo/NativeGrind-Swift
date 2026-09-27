//
//  inbox.swift
//  NativeGrind
//
//  Created by Jay Brammeld on 02/07/2026.
//

import SwiftUI
import NativeGrindCore

struct inboxItem: Identifiable {
    let id: String
    let conversation: conversationData
    let profile: profile?
    
    init(conversation: conversationData, profile: profile?) {
        self.id = conversation.conversationId
        self.conversation = conversation
        self.profile = profile
    }
}

/// What the split view needs to open a chat in the detail pane
struct inboxSelection: Hashable {
    let conversationId: String
    let otherProfileId: Int
    let title: String
}

struct inboxView: View {
    /// When set the rows select into this for a split view instead of pushing the chat
    let selection: Binding<inboxSelection?>?

    @State private var items: [inboxItem] = []
    @State private var isLoading = false

    init(selection: Binding<inboxSelection?>? = nil) {
        self.selection = selection
    }

    /// Sidebar of the split view on macOS / iPad landscape
    private var isSplit: Bool {
        selection != nil
    }

    private var showsRefreshButton: Bool {
        #if os(macOS)
        return true
        #elseif os(iOS)
        return isSplit
        #else
        return false
        #endif
    }

    var body: some View {
        VStack(spacing: 0) {
            #if os(iOS)
            // Only bind selection in the split view, a selection binding on the push list gets in the way of the links
            Group {
                if let selection {
                    List(selection: selection) { iOSListContent }
                } else {
                    List { iOSListContent }
                }
            }
            .listStyle(.plain)
            
            #else
            if isLoading && items.isEmpty {
                Spacer()
                ProgressView()
                Spacer()
            } else if items.isEmpty {
                Spacer()
                Text("No conversations")
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                Group {
                    if let selection {
                        List(items, selection: selection) { item in listRow(for: item) }
                    } else {
                        List(items) { item in listRow(for: item) }
                    }
                }
                .listStyle(.plain)
                .refreshable {
                    await loadInboxData()
                }
            }
            #endif
        }
        .navigationTitle("Inbox")
        #if os(iOS)
        .navigationBarTitleDisplayMode(isSplit ? .inline : .large)
        .refreshable {
            await loadInboxData()
        }
        #endif
        .toolbar {
            settingsToolbarButton()

            if showsRefreshButton {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await loadInboxData() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .task {
            await loadInboxData()
        }
        .onReceive(wsController.shared.publisher(for: .onChatMessage)) { _ in
            Task { await loadInboxData() }
        }
        .onReceive(wsController.shared.publisher(for: .onConversationsUpdated)) { _ in
            Task { await loadInboxData() }
        }
        .onReceive(wsController.shared.publisher(for: .onConversationsDeleted)) { event in
            let deleted = Set(event.conversationIds.map(\.value))
            items.removeAll { deleted.contains($0.id) }
        }
    }

    private func listRow(for item: inboxItem) -> some View {
        conversationLink(for: item)
            .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
    }

    #if os(iOS)
    @ViewBuilder
    private var iOSListContent: some View {
        if isLoading && items.isEmpty {
            HStack {
                Spacer()
                ProgressView()
                    .padding(.top, 20)
                Spacer()
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
        else if items.isEmpty {
            VStack {
                Spacer()
                Text("No conversations")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            }
            .frame(minHeight: 300)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
        else {
            ForEach(items) { item in
                listRow(for: item)
            }
        }
    }
    #endif

    @ViewBuilder
    private func openableRow(for item: inboxItem, otherProfileId: Int) -> some View {
        let row = inboxRow(conversation: item.conversation, profile: item.profile)

        if selection != nil {
            // Must be the non-optional type to match List(selection: Binding<inboxSelection?>)
            row.tag(inboxSelection(
                conversationId: item.conversation.conversationId,
                otherProfileId: otherProfileId,
                title: item.conversation.name
            ))
        } else {
            NavigationLink {
                chatView(
                    conversationId: item.conversation.conversationId,
                    otherProfileId: otherProfileId,
                    title: item.conversation.name
                )
            } label: {
                row
            }
        }
    }

    @ViewBuilder
    private func conversationLink(for item: inboxItem) -> some View {
        if let otherProfileId = item.conversation.participants.first?.profileId {
            openableRow(for: item, otherProfileId: otherProfileId)
            #if !os(tvOS) && !os(macOS)
            .swipeActions(edge: .leading) {
                Button {
                    Task { await setPinned(item, pinned: !item.conversation.pinned) }
                } label: {
                    Label(item.conversation.pinned ? "Unpin" : "Pin", systemImage: item.conversation.pinned ? "pin.slash" : "pin")
                }
                .tint(.orange)
            }
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    Task { await deleteConversation(item) }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            #endif
            .contextMenu {
                Button {
                    Task { await setPinned(item, pinned: !item.conversation.pinned) }
                } label: {
                    Label(item.conversation.pinned ? "Unpin" : "Pin", systemImage: item.conversation.pinned ? "pin.slash" : "pin")
                }
                Button(role: .destructive) {
                    Task { await deleteConversation(item) }
                } label: {
                    Label("Delete Conversation", systemImage: "trash")
                }
            }
        } else {
            inboxRow(conversation: item.conversation, profile: item.profile)
        }
    }

    private func setPinned(_ item: inboxItem, pinned: Bool) async {
        if await conversationController.shared.setPinned(conversationId: item.id, pinned: pinned) {
            await loadInboxData()
        }
    }

    private func deleteConversation(_ item: inboxItem) async {
        if await conversationController.shared.deleteConversation(conversationId: item.id) {
            items.removeAll { $0.id == item.id }
            if selection?.wrappedValue?.conversationId == item.id {
                selection?.wrappedValue = nil
            }
        }
    }

    private func loadInboxData() async {
        isLoading = true
        defer { isLoading = false }
        
        if let fetched = await inboxController.shared.fetchInboxes(depth: 3) {
            var currentItems = self.items
            
            for raw in fetched {
                let newItem = inboxItem(conversation: raw.conversation, profile: raw.profile)
                guard !newItem.id.isEmpty else { continue }
                
                if let index = currentItems.firstIndex(where: { $0.id == newItem.id }) {
                    currentItems[index] = newItem
                } else {
                    currentItems.append(newItem)
                }
            }
            
            self.items = currentItems.sorted { lhs, rhs in
                if lhs.conversation.pinned != rhs.conversation.pinned {
                    return lhs.conversation.pinned
                }
                return lhs.conversation.lastActivityTimestamp > rhs.conversation.lastActivityTimestamp
            }
        }
    }
}

struct inboxAvatarView: View {
    let conversation: conversationData
    
    @State private var avatarImage: Image? = nil
    @State private var hasLoaded = false
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 48, height: 48)
            
            if let avatarImage {
                avatarImage
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                let displayName = conversation.name.isEmpty ? "Someone" : conversation.name
                Text(String(displayName.prefix(1)).uppercased())
                    .font(.headline)
                    .foregroundColor(.primary)
            }
        }
        .task(id: conversation.participants.first?.primaryMediaHash) {
            guard let mediaHash = conversation.participants.first?.primaryMediaHash, !mediaHash.isEmpty else { return }
            if hasLoaded { return }
            
            if let data = await profileController.shared.fetchProfileImage(size: .size2048, mediaHash: mediaHash) {
                if let platformImage = PlatformImage(data: data) {
                    self.avatarImage = Image(platformImage: platformImage)
                }
            }
            hasLoaded = true
        }
    }
}

struct inboxRow: View {
    let conversation: conversationData
    let profile: profile?
    
    func getPreview() -> String {
        guard let preview = conversation.preview else {
            return ""
        }

        if let text = preview.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return text
        }

        if preview.type == .albumContentReaction || preview.albumContentReply != nil {
            return "Album Reaction"
        }
        
        if preview.photoContentReply != nil {
            return "Photo Reaction"
        }

        if let imageHash = preview.imageHash, !imageHash.isEmpty {
            return "📷 Photo"
        }

        if preview.duration != nil {
            return "🎤 Audio Message"
        }

        if preview.lat != nil && preview.lon != nil {
            return "📍 Location"
        }

        if preview.albumId != nil {
            return "Shared Album"
        }

        return ""
    }
    
    var body: some View {
        HStack(spacing: 16) {
            inboxAvatarView(conversation: conversation)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    let displayName = conversation.name.isEmpty ? "Someone" : conversation.name
                    Text(displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()

                    if conversation.pinned {
                        Image(systemName: "pin.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .rotationEffect(.degrees(45))
                            .accessibilityLabel("Pinned")
                    }
                    
                    if conversation.unreadCount > 0 {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 8, height: 8)
                    }
                }
                
                Text(getPreview())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
    }
}
