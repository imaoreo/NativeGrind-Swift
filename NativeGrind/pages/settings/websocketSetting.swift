//
//  websocketSetting.swift
//  NativeGrind
//
//  Created by Jay Brammeld on 09/07/2026.
//

import SwiftUI
import Combine
import NativeGrindCore

struct websocketLogEntry: Identifiable {
    let id = UUID()
    let timestamp = Date()
    let domain: wsDomain
    let message: String
}

struct websocketsSettingView: View {
    @StateObject private var controller = wsController.shared
    @State private var logs: [websocketLogEntry] = []
    @State private var wantLogin = true
    @State private var customApiKey = ""
    @State private var customSessionId = ""
    
    var body: some View {
        Form {
            Section(header: Text("Websocket Connections")) {
                connectionRow(domain: .main, displayName: "Grindr Main WS")
                #if INCLUDE_SERVER
                connectionRow(domain: .nativeServer, displayName: "Native Server WS")
                #endif
            }
            
            Section(header: HStack {
                Text("Received Messages")
                Spacer()
                Button("Clear") {
                    logs.removeAll()
                }
                .font(.caption)
            }) {
                if logs.isEmpty {
                    Text("No messages received yet")
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    ForEach(logs) { log in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(log.domain == .main ? "Main" : "Server")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(log.domain == .main ? .blue : .green)
                                Spacer()
                                Text(log.timestamp, style: .time)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Text(log.message)
                                .font(.system(.footnote, design: .monospaced))
                                .textSelection(.enabled)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("WebSocket Test")
        .formStyle(.grouped)
        .onReceive(wsController.shared.incomingDataPublisher) { tuple in
            let domain = tuple.domain
            let data = tuple.data
            let messageString: String
            if let str = String(data: data, encoding: .utf8) {
                messageString = str
            } else {
                messageString = "Binary Data (\(data.count) bytes)"
            }
            
            let entry = websocketLogEntry(domain: domain, message: messageString)
            logs.insert(entry, at: 0) // Show latest at the top
        }
    }
    
    private func connectionRow(domain: wsDomain, displayName: String) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(displayName)
                    .font(.body)
                Text(domain.rawValue)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            let isConnected = controller.connectedDomains.contains(domain)
            
            Text(isConnected ? "Connected" : "Disconnected")
                .font(.footnote)
                .foregroundColor(isConnected ? .green : .red)
                .padding(.trailing, 8)
            
            Button(isConnected ? "Disconnect" : "Connect") {
                if isConnected {
                    wsController.shared.disconnect(domain: domain)
                } else {
                    wsController.shared.connect(to: domain)
                }
            }
            .buttonStyle(.bordered)
            .tint(isConnected ? .red : .blue)
        }
    }
    
    private func logAction(domain: wsDomain, _ text: String) {
        let entry = websocketLogEntry(domain: domain, message: text)
        logs.insert(entry, at: 0)
    }
}

#Preview {
    NavigationStack {
        websocketsSettingView()
    }
}
