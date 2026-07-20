//
//  nsAccountSetting.swift
//  NativeGrind
//
//  Created by Jay Brammeld on 19/07/2026.
//

import SwiftUI
import NativeGrindCore
import Combine

public struct nsAccountSettingView: View {
    @StateObject private var controller = wsController.shared
    
    @State private var accountKey: String? = keychainManager.shared.getToken(type: .accountKey)
    @State private var currentDeviceId: String? = keychainManager.shared.getToken(type: .deviceId)
    @State private var devices: [device] = []
    
    @State private var isLoading = false
    @State private var statusMessage: String?
    @State private var showCreateConfirm = false

    public init() {}

    public var body: some View {
        Form {
            #if os(iOS)
            Text("NS Account")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 16))
            #endif

            Section(header: Text("Account Details")) {
                if let key = accountKey, !key.isEmpty {
                    LabeledContent {
                        Text("Active")
                            .foregroundColor(.green)
                            .fontWeight(.semibold)
                    } label: {
                        Label("Account Status", systemImage: "person.crop.circle.badge.checkmark")
                    }

                    LabeledContent {
                        Text(verbatim: key)
                            .foregroundColor(.secondary)
                    } label: {
                        Label("Account Key", systemImage: "key.fill")
                    }
                    
                    Button(role: .destructive) {
                        showCreateConfirm = true
                    } label: {
                        Label("Re-create Account", systemImage: "arrow.triangle.2.circlepath")
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No NS Account Found")
                            .font(.headline)
                        Text("Creating an account will generate a symmetric Account Key and allow linking multiple devices.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)

                    Button {
                        createAccountAction()
                    } label: {
                        HStack {
                            Spacer()
                            if isLoading {
                                ProgressView()
                            } else {
                                Label("Create Account", systemImage: "person.badge.plus")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .disabled(isLoading)
                }
            }

            if accountKey != nil {
                Section(header: HStack {
                    Text("Linked Devices (\(devices.count))")
                    Spacer()
                    Button {
                        fetchDevices()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .font(.caption)
                }) {
                    if devices.isEmpty {
                        Text("No devices linked yet")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach(devices) { dev in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(dev.name)
                                            .font(.body)
                                            .fontWeight(.medium)

                                        if dev.id == currentDeviceId {
                                            Text("This Device")
                                                .font(.caption2)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.blue.opacity(0.15))
                                                .foregroundColor(.blue)
                                                .cornerRadius(4)
                                        }
                                    }

                                    Text("Device ID: \(dev.id)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                if dev.id != currentDeviceId {
                                    Button(role: .destructive) {
                                        removeDeviceAction(dev.id)
                                    } label: {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }

            if let message = statusMessage {
                Section(header: Text("Status")) {
                    Text(message)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .onReceive(controller.publisher(for: .onAccountCreated)) { response in
            isLoading = false
            if response.status == .success {
                statusMessage = response.message
                accountKey = keychainManager.shared.getToken(type: .accountKey)
                fetchDevices()
            } else {
                statusMessage = "Account creation failed: \(response.message)"
            }
        }
        .onReceive(controller.publisher(for: .onDeviceList)) { response in
            if response.status == .success, let devList = response.devices {
                devices = devList
                statusMessage = nil
            } else {
                statusMessage = "Device fetch failed: \(response.message)"
            }
        }
        .onReceive(controller.publisher(for: .onDeviceRemoved)) { response in
            if response.status == .success {
                fetchDevices()
            }
        }
        .onReceive(controller.publisher(for: .onDeviceAdded)) { response in
            if response.status == .success {
                fetchDevices()
            }
        }
        .alert("Re-create Account", isPresented: $showCreateConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Re-create", role: .destructive) {
                createAccountAction()
            }
        } message: {
            Text("This will generate a new symmetric Account Key and register the account with the server.")
        }
        .onAppear {
            accountKey = keychainManager.shared.getToken(type: .accountKey)
            currentDeviceId = keychainManager.shared.getToken(type: .deviceId)
            if accountKey != nil {
                fetchDevices()
            }
        }
    }

    private func createAccountAction() {
        isLoading = true
        statusMessage = "Creating account..."
        
        let newAccountKey = cryptoController.shared.generateAccountKey()
        _ = keychainManager.shared.saveToken(newAccountKey, type: .accountKey)
        accountKey = newAccountKey
        
        wsController.shared.send(request: .createAccount())
    }

    private func fetchDevices() {
        wsController.shared.send(request: .listDevices())
    }

    private func removeDeviceAction(_ deviceId: String) {
        wsController.shared.send(request: .removeDevice(deviceId: deviceId))
    }
}

#Preview {
    nsAccountSettingView()
}
