//
//  deviceLocationController.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 22/08/2026.
//

import Foundation
import CoreLocation

public class deviceLocationManager: NSObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    
    public override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }
    
    public func getCurrentLocation() async throws -> CLLocation {
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            self.locationContinuation?.resume(throwing: CancellationError())
            
            self.locationContinuation = continuation
            locationManager.requestLocation()
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            locationContinuation?.resume(returning: location)
            
            locationContinuation = nil
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationContinuation?.resume(throwing: error)
        locationContinuation = nil
    }
}
