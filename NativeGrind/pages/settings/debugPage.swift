//
//  debugPage.swift
//  NativeGrind
//
//  Created by Jay Brammeld on 09/07/2026.
//

import SwiftUI

struct debugSettingsView: View {
    var body: some View {
        Form {
            #if os(iOS)
            Text("Debug")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top, 16)
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
        }
        .formStyle(.grouped)
    }
}
