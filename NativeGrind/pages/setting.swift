//
//  setting.swift
//  NativeGrind
//
//  Created by Jay Brammeld on 09/07/2026.
//

import SwiftUI

struct settingsView: View {
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    #if INCLUDE_SERVER
                        NavigationLink {
                            nsAccountSettingView()
                        } label: {
                            Label("NS Account", systemImage: "person.crop.circle.badge.checkmark")
                        }
                    #endif

                    NavigationLink {
                        debugSettingView()
                    } label: {
                        Label("Debug", systemImage: "ladybug")
                    }
                    
                    NavigationLink {
                        websocketsSettingView()
                    } label: {
                        Label("WebSockets", systemImage: "network")
                    }
                    
                    NavigationLink {
                        privacySettingView()
                    } label: {
                        Label("Privacy & Security", systemImage: "lock.shield")
                    }
                } header: {
                    Text("General")
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    settingsView()
}
