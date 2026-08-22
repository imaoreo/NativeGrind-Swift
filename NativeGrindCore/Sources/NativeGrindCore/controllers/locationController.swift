import Foundation

public actor locationController {
    public static let shared = locationController()
    
    private var _currentGeohash: String? = nil
    
    public var currentGeohash: String? {
        if let inMemory = _currentGeohash {
            return inMemory
        }
        if let local = UserDefaults.standard.string(forKey: "saved_geohash") {
            return local
        }
        return nil
    }
    
    private init() {
        if let local = UserDefaults.standard.string(forKey: "saved_geohash") {
            self._currentGeohash = local
        }
    }
    
    public func updateGeohash(_ geohash: String?) {
        self._currentGeohash = geohash
        if let geohash = geohash {
            UserDefaults.standard.set(geohash, forKey: "saved_geohash")
            
            Task {
                if await wsController.shared.isServerAuthorized {
                    try? await nsStorageController.shared.saveData(location: .location, data: geohash)
                }
            }
        } else {
            UserDefaults.standard.removeObject(forKey: "saved_geohash")
            Task {
                if await wsController.shared.isServerAuthorized {
                    try? await nsStorageController.shared.saveData(location: .location, data: "")
                }
            }
        }
    }
    
    public func updateGeohash(latitude: Double, longitude: Double) {
        let geohash = geohashEncoder.encode(latitude: latitude, longitude: longitude)
        self.updateGeohash(geohash)
    }
    
    public func syncWithServer() async {
        guard await wsController.shared.isServerAuthorized else { return }
        do {
            let serverGeohash = try await nsStorageController.shared.getData(location: .location)
            if !serverGeohash.isEmpty {
                self._currentGeohash = serverGeohash
                UserDefaults.standard.set(serverGeohash, forKey: "saved_geohash")
            }
        } catch {
            if let local = _currentGeohash {
                try? await nsStorageController.shared.saveData(location: .location, data: local)
            }
        }
    }
}

public struct geohashEncoder {
    private static let base32Chars = Array("0123456789bcdefghjkmnpqrstuvwxyz")
    
    public static func decode(_ geohash: String) -> (latitude: Double, longitude: Double)? {
        let cleanHash = geohash.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleanHash.isEmpty else { return nil }
        var latRange = (-90.0, 90.0)
        var lonRange = (-180.0, 180.0)
        var isEven = true
        
        for char in cleanHash {
            guard let idx = base32Chars.firstIndex(of: char) else { return nil }
            for bit in 0..<5 {
                let mask = 1 << (4 - bit)
                let bitVal = (idx & mask) != 0
                if isEven {
                    let mid = (lonRange.0 + lonRange.1) / 2
                    if bitVal {
                        lonRange.0 = mid
                    } else {
                        lonRange.1 = mid
                    }
                } else {
                    let mid = (latRange.0 + latRange.1) / 2
                    if bitVal {
                        latRange.0 = mid
                    } else {
                        latRange.1 = mid
                    }
                }
                isEven.toggle()
            }
        }
        let lat = (latRange.0 + latRange.1) / 2
        let lon = (lonRange.0 + lonRange.1) / 2
        return (lat, lon)
    }
    
    public static func encode(latitude: Double, longitude: Double, precision: Int = 12) -> String {
        var latRange = (-90.0, 90.0)
        var lonRange = (-180.0, 180.0)
        var geohash = ""
        var isEven = true
        var bit = 0
        var ch = 0
        
        while geohash.count < precision {
            if isEven {
                let mid = (lonRange.0 + lonRange.1) / 2
                if longitude >= mid {
                    ch |= (1 << (4 - bit))
                    lonRange.0 = mid
                } else {
                    lonRange.1 = mid
                }
            } else {
                let mid = (latRange.0 + latRange.1) / 2
                if latitude >= mid {
                    ch |= (1 << (4 - bit))
                    latRange.0 = mid
                } else {
                    latRange.1 = mid
                }
            }
            
            isEven.toggle()
            
            if bit < 4 {
                bit += 1
            } else {
                geohash.append(base32Chars[ch])
                bit = 0
                ch = 0
            }
        }
        
        return geohash
    }
}
