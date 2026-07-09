//
//  debugPage.swift
//  NativeGrind
//
//  Created by Jay Brammeld on 09/07/2026.
//

import SwiftUI

enum NotifyMeAboutType: String, Hashable {
    case directMessages, mentions, anything
}

struct debugSettingsView: View {
    @State private var notifyMeAbout: NotifyMeAboutType = .anything
    @State private var playNotificationSounds = true
    @State private var sendReadReceipts = false
    
    var body: some View {
        Form {
            #if os(iOS)
            Text("Debug")
                .font(.largeTitle)
                .fontWeight(.bold)

                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 16))
            #endif
            
            Section(header: Text("Connection Information")) {
                LabeledContent {
                    Text("Online")
                        .foregroundColor(.green)
                } label: {
                    Label("Connected Status", systemImage: "network")
                }
                
                LabeledContent {
                    Text("OAuth")
                        .foregroundColor(.secondary)
                } label: {
                    Label("Authentication", systemImage: "lock.shield.fill")
                }
            }
            
            Section(header: Text("Native Grind")) {
                LabeledContent {
                    Text("Maximum")
                        .foregroundColor(.secondary)
                } label: {
                    Label("Cool Factor", systemImage: "sunglasses.fill")
                }
                
                LabeledContent {
                    Text("Slaying")
                        .fontWeight(.semibold)
                        .foregroundColor(.purple)
                } label: {
                    Label("Yas Status", systemImage: "sparkles")
                }
            }
            
            Section(header: Text("Notifications")) {
                Picker("Notify Me About", selection: $notifyMeAbout) {
                    Text("Direct Messages").tag(NotifyMeAboutType.directMessages)
                    Text("Mentions").tag(NotifyMeAboutType.mentions)
                    Text("Anything").tag(NotifyMeAboutType.anything)
                }
                Toggle("Play notification sounds", isOn: $playNotificationSounds)
                Toggle("Send read receipts", isOn: $sendReadReceipts)
            }
        }
        .formStyle(.grouped)
    }
}
