//
//  chatMessageSummary.swift
//  NativeGrind
//
//  Created by Jay Brammeld on 24/09/2026.
//

import NativeGrindCore

extension chatMessage {
    var summaryText: String {
        if unsent == true {
            return "This message was unsent"
        }

        switch type {
        case .text:
            return body?.text ?? ""
        case .image, .expiringImage:
            return "📷 Photo"
        case .giphy:
            return "GIF"
        case .gaymoji:
            return "Gaymoji"
        case .audio:
            if let length = body?.length {
                return "🎤 Audio Message (\(Int(length / 1000))s)"
            }
            return "🎤 Audio Message"
        case .video, .privateVideo, .nonExpiringVideo:
            return "🎥 Video"
        case .location:
            return "📍 Location"
        case .album, .expiringAlbum, .expiringAlbumV2:
            return "🗂️ Shared Album"
        case .albumContentReaction:
            return "🔥 Reacted to album"
        case .albumContentReply:
            return "Album Reply: \(body?.albumContentReply ?? "")"
        case .profilePhotoReply:
            return "Photo Reply: \(body?.photoContentReply ?? "")"
        case .videoCall:
            if let result = body?.result {
                return "📞 Video Call · \(result)"
            }
            return "📞 Video Call"
        case .retract:
            return "This message was unsent"
        case .profileLink:
            return "Profile Link"
        case .generative, .unknown:
            return "Unsupported message"
        }
    }
}
