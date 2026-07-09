//
//  privacySetting.swift
//  NativeGrind
//
//  Created by Jay Brammeld on 09/07/2026.
//

import SwiftUI

struct privacySettingView: View {
    @State private var shareDiagnostics = false
        
    var body: some View {
        Form {
            #if os(iOS)
            Text("Privacy & Security")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 16))
            #endif
            
            Section {
                Toggle("Share Analytics", isOn: $shareDiagnostics)
            } footer: {
                Text("Help us improve the app by sharing usage data.")
            }
        }
        .formStyle(.grouped)
    }
}
