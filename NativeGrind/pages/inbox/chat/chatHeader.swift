//
//  chatHeader.swift
//  NativeGrind
//
//  Created by Jay Brammeld on 24/09/2026.
//

import SwiftUI
import NativeGrindCore

struct chatHeader: View {
    let title: String
    let mediaHash: String?
    let onShowProfile: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onShowProfile) {
                HStack(spacing: 10) {
                    chatAvatar(name: title, mediaHash: mediaHash)

                    Text(title)
                        .font(.headline)
                        .lineLimit(1)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Button(action: onShowProfile) {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("View Profile")

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            #if !os(tvOS)
            .keyboardShortcut(.cancelAction)
            #endif
            .help("Close")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        #if !os(tvOS)
        .background(.bar)
        #endif
    }
}

/// Their profile photo, falling back to the first letter of their name while loading or if they have none
private struct chatAvatar: View {
    let name: String
    let mediaHash: String?

    @State private var image: Image? = nil

    var body: some View {
        ZStack {
            if let image {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Text(String(name.prefix(1)).uppercased())
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.blue.gradient)
            }
        }
        .frame(width: 34, height: 34)
        .clipShape(Circle())
        .task(id: mediaHash) {
            image = nil
            guard let mediaHash, !mediaHash.isEmpty,
                  let data = await profileController.shared.fetchProfileImage(size: .size320, mediaHash: mediaHash),
                  let platformImage = PlatformImage(data: data) else {
                return
            }
            image = Image(platformImage: platformImage)
        }
    }
}
