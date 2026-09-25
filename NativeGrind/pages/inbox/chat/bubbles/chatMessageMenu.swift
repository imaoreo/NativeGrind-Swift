//
//  chatMessageMenu.swift
//  NativeGrind
//
//  Created by Jay Brammeld on 24/09/2026.
//

import SwiftUI
import NativeGrindCore

struct chatMessageMenu: View {
    let message: chatMessage
    let store: chatStore
    let canReply: Bool

    private var isMine: Bool { store.isMine(message) }
    private var isUnsent: Bool { message.unsent == true }

    var body: some View {
        #if !os(tvOS)
        if let text = message.body?.text, !isUnsent {
            Button {
                copyToClipboard(text)
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
        }
        #endif

        if canReply && !isUnsent {
            Button {
                store.startReply(to: message)
            } label: {
                Label("Reply", systemImage: "arrowshape.turn.up.left")
            }
        }

        if !isMine && !isUnsent {
            Button {
                Task { await store.react(to: message) }
            } label: {
                Label("React 🔥", systemImage: "flame")
            }
        }

        if isMine && !isUnsent {
            Button(role: .destructive) {
                Task { await store.unsend(message) }
            } label: {
                Label("Unsend", systemImage: "arrow.uturn.backward")
            }
        }

        Button(role: .destructive) {
            Task { await store.delete(message) }
        } label: {
            Label("Delete for Me", systemImage: "trash")
        }
    }

    private func copyToClipboard(_ text: String) {
        #if canImport(UIKit) && !os(tvOS)
        UIPasteboard.general.string = text
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
}
