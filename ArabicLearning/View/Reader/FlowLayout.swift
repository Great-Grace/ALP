// FlowLayout.swift
// Custom Layout for wrapping text tokens horizontally
// Uses iOS 16+ Layout Protocol

import SwiftUI

struct FlowLayout: Layout {
    var alignment: Alignment = .leading
    var spacing: CGFloat = 6
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrangeSubviews(proposal: proposal, subviews: subviews)
        if rows.isEmpty { return .zero }
        
        let width = rows.reduce(0) { max($0, $1.width) }
        let height = rows.last!.maxY
        
        return CGSize(width: width, height: height)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrangeSubviews(proposal: proposal, subviews: subviews)
        
        for row in rows {
            for element in row.elements {
                element.subview.place(
                    at: CGPoint(x: bounds.minX + element.x, y: bounds.minY + element.y),
                    proposal: .unspecified
                )
            }
        }
    }
    
    struct LayoutRow {
        var elements: [(subview: LayoutSubview, x: CGFloat, y: CGFloat)] = []
        var width: CGFloat = 0
        var maxY: CGFloat = 0 // Bottom Y of this row
    }
    
    func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> [LayoutRow] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [LayoutRow] = []
        var currentRow = LayoutRow()
        var x: CGFloat = 0
        var y: CGFloat = 0
        var maxHeightInRow: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            // Check if we need a new row
            if x + size.width > maxWidth && !currentRow.elements.isEmpty {
                // Finish current row
                currentRow.maxY = y + maxHeightInRow
                rows.append(currentRow)
                
                // Reset for next row
                currentRow = LayoutRow()
                x = 0
                y += maxHeightInRow + spacing
                maxHeightInRow = 0
            }
            
            currentRow.elements.append((subview, x, y))
            x += size.width + spacing
            maxHeightInRow = max(maxHeightInRow, size.height)
            currentRow.width = max(currentRow.width, x)
        }
        
        if !currentRow.elements.isEmpty {
            currentRow.maxY = y + maxHeightInRow
            rows.append(currentRow)
        }
        
        return rows
    }
}
