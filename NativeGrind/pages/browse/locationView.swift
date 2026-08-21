import SwiftUI
import MapKit
import NativeGrindCore

struct LocationView: View {
    var onDismiss: () -> Void
    
    @State private var currentGeohash: String = ""
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Select Location") {
                    MapReader { proxy in
                        Map(position: $cameraPosition) {
                            if let coordinate = selectedCoordinate {
                                Marker("Selected Location", coordinate: coordinate)
                            }
                        }
                        .frame(height: 250)
                        .cornerRadius(12)
                        .onTapGesture { position in
                            if let coordinate = proxy.convert(position, from: .local) {
                                selectedCoordinate = coordinate
                                Task {
                                    await updateGeohash(for: coordinate)
                                }
                            }
                        }
                    }
                }
                
                Section("Current Location Geohash") {
                    Text(currentGeohash.isEmpty ? "No location selected" : currentGeohash)
                        .font(.system(.body, design: .monospaced))
                }
            }
            .navigationTitle("Location")
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
    
    private func updateGeohash(for coordinate: CLLocationCoordinate2D) async {
        await locationController.shared.updateGeohash(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        guard let currentGeohash = await locationController.shared.currentGeohash else {
            return
        }
    }
}
