//
//  flowLayout.swift
//  NativeGrind
//
//  Created by Jay Brammeld on 18/08/2026.
//
//  This file was made using Gemini AI; it ideally needs to be refactored.

import SwiftUI

struct flowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var maxHeight: CGFloat = 0
        var positions: [CGPoint] = []

        for subview in subviews {
            let subviewSize = subview.sizeThatFits(.unspecified)
            
            if currentX + subviewSize.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += maxHeight + spacing
                maxHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            maxHeight = max(maxHeight, subviewSize.height)
            currentX += subviewSize.width + spacing
        }

        return (positions, CGSize(width: maxWidth, height: currentY + maxHeight))
    }
}
