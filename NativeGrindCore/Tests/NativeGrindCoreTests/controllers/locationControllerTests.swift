//
//  locationControllerTests.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 22/08/2026.
//

import Testing
import Foundation
@testable import NativeGrindCore

@Suite("Location Controller & Geohash Tests")
struct locationControllerTests {
    
    @Test("Verifies geohash encoding of known vectors")
    func testGeohashEncodingKnownVectors() {
        // (0.0, 0.0) should encode to s00000000000
        let zeroHash = geohashEncoder.encode(latitude: 0.0, longitude: 0.0, precision: 12)
        #expect(zeroHash == "s00000000000")
        
        // London (51.5074, -0.1278) -> gcpvj0dthsbw (approximate)
        let londonHash = geohashEncoder.encode(latitude: 51.5074, longitude: -0.1278, precision: 8)
        #expect(londonHash == "gcpvj0du")
    }
    
    @Test("Verifies geohash round-trip encoding and decoding")
    func testGeohashRoundTrip() {
        let coordinates = [
            (lat: 37.7749, lon: -122.4194), // San Francisco
            (lat: 51.5074, lon: -0.1278),    // London
            (lat: -33.8688, lon: 151.2093),  // Sydney
            (lat: 0.0, lon: 0.0)             // Midpoint
        ]
        
        for coord in coordinates {
            let hash = geohashEncoder.encode(latitude: coord.lat, longitude: coord.lon, precision: 12)
            guard let decoded = geohashEncoder.decode(hash) else {
                Issue.record("Failed to decode hash: \(hash)")
                continue
            }
            
            // Allow small error due to geohash precision limits
            #expect(abs(decoded.latitude - coord.lat) < 0.0001)
            #expect(abs(decoded.longitude - coord.lon) < 0.0001)
        }
    }
    
    @Test("Verifies decoding of invalid or empty geohash returns nil")
    func testInvalidGeohashDecoding() {
        #expect(geohashEncoder.decode("") == nil)
        #expect(geohashEncoder.decode("   ") == nil)
        #expect(geohashEncoder.decode("invalid#chars") == nil)
    }
    
    @Test("Verifies locationController updates currentGeohash")
    func testLocationControllerUpdates() async {
        await TestSerializer.shared.run {
            let controller = locationController.shared
            await controller.updateGeohash("s00000000000")
            let hash = await controller.currentGeohash
            #expect(hash == "s00000000000")
        
            await controller.updateGeohash(latitude: 37.7749, longitude: -122.4194)
            let newHash = await controller.currentGeohash
            #expect(newHash != nil)
            #expect(newHash?.starts(with: "9q8yy") == true)
        }
    }
}
