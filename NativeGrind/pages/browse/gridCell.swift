//
//  gridCell.swift
//  NativeGrind
//

import SwiftUI
import NativeGrindCore

struct gridCell: View {
    let profile: CascadeResponseProfile
    
    @State private var image: Image? = nil
    @State private var hasLoaded = false
    
    private var isOnline: Bool {
        guard let onlineUntil = profile.onlineUntil else { return false }
        return TimeInterval(onlineUntil) > Date().timeIntervalSince1970
    }
    
    private var mediaHash: String? {
        if let urlString = profile.primaryImageUrl, let url = URL(string: urlString) {
            return url.lastPathComponent
        }
        return profile.photoMediaHashes?.first
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                // Profile Image
                Group {
                    if let image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                    } else {
                        Color.gray.opacity(0.15)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.gray)
                            )
                    }
                }
                
                LinearGradient(
                    colors: [.clear, .black.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 48)
                
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(profile.displayName ?? "Someone")\(profile.age != nil ? ", \(profile.age!)" : "")")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        if let distance = profile.distanceMeters {
                            Text(formatDistance(distance))
                                .font(.system(size: 9))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    
                    Spacer()
                    
                    // Online dot
                    if isOnline {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 1)
                            )
                            .padding(.bottom, 2)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 6)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.1), lineWidth: 1)
            )
            .task(id: mediaHash) {
                self.image = nil
                hasLoaded = false
                guard let mediaHash, !mediaHash.isEmpty else { return }
                
                if let data = await profileController.shared.fetchProfileImage(size: .size2048, mediaHash: mediaHash) {
                    if let platformImage = PlatformImage(data: data) {
                        #if canImport(UIKit)
                            self.image = Image(uiImage: platformImage)
                        #elseif canImport(AppKit)
                            self.image = Image(nsImage: platformImage)
                        #endif
                    }
                }
                hasLoaded = true
            }
        }
    }
    
    private func formatDistance(_ meters: Int) -> String {
        if meters < 1000 {
            return "\(meters)m"
        } else {
            let km = Double(meters) / 1000.0
            return String(format: "%.1fkm", km)
        }
    }
}
