//
//  localStore.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 24/09/2026.
//

import Foundation

public enum storeCollection: String, Codable, Sendable, CaseIterable {
    case profiles
    case profileHistory
    case conversations
}

public struct storeChange: Codable, Sendable, Hashable {
    public enum kind: String, Codable, Sendable {
        case upsert
        case delete
    }

    public let collection: storeCollection
    public let key: String
    public let kind: kind
    public let changedAt: Date
}

public actor localStore {
    public static let shared = localStore(root: localStore.defaultRoot)

    private let root: URL
    private var ledger: [String: storeChange]? = nil

    public init(root: URL) {
        self.root = root
    }

    private static var defaultRoot: URL {
        if appEnvironment.isTesting {
            return FileManager.default.temporaryDirectory.appendingPathComponent("localStore-\(UUID().uuidString)", isDirectory: true)
        }
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return support.appendingPathComponent("store", isDirectory: true)
    }

    public func read<T: Decodable>(_ type: T.Type, from collection: storeCollection, key: String) -> T? {
        guard let url = fileURL(collection, key),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return try? decoder.decode(T.self, from: data)
    }

    public func readAll<T: Decodable>(_ type: T.Type, from collection: storeCollection) -> [T] {
        keys(in: collection).compactMap { read(T.self, from: collection, key: $0) }
    }

    public func keys(in collection: storeCollection) -> [String] {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory(collection), includingPropertiesForKeys: nil)) ?? []
        return files
            .filter { $0.pathExtension == "json" }
            .map { $0.deletingPathExtension().lastPathComponent }
    }

    public func write<T: Encodable>(_ value: T, to collection: storeCollection, key: String) throws {
        guard let url = fileURL(collection, key) else {
            throw storeError.invalidKey(key)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .millisecondsSince1970

        try FileManager.default.createDirectory(at: directory(collection), withIntermediateDirectories: true)
        try encoder.encode(value).write(to: url, options: [.atomic, .completeFileProtection])

        record(storeChange(collection: collection, key: key, kind: .upsert, changedAt: Date()))
    }

    public func delete(from collection: storeCollection, key: String) {
        guard let url = fileURL(collection, key), FileManager.default.fileExists(atPath: url.path) else { return }
        try? FileManager.default.removeItem(at: url)
        record(storeChange(collection: collection, key: key, kind: .delete, changedAt: Date()))
    }

    public func clear(_ collection: storeCollection) {
        try? FileManager.default.removeItem(at: directory(collection))
        var ledger = loadLedger()
        ledger = ledger.filter { $0.value.collection != collection }
        saveLedger(ledger)
    }

    public func pendingChanges() -> [storeChange] {
        loadLedger().values.sorted { $0.changedAt < $1.changedAt }
    }

    public func markSynced(_ changes: [storeChange]) {
        var ledger = loadLedger()
        for change in changes {
            let id = ledgerKey(change.collection, change.key)
            if ledger[id] == change {
                ledger.removeValue(forKey: id)
            }
        }
        saveLedger(ledger)
    }

    private func record(_ change: storeChange) {
        var ledger = loadLedger()
        ledger[ledgerKey(change.collection, change.key)] = change
        saveLedger(ledger)
    }

    private func loadLedger() -> [String: storeChange] {
        if let ledger { return ledger }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        let loaded = (try? Data(contentsOf: ledgerURL)).flatMap { try? decoder.decode([String: storeChange].self, from: $0) } ?? [:]
        ledger = loaded
        return loaded
    }

    private func saveLedger(_ newLedger: [String: storeChange]) {
        ledger = newLedger
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try? encoder.encode(newLedger).write(to: ledgerURL, options: .atomic)
    }

    private func ledgerKey(_ collection: storeCollection, _ key: String) -> String {
        "\(collection.rawValue)/\(key)"
    }

    private var ledgerURL: URL {
        root.appendingPathComponent("syncLedger.json")
    }

    private func directory(_ collection: storeCollection) -> URL {
        root.appendingPathComponent(collection.rawValue, isDirectory: true)
    }

    private func fileURL(_ collection: storeCollection, _ key: String) -> URL? {
        guard key.wholeMatch(of: /^[A-Za-z0-9_-]{1,128}$/) != nil else { return nil }
        return directory(collection).appendingPathComponent("\(key).json")
    }
}

public enum storeError: Error {
    case invalidKey(String)
}
