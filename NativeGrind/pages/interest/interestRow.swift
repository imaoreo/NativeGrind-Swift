//
//  interestRow.swift
//  NativeGrind
//
//  Created by Jay Brammeld on 25/09/2026.
//

import SwiftUI
import NativeGrindCore

struct interestRow<Trailing: View>: View {
    let name: String
    let mediaHash: String?
    let details: [String]
    var isOnline = false
    var isBlurred = false
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 14) {
            interestAvatar(name: name, mediaHash: mediaHash, isBlurred: isBlurred)
                .overlay(alignment: .bottomTrailing) {
                    if isOnline {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 12, height: 12)
                            .overlay(Circle().stroke(Color(white: 0.1), lineWidth: 2))
                    }
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.headline)
                    .lineLimit(1)

                if !details.isEmpty {
                    Text(details.joined(separator: " · "))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            trailing()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    static func distanceText(_ meters: Double?) -> String? {
        guard let meters else { return nil }
        return Measurement(value: meters, unit: UnitLength.meters)
            .formatted(.measurement(width: .abbreviated, usage: .road))
    }

    static func agoText(_ date: Date?) -> String? {
        date?.formatted(.relative(presentation: .named))
    }
}

struct interestAvatar: View {
    let name: String
    let mediaHash: String?
    var isBlurred = false

    @State private var image: Image? = nil

    var body: some View {
        ZStack {
            if let image {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Text(isBlurred ? "?" : String(name.prefix(1)).uppercased())
                    .font(.headline)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.gray.opacity(0.2))
            }
        }
        .frame(width: 52, height: 52)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .task(id: mediaHash) {
            guard let mediaHash, !mediaHash.isEmpty,
                  let data = await profileController.shared.fetchProfileImage(size: .size2048, mediaHash: mediaHash),
                  let platformImage = PlatformImage(data: data) else {
                return
            }
            image = Image(platformImage: platformImage)
        }
    }
}
