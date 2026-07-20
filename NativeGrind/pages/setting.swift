//
//  setting.swift
//  NativeGrind
//
//  Created by Jay Brammeld on 09/07/2026.
//

import SwiftUI
import NativeGrindCore

struct settingsView: View {
    @State private var showLogoutConfirm = false
    
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
                    
                Section {
                    Button(role: .destructive) {
                        sessionManager.shared.logout()
                    } label: {
                        Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                } header: {
                    Text("Account")
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    settingsView()
}
