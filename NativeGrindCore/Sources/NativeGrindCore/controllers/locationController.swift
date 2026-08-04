import Foundation

public actor locationController {
    public static let shared = locationController()
    
    public var currentGeohash: String? = nil
    
    private init() {}
    
    public func updateGeohash(_ geohash: String?) {
        self.currentGeohash = geohash
    }
}
