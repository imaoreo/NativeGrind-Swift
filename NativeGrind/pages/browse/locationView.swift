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
    @State private var search = placeSearch()
    @State private var selectedPlaceName: String? = nil
    
    var body: some View {
        NavigationStack {
            #if os(macOS)
            VStack(spacing: 0) {
                map
                Divider()
                form
            }
            .navigationTitle("Location")
            .toolbar { toolbarContent }
            .task { await loadCurrentLocation() }
            #else
            form
                .navigationTitle("Location")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar { toolbarContent }
                .task { await loadCurrentLocation() }
            #endif
        }
    }

    private var map: some View {
        MapReader { proxy in
            Map(position: $cameraPosition) {
                if let coordinate = selectedCoordinate {
                    Marker(selectedPlaceName ?? "Selected Location", coordinate: coordinate)
                }
            }
            #if os(macOS)
            .frame(height: 220)
            #else
            .frame(height: 250)
            #endif
            .onTapGesture { position in
                if let coordinate = proxy.convert(position, from: .local) {
                    selectedPlaceName = nil
                    selectedCoordinate = coordinate
                    currentGeohash = geohashEncoder.encode(latitude: coordinate.latitude, longitude: coordinate.longitude)
                    latitudeString = String(format: "%.6f", coordinate.latitude)
                    longitudeString = String(format: "%.6f", coordinate.longitude)
                }
            }
        }
    }

    private var form: some View {
        Form {
            searchSection

            #if !os(macOS)
            Section("Select Location on Map") {
                map
                    .listRowInsets(EdgeInsets())
            }
            #endif
                
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
        #if os(macOS)
        .formStyle(.grouped)
        .toggleStyle(.checkbox)
        #endif
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
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

    private func loadCurrentLocation() async {
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

    private var searchSection: some View {
        Section("Search") {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search for a place", text: $search.query)
                    .autocorrectionDisabled()
                if search.isResolving {
                    ProgressView()
                        .controlSize(.small)
                } else if !search.query.isEmpty {
                    Button {
                        search.clear()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            ForEach(search.results, id: \.self) { result in
                Button {
                    Task { await select(result) }
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(result.title)
                            .foregroundColor(.primary)
                        if !result.subtitle.isEmpty {
                            Text(result.subtitle)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func select(_ result: MKLocalSearchCompletion) async {
        guard let coordinate = await search.coordinate(for: result) else { return }
        latitudeString = String(format: "%.6f", coordinate.latitude)
        longitudeString = String(format: "%.6f", coordinate.longitude)
        updateFromCoordinates()
        selectedPlaceName = result.title
        search.clear()
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
        
        guard let (lat, lon) = geohashEncoder.decode(currentGeohash) else { return }
        
        let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        selectedCoordinate = coord
        latitudeString = String(coord.latitude)
        longitudeString = String(coord.longitude)
        cameraPosition = .region(MKCoordinateRegion(center: coord, span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)))
    }
}
#endif
