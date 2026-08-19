import Foundation

public actor locationController {
    public static let shared = locationController()
    
    public var currentGeohash: String = "gcvxpuyy2222"
    
    private init() {}
    
    public func updateGeohash(_ geohash: String?) {
        self.currentGeohash = geohash ?? ""
    }
    
    public func updateGeohash(latitude: Double, longitude: Double) {
        self.currentGeohash = geohashEncoder.encode(latitude: latitude, longitude: longitude)
    }
}

struct geohashEncoder {
    private static let base32Chars = Array("0123456789bcdefghjkmnpqrstuvwxyz")
    
    static func encode(latitude: Double, longitude: Double, precision: Int = 12) -> String {
        var latRange = (-90.0, 90.0)
        var lonRange = (-180.0, 180.0)
        var geohash = ""
        var isEven = true
        var bit = 0
        var ch = 0
        
        while geohash.count < precision {
            if isEven {
                let mid = (lonRange.0 + lonRange.1) / 2
                if longitude > mid {
                    ch |= (1 << (4 - bit))
                    lonRange.0 = mid
                } else {
                    lonRange.1 = mid
                }
            } else {
                let mid = (latRange.0 + latRange.1) / 2
                if latitude > mid {
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
