//
//  dbControllerHelper.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 29/06/2026.
//

import Foundation

public enum dbControllerHelper {
    
    // Standard Encoder used for db
    public static var encoder: JSONEncoder {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        return enc
    }
    
    // Standard Decoder used for db
    public static var decoder: JSONDecoder {
        return JSONDecoder()
    }
    
    // Decode a JSON String into a data struct (like profile, inbox)
    public static func decodeRecord<T: Codable>(_ jsonString: String, as type: T.Type, domain: String) throws -> T {
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw NSError(domain: domain, code: 3, userInfo: [NSLocalizedDescriptionKey: "Corrupted string data in database"])
        }
        return try decoder.decode(T.self, from: jsonData)
    }

    // Compare 2 codeable objects and output a reverse JSON delta string
    public static func generateDiff(from oldData: Data, to newData: Data) -> String? {
        guard let oldDict = try? JSONSerialization.jsonObject(with: oldData) as? [String: Any],
              let newDict = try? JSONSerialization.jsonObject(with: newData) as? [String: Any] else {
            return nil
        }
        
        var diffDict: [String: Any] = [:]
        
        let keys = Set(oldDict.keys).union(newDict.keys)
        
        for key in keys {
            let oldValue = oldDict[key]
            let newValue = newDict[key]
            
            let oldObj = oldValue as? NSObject
            let newObj = newValue as? NSObject
            
            if oldObj != newObj {
                // Store the previous value so history can be rebuilt backwards from the current model.
                diffDict[key] = oldValue ?? NSNull()
            }
        }
        
        guard !diffDict.isEmpty else { return nil }
        
        if let serializedDiff = try? JSONSerialization.data(withJSONObject: diffDict, options: []),
           let diffString = String(data: serializedDiff, encoding: .utf8) {
            return diffString
        }
        
        return nil
    }
    
    // Used to create a list of a object through diffrent stages / timestamps
    public static func rebuildHistory<T: Codable>(
        currentModel: T,
        diffStrings: [(createdAt: Date, jsonStr: String)],
        timestampAssigner: (inout T, Date) -> Void
    ) -> [T] {
        guard let currentData = try? encoder.encode(currentModel),
              var currentJsonDict = try? JSONSerialization.jsonObject(with: currentData) as? [String: Any] else {
            return []
        }
        
        var history: [T] = []
        
        history.append(currentModel)
        
        for record in diffStrings {
            guard let diffData = record.jsonStr.data(using: .utf8),
                  let diffDict = try? JSONSerialization.jsonObject(with: diffData) as? [String: Any] else {
                continue
            }
            
            // apply reverse diff data to the current state
            for (key, val) in diffDict {
                if val is NSNull {
                    currentJsonDict.removeValue(forKey: key)
                } else {
                    currentJsonDict[key] = val
                }
            }
            
            if let combinedData = try? JSONSerialization.data(withJSONObject: currentJsonDict),
               var historicItem = try? decoder.decode(T.self, from: combinedData) {
                timestampAssigner(&historicItem, record.createdAt)
                history.append(historicItem)
            }
        }
        
        return history
    }
}
