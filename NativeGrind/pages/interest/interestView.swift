//
//  interestView.swift
//  NativeGrind
//
//  Created by Jay Brammeld on 25/09/2026.
//

import SwiftUI

enum interestTab: String, CaseIterable, Identifiable {
    case views = "Views"
    case taps = "Taps"

    var id: String { rawValue }
}

struct interestView: View {
    @State private var tab: interestTab = .views

    var body: some View {
        VStack(spacing: 0) {
            Picker("Show", selection: $tab) {
                ForEach(interestTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            switch tab {
            case .views:
                viewersList()
            case .taps:
                tapsList()
            }
        }
        .navigationTitle("Interest")
        .toolbar {
            settingsToolbarButton()
        }
    }
}
