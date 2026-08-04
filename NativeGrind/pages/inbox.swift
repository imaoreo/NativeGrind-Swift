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
                        inboxRow(conversation: item.conversation, profile: item.profile)
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
                    inboxRow(conversation: item.conversation, profile: item.profile)
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
    }

    private func loadInboxData() async {
        isLoading = true
        if let fetched = await inboxController.shared.fetchInboxes(depth: 3) {
            self.items = fetched.map { item in
                inboxItem(conversation: item.conversation, profile: item.profile)
            }
        }
        isLoading = false
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
                
                Text(conversation.preview?.text ?? "")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
    }
}
