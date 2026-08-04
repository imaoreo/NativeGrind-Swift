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
    @State private var showDeleteConfirm = false
    
    @State private var linkCodeInput = ""
    @State private var isLinking = false

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
                    
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete Account", systemImage: "arrow.triangle.2.circlepath")
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
                Section(header: Text("Link New Device")) {
                    HStack {
                        TextField("Enter 8-digit link code", text: $linkCodeInput)
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            #endif
                            .disableAutocorrection(true)
                        
                        Button {
                            linkDeviceAction()
                        } label: {
                            if isLinking {
                                ProgressView()
                            } else {
                                Text("Link")
                                    .fontWeight(.semibold)
                            }
                        }
                        .disabled(linkCodeInput.count != 8 || isLinking)
                    }
                }

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
        .onReceive(controller.publisher(for: wsEvent<nsDevicePublicKeyResponse>.onDevicePublicKey)) { response in
            if response.status == nsStatus.failed {
                isLinking = false
                statusMessage = "Link failed: \(response.message)"
            }
        }
        .onReceive(controller.publisher(for: .onDeviceLinked)) { response in
            isLinking = false
            if response.status == nsStatus.success {
                linkCodeInput = ""
                statusMessage = "Device linked successfully!"
                fetchDevices()
            } else {
                statusMessage = "Link failed: \(response.message)"
            }
        }
        .onReceive(controller.publisher(for: .onAccountDeleted)) { response in
            if (response.status == .success || response.message == "Device is not associated with any account") {
                isLoading = false
                keychainManager.shared.deleteToken(type: .accountKey)
                accountKey = nil
            } else {
                isLoading = false
                statusMessage = "Account deletion failed: \(response.message)"
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
        .alert("Delete Account", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteAccountAction()
            }
        } message: {
            Text("This will delete your NativeServer Account as well as all data associated with it.")
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
    
    private func deleteAccountAction() {
        isLoading = true
        statusMessage = "Deleting account..."
        
        wsController.shared.send(request: .deleteAccount())
    }

    private func fetchDevices() {
        wsController.shared.send(request: .listDevices())
    }

    private func removeDeviceAction(_ deviceId: String) {
        wsController.shared.send(request: .removeDevice(deviceId: deviceId))
    }

    private func linkDeviceAction() {
        guard linkCodeInput.count == 8 else { return }
        isLinking = true
        statusMessage = "Requesting device public key..."
        wsController.shared.send(request: .getPublicKey(code: linkCodeInput))
    }
}

#Preview {
    nsAccountSettingView()
}
