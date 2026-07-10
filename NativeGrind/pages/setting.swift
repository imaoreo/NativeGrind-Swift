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
