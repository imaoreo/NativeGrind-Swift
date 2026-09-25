//
//  chatView.swift
//  NativeGrind
//
//  Created by Jay Brammeld on 24/09/2026.
//

import SwiftUI
import PhotosUI
import NativeGrindCore

enum chatPresentation {
    case pushed // inside the inbox navigation stack on iPhone
    case sheet // opened from a profile, has its own header
    case split // detail pane of the inbox split view on macOS / iPad landscape
}

enum chatViewSheet: Identifiable {
    case sendMedia(chatOutgoingMedia)
    case drawer
    case sharedMedia

    var id: String {
        switch self {
        case .sendMedia(let media): "media-\(media.id)"
        case .drawer: "drawer"
        case .sharedMedia: "sharedMedia"
        }
    }
}

struct chatView: View {
    let title: String
    let presentation: chatPresentation

    @State private var store: chatStore
    @State private var draft = ""
    @State private var showProfile: identifiableId? = nil
    @State private var confirmSendLocation = false
    @State private var audioPlayer = chatAudioPlayer()
    @State private var viewingPhoto: chatMessage? = nil
    @State private var openedAlbum: albumTarget? = nil
    @State private var viewingVideo: chatMessage? = nil
    @State private var activeSheet: chatViewSheet? = nil
    @State private var isPreparingMedia = false
    #if !os(tvOS)
    @State private var showMediaPicker = false
    @State private var pickedItem: PhotosPickerItem? = nil
    @State private var showFileImporter = false
    #endif
    #if !os(tvOS)
    @State private var recorder = chatAudioRecorder()
    #endif

    @ObservedObject private var sockets = wsController.shared
    @Environment(\.dismiss) private var dismiss

    init(conversationId: String, otherProfileId: Int, title: String, presentation: chatPresentation = .pushed) {
        self.title = title
        self.presentation = presentation
        self._store = State(initialValue: chatStore(conversationId: conversationId, otherProfileId: otherProfileId))
    }

    private var canReply: Bool {
        sockets.connectedDomains.contains(.main)
    }

    private var isSocketConnected: Bool {
        sockets.connectedDomains.contains(.main)
    }

    private let pollInterval: Duration = .seconds(5)

    private var displayName: String {
        if !title.isEmpty { return title }
        if let name = store.otherProfile?.name, !name.isEmpty { return name }
        return "Someone"
    }

    var body: some View {
        VStack(spacing: 0) {
            if presentation == .sheet {
                chatHeader(title: displayName, mediaHash: store.otherProfile?.mediaHash, onShowProfile: showOtherProfile, onClose: { dismiss() })
                Divider()
            }
            chatMessageList(store: store, canReply: canReply, otherName: displayName)
            chatComposer(
                draft: $draft,
                isSending: store.isSending || isPreparingMedia,
                replyingTo: store.replyingTo,
                recordingStartedAt: recordingStartedAt,
                actions: composerActions
            )
        }
        .navigationTitle(displayName)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        // The split view keeps the tab bar, only a pushed chat takes over the screen
        .toolbar(presentation == .pushed ? .hidden : .automatic, for: .tabBar)
        #endif
        .toolbar {
            if !store.sharedMedia.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        activeSheet = .sharedMedia
                    } label: {
                        Image(systemName: "photo.on.rectangle")
                    }
                    .help("Shared Media")
                }
            }
            if presentation != .sheet {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: showOtherProfile) {
                        Image(systemName: "person.crop.circle")
                    }
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
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .sendMedia(let media):
                chatMediaSendSheet(media: media) { viewOnce in
                    Task { await store.sendMedia(media, viewOnce: viewOnce) }
                }
            case .drawer:
                chatMediaDrawer(store: store)
            case .sharedMedia:
                chatSharedMedia(store: store)
            }
        }
        #if !os(tvOS)
        .photosPicker(isPresented: $showMediaPicker, selection: $pickedItem, matching: .any(of: [.images, .videos]))
        .onChange(of: pickedItem) { _, item in
            guard let item else { return }
            pickedItem = nil
            Task { await prepare(item) }
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.image, .movie]) { result in
            guard case .success(let file) = result else { return }
            Task { await prepare(file) }
        }
        #endif
        .sheetWithToast(item: $showProfile) { item in
            profileDetailView(profileId: item.id, allowsMessaging: false)
        }
        .task {
            await store.loadInitial()
        }
        .task(id: isSocketConnected) {
            guard !isSocketConnected else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: pollInterval)
                guard !Task.isCancelled else { break }
                await store.refreshLatest()
            }
        }
        .onChange(of: isSocketConnected) { _, connected in
            if connected {
                Task { await store.refreshLatest() }
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
        .environment(\.openChatPhoto) { message in
            viewingPhoto = message
        }
        .environment(\.openAlbum) { target in
            openedAlbum = target
        }
        .environment(\.openChatVideo) { message in
            viewingVideo = message
        }
        .environment(\.loadChatVideo) { [store] message in
            await store.videoFile(for: message)
        }
        .sheet(item: $openedAlbum) { target in
            albumView(target: target)
        }
        .environment(\.loadChatImage) { [store] message in
            await store.imageData(for: message)
        }
        .environment(\.revealExpiringImage) { [store] message in
            await store.revealExpiringImage(message)
        }
        #if os(macOS)
        .sheet(item: $viewingPhoto) { message in
            chatPhotoViewer(message: message, loadImage: store.imageData)
        }
        .sheet(item: $viewingVideo) { message in
            chatVideoViewer(message: message, loadVideo: store.videoFile)
        }
        #else
        .fullScreenCover(item: $viewingPhoto) { message in
            chatPhotoViewer(message: message, loadImage: store.imageData)
        }
        .fullScreenCover(item: $viewingVideo) { message in
            chatVideoViewer(message: message, loadVideo: store.videoFile)
        }
        #endif
        .onAppear {
            audioPlayer.resolveURL = { [store] message in
                await store.mediaURL(for: message)
            }
        }
        .onDisappear {
            audioPlayer.stop()
            #if !os(tvOS)
            recorder.cancel()
            #endif
        }
    }

    #if !os(tvOS)
    private func prepare(_ item: PhotosPickerItem) async {
        isPreparingMedia = true
        defer { isPreparingMedia = false }
        present(await chatOutgoingMedia.load(from: item))
    }

    private func prepare(_ file: URL) async {
        isPreparingMedia = true
        defer { isPreparingMedia = false }
        present(await chatOutgoingMedia.loadPicked(file: file))
    }

    private func present(_ media: chatOutgoingMedia?) {
        guard let media else {
            toastManager.shared.show(style: .error, header: "Media", message: "Couldn't read that photo or video")
            return
        }
        activeSheet = .sendMedia(media)
    }
    #endif

    private func showOtherProfile() {
        showProfile = identifiableId(id: String(store.otherProfileId))
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
            pickMedia: nil,
            chooseFile: nil,
            openDrawer: { activeSheet = .drawer },
            startRecording: nil,
            cancelRecording: {},
            finishRecording: {}
        )

        #if !os(tvOS)
        actions.pickMedia = { showMediaPicker = true }
        actions.chooseFile = { showFileImporter = true }
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
