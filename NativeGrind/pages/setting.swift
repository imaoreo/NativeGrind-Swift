//
//  setting.swift
//  NativeGrind
//
//  Created by Jay Brammeld on 09/07/2026.
//

import SwiftUI
import NativeGrindCore

struct settingsView: View {
    var showsDoneButton = false

    @State private var showLogoutConfirm = false
    @Environment(\.dismiss) private var dismiss
    
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
                        showLogoutConfirm = true
                    } label: {
                        Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                } header: {
                    Text("Account")
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                if showsDoneButton {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
            }
            .alert("Log Out", isPresented: $showLogoutConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Log Out", role: .destructive) {
                    Task {
                        await sessionManager.shared.logout()
                    }
                }
            } message: {
                Text("Are you sure you want to log out?")
            }
        }
    }
}

struct settingsToolbarButton: ToolbarContent {
    @EnvironmentObject private var router: navigationRouter

    var body: some ToolbarContent {
        #if os(iOS)
        ToolbarItem(placement: .topBarLeading) {
            Button {
                router.showingSettings = true
            } label: {
                Image(systemName: "gearshape")
            }
            .accessibilityLabel("Settings")
        }
        #endif
    }
}

#Preview {
    settingsView()
}
