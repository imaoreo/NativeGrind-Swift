//
//  mutiSelector.swift
//  NativeGrind
//
//  Created by Jay Brammeld on 17/08/2026.
//

import SwiftUI

struct MultiSelectPicker<T: Hashable & CaseIterable>: View {
    let title: String
    @Binding var selection: [T]?

    var displayString: (T) -> String = { String(describing: $0).capitalized }
    
    var body: some View {
        NavigationLink {
            List {
                ForEach(Array(T.allCases), id: \.self) { item in
                    let isSelected = selection?.contains(item) ?? false
                    
                    Button {
                        toggleSelection(for: item)
                    } label: {
                        HStack {
                            Text(displayString(item))
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle(title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        } label: {
            LabeledContent(title) {
                if let selection = selection, !selection.isEmpty {
                    Text(selection.count == 1 ? displayString(selection.first!) : "\(selection.count) Selected")
                } else {
                    Text("Any")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private func toggleSelection(for item: T) {
        var current = selection ?? []
        if current.contains(item) {
            current.removeAll { $0 == item }
        } else {
            current.append(item)
        }
        selection = current.isEmpty ? nil : current
    }
}
