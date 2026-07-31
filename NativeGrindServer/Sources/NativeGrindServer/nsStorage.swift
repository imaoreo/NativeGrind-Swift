//
//  nsStorage.swift
//  NativeGrindServer
//
//  Created by Jay Brammeld on 31/07/2026.
//

import NativeGrindCore
import Foundation

public enum nsStorageError: Error {
    case keyNotFound
    case invalidData
    case decodingFailed
    case encodingFailed
}


public final class nsStorageController: Sendable {
    public static let shared = nsStorageController()
    
    private init() {}
    
    // Get Private Data
    public func getData<T: Decodable>(location: String, as type: T.Type) async throws -> T {
        guard let data = await wsController.shared.sendAndWait(
            request: .getData(location: location),
            expectedEvent: .onDataGet
        ) else {
            throw nsStorageError.invalidData
        }
        
        guard let encryptedData = data.data else {
            throw nsStorageError.invalidData
        }
        
        let decryptedString = try cryptoController.shared.decryptTextWithSharedKey(encryptedBase64: encryptedData)
        
        guard let jsonData = decryptedString.data(using: .utf8) else {
            throw nsStorageError.decodingFailed
        }
        
        do {
            let decoder = JSONDecoder()
            let decodedObject = try decoder.decode(T.self, from: jsonData)
            return decodedObject
        } catch {
            await errorManager.shared.error("nsStorage", "JSON Decoding failed: \(error.localizedDescription)")
            throw nsStorageError.decodingFailed
        }
    }

    // Save Data
    public func saveData(location: String, data: String) async throws -> String {
        let encoder = JSONEncoder()
        guard let jsonData = try? encoder.encode(data),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw nsStorageError.encodingFailed
        }
        
        let encryptedData = try cryptoController.shared.encryptTextWithSharedKey(text: jsonString)
        
        guard let data = await wsController.shared.sendAndWait(
            request: .saveData(location: location, encryptedData: encryptedData),
            expectedEvent: .onDataSaved
        ) else {
            throw nsStorageError.invalidData
        }
        
        return data.message
    }
}
