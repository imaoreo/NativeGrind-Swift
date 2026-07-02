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
        NavigationStack {
            VStack {
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
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Inbox")
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
            .refreshable {
                await loadInboxData()
            }
            .task {
                await loadInboxData()
            }
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

struct inboxRow: View {
    let conversation: conversationData
    let profile: profile?
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 44, height: 44)
                
                let displayName = conversation.name
                Text(String(displayName.prefix(1)).uppercased())
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    
                    if conversation.unreadCount > 0 {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 8, height: 8)
                    }
                }
                
                Text(conversation.preview.text ?? "")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}
