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

struct inboxView: View {
    @State private var items: [inboxItem] = []
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 0) {
            #if os(iOS)
            List {
                Text("Inbox")
                    .font(.largeTitle.bold())
                    .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                
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
                        conversationLink(for: item)
                            .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
                    }
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
                List(items) { item in
                    conversationLink(for: item)
                        .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
                }
                .listStyle(.plain)
                .refreshable {
                    await loadInboxData()
                }
            }
            #endif
        }
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        .refreshable {
            await loadInboxData()
        }
        #else
        .navigationTitle("Inbox")
        #endif
        #if !os(iOS) && !os(watchOS) && !os(tvOS)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    Task {
                        await loadInboxData()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        #endif
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

    @ViewBuilder
    private func conversationLink(for item: inboxItem) -> some View {
        let row = inboxRow(conversation: item.conversation, profile: item.profile)

        if let otherProfileId = item.conversation.participants.first?.profileId {
            NavigationLink {
                chatView(
                    conversationId: item.conversation.conversationId,
                    otherProfileId: otherProfileId,
                    title: item.conversation.name
                )
            } label: {
                row
            }
            #if !os(tvOS)
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
            row
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
                    #if canImport(UIKit)
                        self.avatarImage = Image(uiImage: platformImage)
                    #elseif canImport(AppKit)
                        self.avatarImage = Image(nsImage: platformImage)
                    #endif
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
