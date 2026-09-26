//
//  demoChatView.swift
//  NativeGrind
//
//  Created by Jay Brammeld on 26/09/2026.
//

#if DEBUG
import SwiftUI
import NativeGrindCore

struct demoChatView: View {
    @StateObject private var store = demoChatView.makeStore()
    @StateObject private var audioPlayer = chatAudioPlayer()
    @State private var draft = ""

    private static let me = 1_000
    private static let alex = 2_000
    private static let conversationId = "1000:2000"

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                chatMessageList(store: store, canReply: true, otherName: "Alex")
                chatComposer(
                    draft: $draft,
                    isSending: false,
                    replyingTo: nil,
                    recordingStartedAt: nil,
                    actions: chatComposerActions(
                        send: {},
                        cancelReply: {},
                        sendLocation: {},
                        pickMedia: {},
                        chooseFile: {},
                        openDrawer: {},
                        startRecording: {},
                        cancelRecording: {},
                        finishRecording: {}
                    )
                )
            }
            .navigationTitle("Alex")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Image(systemName: "person.crop.circle")
                }
            }
        }
        .environmentObject(audioPlayer)
    }

    private static func makeStore() -> chatStore {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        func at(minutesAgo: Int64) -> Int64 { now - minutesAgo * 60_000 }

        let messages: [String] = [
            message("a", from: alex, at: at(minutesAgo: 52), type: "Text", body: #"{"text":"Hey! How's your week going?"}"#),
            message("b", from: me, at: at(minutesAgo: 50), type: "Text", body: #"{"text":"Pretty good, just finished work 🙌"}"#),
            message("c", from: alex, at: at(minutesAgo: 49), type: "Text", body: #"{"text":"Nice. Fancy grabbing a coffee later?"}"#),
            message("d", from: me, at: at(minutesAgo: 31), type: "Text", body: #"{"text":"Sounds great, where were you thinking?"}"#,
                    replyTo: message("c", from: alex, at: at(minutesAgo: 49), type: "Text", body: #"{"text":"Nice. Fancy grabbing a coffee later?"}"#)),
            message("e", from: alex, at: at(minutesAgo: 12), type: "Location", body: #"{"lat":55.9486,"lon":-3.1999}"#),
            message("f", from: alex, at: at(minutesAgo: 12), type: "Text", body: #"{"text":"This place does the best flat whites"}"#),
            message("g", from: me, at: at(minutesAgo: 4), type: "Text", body: #"{"text":"Perfect, see you at 4 ☕️"}"#, reactions: #"[{"profileId":2000,"reactionType":1}]"#),
            message("h", from: alex, at: at(minutesAgo: 1), type: "Audio", body: #"{"mediaId":1,"length":8000}"#),
        ]

        let decoded = messages.compactMap { json in
            try? JSONDecoder().decode(chatMessage.self, from: Data(json.utf8))
        }
        return chatStore.demo(conversationId: conversationId, otherProfileId: alex, messages: decoded, lastReadTimestamp: now)
    }

    private static func message(_ id: String, from sender: Int, at timestamp: Int64, type: String, body: String, reactions: String = "[]", replyTo: String? = nil) -> String {
        """
        {"messageId":"\(timestamp):demo-\(id)","conversationId":"\(conversationId)","senderId":\(sender),"timestamp":\(timestamp),"unsent":false,"reactions":\(reactions),"type":"\(type)","body":\(body),"replyToMessage":\(replyTo ?? "null")}
        """
    }
}
#endif
