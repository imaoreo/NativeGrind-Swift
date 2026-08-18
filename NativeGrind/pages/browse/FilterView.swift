import SwiftUI
import NativeGrindCore

struct filterView: View {
    @Binding var filters: GridFilters
    
    var onDismiss: () -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Common Filters") {
                    Toggle("Online Only", isOn: $filters.onlineOnly.toNonOptional)
                    Toggle("Photo Only", isOn: $filters.photoOnly.toNonOptional)
                    Toggle("Face Only", isOn: $filters.faceOnly.toNonOptional)
                    Toggle("Has Album", isOn: $filters.hasAlbum.toNonOptional)
                    Toggle("Not Recently Chated", isOn: $filters.notRecentlyChatted.toNonOptional)
                    Toggle("Right Now", isOn: $filters.rightNow.toNonOptional)
                }
                
                Section("Age, Height and Weight") {
                    RangeInputRow(
                        title: "Age",
                        minVal: $filters.ageMin,
                        maxVal: $filters.ageMax,
                        format: .number
                    )
                    
                    RangeInputRow(
                        title: "Height (cm)",
                        minVal: $filters.heightCmMin,
                        maxVal: $filters.heightCmMax,
                        format: .number
                    )
                    
                    RangeInputRow(
                        title: "Weight (kg)",
                        minVal: $filters.weightGramsMin.gramsToKg,
                        maxVal: $filters.weightGramsMax.gramsToKg,
                        format: .number
                    )
                }
                
                Section("Preferences") {
                    MultiSelectPicker(title: "Tribes", selection: $filters.tribes)
                    MultiSelectPicker(title: "Looking For", selection: $filters.lookingFor)
                    MultiSelectPicker(title: "Relationship Status", selection: $filters.relationshipStatuses)
                    MultiSelectPicker(title: "Body Type", selection: $filters.bodyTypes)
                    MultiSelectPicker(title: "Sexual Position", selection: $filters.sexualPositions)
                    MultiSelectPicker(title: "Meet At", selection: $filters.meetAt)
                    MultiSelectPicker(title: "NSFW Pics", selection: $filters.nsfwPics)
                }
                
                Section("Extras") {
                    Toggle("Fresh", isOn: $filters.fresh.toNonOptional)
                    Toggle("Favorites", isOn: $filters.favorites.toNonOptional)
                    Toggle("Shuffle", isOn: $filters.shuffle.toNonOptional)
                    Toggle("Hot", isOn: $filters.hot.toNonOptional)
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
                        onDismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                }
                
                #if os(macOS)
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
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
