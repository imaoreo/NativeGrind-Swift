//
//  chatView.swift
//  NativeGrind
//
//  Created by Jay Brammeld on 24/09/2026.
//

import SwiftUI
import NativeGrindCore

struct chatView: View {
    let title: String

    @State private var store: chatStore
    @State private var draft = ""
    @State private var showProfile: identifiableId? = nil
    @State private var confirmSendLocation = false
    @State private var audioPlayer = chatAudioPlayer()
    #if !os(tvOS)
    @State private var recorder = chatAudioRecorder()
    #endif

    @ObservedObject private var sockets = wsController.shared

    init(conversationId: String, otherProfileId: Int, title: String) {
        self.title = title
        self._store = State(initialValue: chatStore(conversationId: conversationId, otherProfileId: otherProfileId))
    }

    private var canReply: Bool {
        sockets.connectedDomains.contains(.main)
    }

    private var pollInterval: Duration {
        sockets.connectedDomains.contains(.main) ? .seconds(30) : .seconds(5)
    }

    var body: some View {
        VStack(spacing: 0) {
            chatMessageList(store: store, canReply: canReply, otherName: title.isEmpty ? "Someone" : title)
            Divider()
            chatComposer(
                draft: $draft,
                isSending: store.isSending,
                replyingTo: store.replyingTo,
                recordingStartedAt: recordingStartedAt,
                actions: composerActions
            )
        }
        .navigationTitle(title.isEmpty ? "Someone" : title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showProfile = identifiableId(id: String(store.otherProfileId))
                } label: {
                    Image(systemName: "person.crop.circle")
                }
            }
        }
        .confirmationDialog("Send your current location?", isPresented: $confirmSendLocation, titleVisibility: .visible) {
            Button("Send Location") {
                Task { await store.sendCurrentLocation() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("They'll see a pin where you are right now.")
        }
        .sheetWithToast(item: $showProfile) { item in
            profileDetailView(profileId: item.id, allowsMessaging: false)
        }
        .task {
            await store.loadInitial()
            while !Task.isCancelled {
                try? await Task.sleep(for: pollInterval)
                guard !Task.isCancelled else { break }
                await store.refreshLatest()
            }
        }
        .onReceive(sockets.publisher(for: .onChatMessage)) { store.receive($0) }
        .onReceive(sockets.publisher(for: .onConversationRead)) { store.receive($0) }
        .onReceive(sockets.publisher(for: .onTypingStatus)) { store.receive($0) }
        .onChange(of: canReply) { _, canReply in
            if !canReply {
                store.cancelReply()
            }
        }
        .onChange(of: draft) { oldValue, newValue in
            let wasEmpty = oldValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let isEmpty = newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            guard wasEmpty != isEmpty else { return }
            Task { await store.setTyping(!isEmpty) }
        }
        .environment(audioPlayer)
        .onAppear {
            audioPlayer.resolveURL = { [store] message in
                await store.playableURL(for: message)
            }
        }
        .onDisappear {
            audioPlayer.stop()
            #if !os(tvOS)
            recorder.cancel()
            #endif
        }
    }

    private var recordingStartedAt: Date? {
        #if os(tvOS)
        return nil
        #else
        return recorder.startedAt
        #endif
    }

    private var composerActions: chatComposerActions {
        var actions = chatComposerActions(
            send: {
                Task {
                    if await store.send(draft) {
                        draft = ""
                    }
                }
            },
            cancelReply: store.cancelReply,
            sendLocation: { confirmSendLocation = true },
            startRecording: nil,
            cancelRecording: {},
            finishRecording: {}
        )

        #if !os(tvOS)
        actions.startRecording = {
            Task { await recorder.start() }
        }
        actions.cancelRecording = recorder.cancel
        actions.finishRecording = {
            guard let recording = recorder.finish() else { return }
            Task { await store.sendAudio(recording.data, contentType: chatAudioRecorder.contentType, lengthMs: recording.lengthMs) }
        }
        #endif

        return actions
    }
}
