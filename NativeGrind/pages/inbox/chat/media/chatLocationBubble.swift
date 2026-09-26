//
//  chatLocationBubble.swift
//  NativeGrind
//
//  Created by Jay Brammeld on 24/09/2026.
//

import SwiftUI
import MapKit

struct chatLocationBubble: View {
    let latitude: Double
    let longitude: Double

    private var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    private var region: MKCoordinateRegion {
        MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
    }

    var body: some View {
        map
            .allowsHitTesting(false)
        .frame(width: 220, height: 150)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        #if !os(tvOS)
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .onTapGesture(perform: openInMaps)
        #endif
    }

    @ViewBuilder
    private var map: some View {
        if #available(iOS 17, *) {
            Map(initialPosition: .region(region)) {
                Marker("Location", coordinate: coordinate)
            }
        } else {
            Map(coordinateRegion: .constant(region), annotationItems: [pin(coordinate: coordinate)]) { pin in
                MapMarker(coordinate: pin.coordinate)
            }
        }
    }

    private struct pin: Identifiable {
        let id = 0
        let coordinate: CLLocationCoordinate2D
    }

    #if !os(tvOS)
    private func openInMaps() {
        let mapItem: MKMapItem
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            mapItem = MKMapItem(location: CLLocation(latitude: latitude, longitude: longitude), address: nil)
        } else {
            mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        }
        mapItem.name = "Shared Location"
        mapItem.openInMaps()
    }
    #endif
}
