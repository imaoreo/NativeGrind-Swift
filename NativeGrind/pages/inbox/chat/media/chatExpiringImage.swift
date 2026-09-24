//
//  chatExpiringImage.swift
//  NativeGrind
//
//  Created by Jay Brammeld on 24/09/2026.
//

import SwiftUI
import NativeGrindCore

struct chatExpiringImage: View {
    let message: chatMessage
    let size: CGSize

    @Environment(\.loadChatImage) private var loadImage
    @Environment(\.revealExpiringImage) private var reveal
    @Environment(\.openChatPhoto) private var openPhoto

    @State private var image: Image? = nil
    @State private var isChecking = true
    @State private var isRevealing = false
    @State private var failed = false
    @State private var confirmReveal = false

    var body: some View {
        Group {
            if let image {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.height)
                    .clipped()
                    .contentShape(Rectangle())
                    .onTapGesture { openPhoto(message) }
            } else {
                placeholder
            }
        }
        .confirmationDialog("View Expiring Photo?", isPresented: $confirmReveal, titleVisibility: .visible) {
            Button("View Photo") {
                Task { await revealPhoto() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This photo can only be opened once. It'll be saved on this device and backed up to NativeServer.")
        }
        .task(id: message.id) {
            if let data = await loadImage(message) {
                show(data)
            }
            isChecking = false
        }
    }

    private var placeholder: some View {
        VStack(spacing: 8) {
            if isChecking || isRevealing {
                ProgressView()
            } else {
                Image(systemName: failed ? "exclamationmark.triangle" : "eye.slash")
                    .font(.title2)
            }

            Text("Expiring Photo")
                .font(.subheadline.weight(.semibold))

            Text(failed ? "Couldn't open this photo" : "Tap to view")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(width: size.width, height: size.height)
        .background(Color.gray.opacity(0.25))
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isChecking, !isRevealing, !failed else { return }
            confirmReveal = true
        }
    }

    private func revealPhoto() async {
        isRevealing = true
        defer { isRevealing = false }

        guard let data = await reveal(message) else {
            failed = true
            return
        }
        show(data)
    }

    private func show(_ data: Data) {
        guard let platformImage = PlatformImage(data: data) else { return }
        image = Image(platformImage: platformImage)
    }
}
