import Foundation

extension chatMessage {
    public func preservingMediaKeys(from older: chatMessage) -> chatMessage {
        let needsMerge = (body?.url == nil && older.body?.url != nil) || 
                         (body?.mediaHash == nil && older.body?.mediaHash != nil) || 
                         (body?.imageHash == nil && older.body?.imageHash != nil)
        
        guard needsMerge else { return self }
        
        guard let newerData = try? JSONEncoder().encode(self),
              let olderData = try? JSONEncoder().encode(older),
              var newerDict = try? JSONSerialization.jsonObject(with: newerData) as? [String: Any],
              let olderDict = try? JSONSerialization.jsonObject(with: olderData) as? [String: Any],
              var newerBody = newerDict["body"] as? [String: Any],
              let olderBody = olderDict["body"] as? [String: Any] else {
            return self
        }
        
        let keysToPreserve = ["url", "mediaHash", "imageHash", "mediaId"]
        for key in keysToPreserve {
            if (newerBody[key] == nil || newerBody[key] is NSNull), let oldVal = olderBody[key], !(oldVal is NSNull) {
                newerBody[key] = oldVal
            }
        }
        
        newerDict["body"] = newerBody
        
        if let mergedData = try? JSONSerialization.data(withJSONObject: newerDict),
           let merged = try? JSONDecoder().decode(chatMessage.self, from: mergedData) {
            return merged
        }
        
        return self
    }
}
