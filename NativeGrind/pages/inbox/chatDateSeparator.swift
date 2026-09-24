//
//  chatDateSeparator.swift
//  NativeGrind
//
//  Created by Jay Brammeld on 24/09/2026.
//

import SwiftUI

/// Shown before the first message of each day
struct chatDateSeparator: View {
    let date: Date

    var body: some View {
        Text(Self.label(for: date))
            .font(.caption.weight(.semibold))
            .foregroundColor(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.gray.opacity(0.12), in: Capsule())
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
    }

    /// Today, Yesterday, a weekday for the last week, otherwise the date (with the year if it isn't this year)
    static func label(for date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        if calendar.isDateInToday(date) {
            return "Today"
        }
        if calendar.isDateInYesterday(date) {
            return "Yesterday"
        }

        let startOfToday = calendar.startOfDay(for: now)
        if let weekAgo = calendar.date(byAdding: .day, value: -6, to: startOfToday), date >= weekAgo {
            return date.formatted(.dateTime.weekday(.wide))
        }

        if calendar.isDate(date, equalTo: now, toGranularity: .year) {
            return date.formatted(.dateTime.weekday(.abbreviated).day().month(.wide))
        }
        return date.formatted(.dateTime.day().month(.wide).year())
    }
}
