//
//  lenientDecoding.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 25/09/2026.
//

import Foundation

public extension Date {
    init(milliseconds: Int64) {
        self.init(timeIntervalSince1970: TimeInterval(milliseconds) / 1000)
    }
}

extension KeyedDecodingContainer {
    func lenient<T: Decodable>(_ key: Key) -> T? {
        (try? decodeIfPresent(T.self, forKey: key)) ?? nil
    }

    func lenientTimestamp(_ key: Key) -> Int64? {
        if let value: Int64 = lenient(key) { return value }
        if let value: Double = lenient(key) { return Int64(value) }
        return nil
    }

    func lossyArray<T: Decodable>(_ key: Key) -> [T] {
        guard var container = try? nestedUnkeyedContainer(forKey: key) else { return [] }
        var items: [T] = []
        while !container.isAtEnd {
            if let item = try? container.decode(T.self) {
                items.append(item)
            } else {
                _ = try? container.decode(skipItem.self)
            }
        }
        return items
    }
}

private struct skipItem: Decodable {}
