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
                        debugSettingsView()
                    } label: {
                        Label("Debug", systemImage: "ladybug")
                    }
                    
                    NavigationLink {
                        privacySettingsView()
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
