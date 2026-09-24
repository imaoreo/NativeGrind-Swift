//
//  profileDetailView.swift
//  NativeGrind
//

import SwiftUI
import NativeGrindCore

struct profileDetailView: View {
    let profiles: [CascadeResponseProfile]?
    let allowsMessaging: Bool
    @State private var profileId: String
    @State private var chatTarget: chatSheetTarget? = nil
    
    @State private var fullProfile: profile? = nil
    @State private var isLoading = true
    @State private var heroImage: Image? = nil
    
    @Environment(\.dismiss) private var dismiss
    
    init(profileId: String, profiles: [CascadeResponseProfile]? = nil, allowsMessaging: Bool = true) {
        self.profiles = profiles
        self.allowsMessaging = allowsMessaging
        self._profileId = State(initialValue: profileId)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                heroSection
                
                if isLoading {
                    ProgressView("Loading Profile...")
                        .padding(.top, 40)
                } else if let profile = fullProfile {
                    VStack(alignment: .leading, spacing: 24) {
                        aboutMeSection(profile: profile)
                        tagsSection(profile: profile)
                        statsSection(profile: profile)
                    }
                    .padding(20)
                }
            }
        }
        .scrollIndicators(.hidden)
        .ignoresSafeArea(.container, edges: .top)
        #if !os(tvOS)
        .gesture(
            DragGesture(minimumDistance: 25, coordinateSpace: .local)
                .onEnded { value in
                    let horizontalTranslation = value.translation.width
                    let verticalTranslation = value.translation.height
                    
                    guard abs(horizontalTranslation) > abs(verticalTranslation) else { return }
                    
                    if horizontalTranslation < -45 {
                        navigateProfile(forward: true)
                    } else if horizontalTranslation > 45 {
                        navigateProfile(forward: false)
                    }
                }
            
        )
        #else
        .focusable()
        .onMoveCommand { direction in
            switch direction {
            case .left:
                navigateProfile(forward: true)
            case .right:
                navigateProfile(forward: false)
            case .up, .down:
                break
            @unknown default:
                break
            }
        }
        #endif
        .task(id: profileId) {
            await fetchFullProfile()
        }
        .sheetWithToast(item: $chatTarget) { target in
            chatSheet(target: target)
        }
    }

    private func openChat() {
        guard let ownProfileId = sessionManager.shared.profileId, let otherProfileId = Int(profileId) else {
            toastManager.shared.show(style: .error, header: "Chat Error", message: "Couldn't find your profile id, try logging in again")
            return
        }

        chatTarget = chatSheetTarget(
            id: conversationController.conversationId(between: ownProfileId, and: otherProfileId),
            otherProfileId: otherProfileId,
            title: fullProfile?.displayName ?? ""
        )
    }
    
    private func navigateProfile(forward: Bool) {
        guard let profiles = profiles,
              let currentIndex = profiles.firstIndex(where: { String($0.profileId) == profileId }) else {
            return
        }
        
        let nextIndex = forward ? currentIndex + 1 : currentIndex - 1
        guard nextIndex >= 0 && nextIndex < profiles.count else { return }
        
        let nextProfile = profiles[nextIndex]
        
        withAnimation(.snappy(duration: 0.3)) {
            self.profileId = String(nextProfile.profileId)
        }
    }
    
    private var heroSection: some View {
            ZStack(alignment: .bottomLeading) {
                // Background Image
                if let heroImage {
                    heroImage
                        .resizable()
                        .scaledToFill()
                        .frame(maxHeight: 400)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 400)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 64))
                                .foregroundColor(.gray.opacity(0.5))
                        )
                }
                 
                // Gradient Overlay
                LinearGradient(
                    gradient: Gradient(colors: [.clear, .black.opacity(0.8)]),
                    startPoint: .center,
                    endPoint: .bottom
                )
                .frame(height: 400)
                 
                // Text Info
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(fullProfile?.displayName ?? (isLoading ? "Loading..." : "Unknown"))
                            .font(.largeTitle)
                            .fontWeight(.bold)
                         
                        if let age = fullProfile?.age {
                            Text("\(age)")
                                .font(.title2)
                                .fontWeight(.medium)
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                    .foregroundColor(.white)
                     
                    if let profile = fullProfile, let distance = profile.distance {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                            Text(formatDistance(distance, approximate: profile.approximateDistance))
                        }
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding()
            }
            .overlay(alignment: .top) {
                HStack {
                    #if os(iOS)
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 24, weight: .bold))
                            .padding(8)
                            .background(.black.opacity(0.4))
                            .foregroundColor(.white)
                            .clipShape(Circle())
                    }
                    #endif
                     
                    Spacer()
                     
                    HStack(spacing: 12) {
                        if allowsMessaging {
                            Button(action: openChat) {
                                Image(systemName: "bubble.left.fill")
                                    .font(.system(size: 24, weight: .bold))
                                    .padding(8)
                                    .background(.black.opacity(0.4))
                                    .foregroundColor(.white)
                                    .clipShape(Circle())
                            }
                        }

                        Button {
                            if !(fullProfile?.isFavorite ?? false) {
                                Task {
                                    _ = try? await APIClient.shared.request(.addFavorite(profileId: profileId))
                                    await fetchFullProfile()
                                }
                            } else {
                                Task {
                                    _ = try? await APIClient.shared.request(.removeFavorite(profileId: profileId))
                                    await fetchFullProfile()
                                }
                            }
                        } label: {
                            Image(systemName: fullProfile?.isFavorite ?? false ? "heart.fill" :"heart")
                                .font(.system(size: 24, weight: .bold))
                                .padding(8)
                                .background(.black.opacity(0.4))
                                .foregroundColor(fullProfile?.isFavorite ?? false ? .red : .white)
                                .clipShape(Circle())
                        }
                        
                        Button {
                            Task {
                                _ = try await APIClient.shared.request(.tap(profileId: profileId, tapType: .hot))
                                await fetchFullProfile()
                            }
                        } label: {
                            Image(systemName: fullProfile?.tapped ?? false ? "flame.fill" :"flame")
                                .font(.system(size: 24, weight: .bold))
                                .padding(8)
                                .background(.black.opacity(0.4))
                                .foregroundColor(fullProfile?.tapped ?? false ? .red : .white)
                                .clipShape(Circle())
                        }
                        .disabled(fullProfile?.tapped ?? false)
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
        }
    
    @ViewBuilder
    private func aboutMeSection(profile: profile) -> some View {
        if let about = profile.aboutMe?.trimmingCharacters(in: .whitespacesAndNewlines), !about.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("About Me")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text(about)
                    .font(.body)
                    .lineLimit(nil)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
            }
        }
    }
    
    @ViewBuilder
    private func statsSection(profile: profile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stats")
                .font(.headline)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 16) {
                
                if let height = profile.height {
                    statCell(icon: "lines.measurement.vertical", title: "Height", value: "\(Int(height)) cm")
                }
                
                if let weight = profile.weight {
                    statCell(icon: "scalemass", title: "Weight", value: formatWeight(weightGrams: weight))
                }
                
                if let position = profile.sexualPosition {
                    statCell(icon: "arrow.up.and.down", title: "Position", value: String(describing: position).capitalized)
                }
                
                if let bodyType = profile.bodyType {
                    statCell(icon: "figure.walk", title: "Body", value: String(describing: bodyType).capitalized)
                }
                
                if let ethnicity = profile.ethnicity {
                    statCell(icon: "globe.europe.africa", title: "Ethnicity", value: String(describing: ethnicity).capitalized)
                }
                
                if let relStatus = profile.relationshipStatus {
                    statCell(icon: "heart", title: "Relationship", value: String(describing: relStatus).capitalized)
                }
                
                if let nsfwStatus = profile.nsfw {
                    statCell(icon: "shield", title: "NSFW pics?", value: String(describing: nsfwStatus).capitalized)
                }
                
                if !profile.lookingFor.isEmpty {
                    let items = profile.lookingFor.map { String(describing: $0).capitalized }
                    let formattedString: String = {
                        if items.count == 1 { return items[0] }
                        else if items.count == 2 { return "\(items[0]) and \(items[1])" }
                        else { return "\(items.dropLast().joined(separator: ", ")), and \(items.last!)" }
                    }()
                    
                    statCell(icon: "eye", title: "Looking For", value: formattedString)
                }
                
                if !profile.grindrTribes.isEmpty {
                    let items = profile.grindrTribes.map { String(describing: $0).capitalized }
                    let formattedString: String = {
                        if items.count == 1 { return items[0] }
                        else if items.count == 2 { return "\(items[0]) and \(items[1])" }
                        else { return "\(items.dropLast().joined(separator: ", ")), and \(items.last!)" }
                    }()
                    
                    statCell(icon: "person.3", title: "Tribes", value: formattedString)
                }
                
                if let tribes = profile.tribesImInto, !tribes.isEmpty {
                    let items = tribes.map { String(describing: $0).capitalized }
                    let formattedString: String = {
                        if items.count == 1 { return items[0] }
                        else if items.count == 2 { return "\(items[0]) and \(items[1])" }
                        else { return "\(items.dropLast().joined(separator: ", ")), and \(items.last!)" }
                    }()
                    
                    statCell(icon: "magnifyingglass", title: "Into Tribes", value: formattedString)
                }
                
                if let hiv = profile.hivStatus {
                    statCell(icon: "exclamationmark.shield", title: "HIV Status", value: String(describing: hiv).capitalized)
                }
                
                var formattedHivDate: String? {
                    guard let hivDate = profile.lastTestedDate else { return nil }
                    let date = Date(timeIntervalSince1970: TimeInterval(hivDate/1000))
                    let formatter = DateFormatter()
                    formatter.dateStyle = .medium
                    formatter.timeStyle = .none
                    return formatter.string(from: date)
                }

                if let dateString = formattedHivDate {
                    statCell(icon: "calendar", title: "Last Tested Date", value: dateString)
                }
                
                if let meetAt = profile.meetAt, !meetAt.isEmpty {
                    let items = meetAt.map { String(describing: $0).capitalized }
                    let formattedString: String = {
                        if items.count == 1 { return items[0] }
                        else if items.count == 2 { return "\(items[0]) and \(items[1])" }
                        else { return "\(items.dropLast().joined(separator: ", ")), and \(items.last!)" }
                    }()
                    
                    statCell(icon: "door.right.hand.open", title: "Meet At", value: formattedString)
                }
    
                
                if !profile.sexualHealth.isEmpty {
                    let items = profile.sexualHealth.map { String(describing: $0).capitalized }
                    let formattedString: String = {
                        if items.count == 1 { return items[0] }
                        else if items.count == 2 { return "\(items[0]) and \(items[1])" }
                        else { return "\(items.dropLast().joined(separator: ", ")), and \(items.last!)" }
                    }()
                    
                    statCell(icon: "cross", title: "Sexual Practices", value: formattedString)
                }

                
                statCell(icon: "number.sign", title: "Profile Id", value: String(describing: profile.profileId).capitalized, allowCopying: true)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    private func statCell(icon: String, title: String, value: String, allowCopying: Bool = false) -> some View {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(.primary)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(value)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                guard allowCopying else { return }
                
                #if os(iOS)
                UIPasteboard.general.string = value
                #elseif os(macOS)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(value, forType: .string)
                #endif
                
                toastManager.shared.show(style: .info, header: "Copied", message: "Copied \(title.lowercased()) to clipboard")
            }
        }
    
    @ViewBuilder
    private func tagsSection(profile: profile) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if !profile.profileTags.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Profile Tags")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    wrappingTags(items: profile.profileTags.map { String(describing: $0).capitalized }, color: .yellow)
                }
            }
        }
    }
    
    private func fetchFullProfile() async {
        isLoading = true
        self.fullProfile = nil
        self.heroImage = nil
        
        if let profile = await profileController.shared.fetchProfile(profileId: profileId) {
            self.fullProfile = profile
            
            if let profileImage = profile.profileImageMediaHash {
                if let data = await profileController.shared.fetchProfileImage(size: .size2048, mediaHash: profileImage),
                   let platformImage = PlatformImage(data: data) {
                    
                    #if canImport(UIKit)
                    self.heroImage = Image(uiImage: platformImage)
                    #elseif canImport(AppKit)
                    self.heroImage = Image(nsImage: platformImage)
                    #endif
                }
            }
        }
        
        isLoading = false
    }
    
    private func wrappingTags(items: [String], color: Color) -> some View {
        flowLayout(spacing: 8) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(color.opacity(0.15))
                    .foregroundColor(color)
                    .cornerRadius(16)
            }
        }
    }
    
    private func formatWeight(weightGrams: Double) -> String {
        let kg = weightGrams / 1000.0
        return String(format: "%.1f kg", kg)
    }
    
    private func formatDistance(_ distance: Double, approximate: Bool) -> String {
        let prefix = approximate ? "~" : ""
        
        if distance < 1000.0 {
            return String(format: "%@%.0fm away", prefix, distance)
        } else {
            let km = distance / 1000.0
            return String(format: "%@%.1f km away", prefix, km)
        }
    }
}

struct chatSheetTarget: Identifiable {
    let id: String // conversation id
    let otherProfileId: Int
    let title: String
}

private struct chatSheet: View {
    let target: chatSheetTarget

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            chatView(conversationId: target.id, otherProfileId: target.otherProfileId, title: target.title)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") {
                            dismiss()
                        }
                    }
                }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 520)
        #endif
    }
}
