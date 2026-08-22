//
//  rangeSelector.swift
//  NativeGrind
//
//  Created by Jay Brammeld on 17/08/2026.
//
import SwiftUI

extension Binding where Value == Double? {
    var gramsToKg: Binding<Double?> {
        Binding<Double?>(
            get: {
                if let grams = self.wrappedValue { return grams / 1000.0 }
                return nil
            },
            set: {
                if let kg = $0 { self.wrappedValue = kg * 1000.0 }
                else { self.wrappedValue = nil }
            }
        )
    }
}

struct RangeInputRow<V, F: ParseableFormatStyle>: View where F.FormatInput == V, F.FormatOutput == String {
    let title: String
    @Binding var minVal: V?
    @Binding var maxVal: V?
    let format: F
    
    var body: some View {
        LabeledContent(title) {
            HStack {
                TextField("Min", value: $minVal, format: format)
                Text("-")
                TextField("Max", value: $maxVal, format: format)
            }
            .multilineTextAlignment(.center)
            #if os(iOS)
            .keyboardType(.decimalPad)
            #endif
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: 150)
        }
    }
}
