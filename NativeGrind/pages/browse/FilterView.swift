import SwiftUI
import NativeGrindCore

struct filterView: View {
    @State private var draftFilters: GridFilters
    
    var onApply: (GridFilters) -> Void
    var onCancel: () -> Void
    
    init(filters: GridFilters, onApply: @escaping (GridFilters) -> Void, onCancel: @escaping () -> Void) {
        _draftFilters = State(initialValue: filters)
        self.onApply = onApply
        self.onCancel = onCancel
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Common Filters") {
                    Toggle("Online Only", isOn: $draftFilters.onlineOnly.toNonOptional)
                    Toggle("Photo Only", isOn: $draftFilters.photoOnly.toNonOptional)
                    Toggle("Face Only", isOn: $draftFilters.faceOnly.toNonOptional)
                    Toggle("Has Album", isOn: $draftFilters.hasAlbum.toNonOptional)
                    Toggle("Not Recently Chatted", isOn: $draftFilters.notRecentlyChatted.toNonOptional)
                    Toggle("Right Now", isOn: $draftFilters.rightNow.toNonOptional)
                }
                
                Section("Age, Height and Weight") {
                    RangeInputRow(
                        title: "Age",
                        minVal: $draftFilters.ageMin,
                        maxVal: $draftFilters.ageMax,
                        format: .number
                    )
                    
                    RangeInputRow(
                        title: "Height (cm)",
                        minVal: $draftFilters.heightCmMin,
                        maxVal: $draftFilters.heightCmMax,
                        format: .number
                    )
                    
                    RangeInputRow(
                        title: "Weight (kg)",
                        minVal: $draftFilters.weightGramsMin.gramsToKg,
                        maxVal: $draftFilters.weightGramsMax.gramsToKg,
                        format: .number
                    )
                }
                
                Section("Preferences") {
                    MultiSelectPicker(title: "Tribes", selection: $draftFilters.tribes)
                    MultiSelectPicker(title: "Looking For", selection: $draftFilters.lookingFor)
                    MultiSelectPicker(title: "Relationship Status", selection: $draftFilters.relationshipStatuses)
                    MultiSelectPicker(title: "Body Type", selection: $draftFilters.bodyTypes)
                    MultiSelectPicker(title: "Sexual Position", selection: $draftFilters.sexualPositions)
                    MultiSelectPicker(title: "Meet At", selection: $draftFilters.meetAt)
                    MultiSelectPicker(title: "NSFW Pics", selection: $draftFilters.nsfwPics)
                }
                
                Section("Extras") {
                    Toggle("Fresh", isOn: $draftFilters.fresh.toNonOptional)
                    Toggle("Favorites", isOn: $draftFilters.favorites.toNonOptional)
                    Toggle("Shuffle", isOn: $draftFilters.shuffle.toNonOptional)
                    Toggle("Hot", isOn: $draftFilters.hot.toNonOptional)
                }
            }
            .navigationTitle("Filters")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #elseif os(macOS)
            .formStyle(.grouped)
            .toggleStyle(.checkbox)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        onApply(draftFilters)
                    }
                    .keyboardShortcut(.defaultAction)
                }
                
                #if os(macOS)
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .keyboardShortcut(.cancelAction)
                }
                #endif
            }
        }
    }
}

extension Binding where Value == Bool? {
    var toNonOptional: Binding<Bool> {
        Binding<Bool>(
            get: { self.wrappedValue ?? false },
            set: { self.wrappedValue = $0 }
        )
    }
}
