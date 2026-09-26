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
    @State private var focus: locationMapFocus? = nil
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var latitudeString: String = ""
    @State private var longitudeString: String = ""
    @StateObject private var search = placeSearch()
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
        locationPickerMap(focus: focus, selected: selectedCoordinate, selectedName: selectedPlaceName ?? "Selected Location") { coordinate in
            selectedPlaceName = nil
            selectedCoordinate = coordinate
            currentGeohash = geohashEncoder.encode(latitude: coordinate.latitude, longitude: coordinate.longitude)
            latitudeString = String(format: "%.6f", coordinate.latitude)
            longitudeString = String(format: "%.6f", coordinate.longitude)
        }
        #if os(macOS)
        .frame(height: 220)
        #else
        .frame(height: 250)
        #endif
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
                    .onChangeCompat(of: latitudeString) { _, _ in
                        updateFromCoordinates()
                    }
                    
                TextField("Longitude", text: $longitudeString)
                    #if os(iOS)
                    .keyboardType(.numbersAndPunctuation)
                    #endif
                    .onChangeCompat(of: longitudeString) { _, _ in
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
                focus = locationMapFocus(center: coord2d)
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
        focus = locationMapFocus(center: coord)
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
        focus = locationMapFocus(center: coord)
    }
}
struct locationMapFocus: Equatable {
    let id = UUID()
    let region: MKCoordinateRegion

    init(center: CLLocationCoordinate2D) {
        region = MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
    }

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
}

private struct locationPickerMap: View {
    let focus: locationMapFocus?
    let selected: CLLocationCoordinate2D?
    let selectedName: String
    let onPick: (CLLocationCoordinate2D) -> Void

    var body: some View {
        if #available(iOS 17, *) {
            modernLocationMap(focus: focus, selected: selected, selectedName: selectedName, onPick: onPick)
        } else {
            legacyLocationMap(focus: focus, selected: selected)
        }
    }
}

@available(iOS 17, *)
private struct modernLocationMap: View {
    let focus: locationMapFocus?
    let selected: CLLocationCoordinate2D?
    let selectedName: String
    let onPick: (CLLocationCoordinate2D) -> Void

    @State private var position: MapCameraPosition = .automatic

    var body: some View {
        MapReader { proxy in
            Map(position: $position) {
                if let selected {
                    Marker(selectedName, coordinate: selected)
                }
            }
            .onTapGesture { point in
                if let coordinate = proxy.convert(point, from: .local) {
                    onPick(coordinate)
                }
            }
        }
        .onChangeCompat(of: focus) { _, focus in
            if let focus { position = .region(focus.region) }
        }
    }
}

private struct legacyLocationMap: View {
    let focus: locationMapFocus?
    let selected: CLLocationCoordinate2D?

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278),
        span: MKCoordinateSpan(latitudeDelta: 40, longitudeDelta: 40)
    )

    private struct pin: Identifiable {
        let id = 0
        let coordinate: CLLocationCoordinate2D
    }

    var body: some View {
        Map(coordinateRegion: $region, annotationItems: selected.map { [pin(coordinate: $0)] } ?? []) { pin in
            MapMarker(coordinate: pin.coordinate)
        }
        .onChange(of: focus) { focus in
            if let focus { region = focus.region }
        }
    }
}
#endif
