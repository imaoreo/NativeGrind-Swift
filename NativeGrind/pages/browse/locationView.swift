//
//  locationView.swift
//  NativeGrind
//

import SwiftUI
import MapKit
import NativeGrindCore

#if !os(tvOS)
struct locationView: View {
    var onApply: () -> Void
    var onCancel: () -> Void
    
    let locationManager = deviceLocationManager()
    @State private var currentGeohash: String = ""
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var latitudeString: String = ""
    @State private var longitudeString: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Select Location on Map") {
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
                                currentGeohash = geohashEncoder.encode(latitude: coordinate.latitude, longitude: coordinate.longitude)
                                latitudeString = String(format: "%.6f", coordinate.latitude)
                                longitudeString = String(format: "%.6f", coordinate.longitude)
                            }
                        }
                    }
                }
                
                Button("Use Current Location") {
                    Task {
                        if let location = try? await locationManager.getCurrentLocation() {
                            latitudeString = String(location.coordinate.latitude)
                            longitudeString = String(location.coordinate.longitude)
                            updateFromCoordinates()
                        }
                    }

                }
                
                Section("Preset Locations") {
                    Button("San Francisco, CA") {
                        latitudeString = "37.7749"
                        longitudeString = "-122.4194"
                        updateFromCoordinates()
                    }
                    Button("London, UK") {
                        latitudeString = "51.5074"
                        longitudeString = "-0.1278"
                        updateFromCoordinates()
                    }
                }
                
                Section("Manual Input") {
                    TextField("Latitude", text: $latitudeString)
                        #if os(iOS)
                        .keyboardType(.numbersAndPunctuation)
                        #endif
                        .onChange(of: latitudeString) {
                            updateFromCoordinates()
                        }
                    
                    TextField("Longitude", text: $longitudeString)
                        #if os(iOS)
                        .keyboardType(.numbersAndPunctuation)
                        #endif
                        .onChange(of: longitudeString) {
                            updateFromCoordinates()
                        }
                    
                    TextField("Geohash", text: $currentGeohash, onEditingChanged: { isEditing in
                        if !isEditing {
                            updateFromGeohash()
                        }
                    })
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
                        Task {
                            await locationController.shared.updateGeohash(currentGeohash)
                            onApply()
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(currentGeohash.isEmpty)
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
            .task {
                if let geohash = await locationController.shared.currentGeohash {
                    currentGeohash = geohash
                    if let coords = geohashEncoder.decode(geohash) {
                        let coord2d = CLLocationCoordinate2D(latitude: coords.latitude, longitude: coords.longitude)
                        selectedCoordinate = coord2d
                        cameraPosition = .region(MKCoordinateRegion(center: coord2d, span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)))
                        latitudeString = String(format: "%.6f", coords.latitude)
                        longitudeString = String(format: "%.6f", coords.longitude)
                    }
                }
            }
        }
    }
    
    private func updateFromCoordinates() {
        guard let lat = Double(latitudeString.trimmingCharacters(in: .whitespacesAndNewlines)),
              let lon = Double(longitudeString.trimmingCharacters(in: .whitespacesAndNewlines)),
              (-90.0...90.0).contains(lat),
              (-180.0...180.0).contains(lon) else {
            currentGeohash = ""
            selectedCoordinate = nil
            return
        }
        let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        selectedCoordinate = coord
        currentGeohash = geohashEncoder.encode(latitude: lat, longitude: lon)
        cameraPosition = .region(MKCoordinateRegion(center: coord, span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)))
    }
    
    private func updateFromGeohash() {
        if currentGeohash.isEmpty {
            return
        }
        
        let (lat, lon) = geohashEncoder.decode(currentGeohash)!
        
        let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        selectedCoordinate = coord
        latitudeString = String(coord.latitude)
        longitudeString = String(coord.longitude)
        cameraPosition = .region(MKCoordinateRegion(center: coord, span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)))
    }
}
#endif
