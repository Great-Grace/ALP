// BlockCardView.swift
// Reusable block card component for 12 curriculum blocks

import SwiftUI
import SwiftData

struct BlockCardView: View {
    let block: CurriculumBlock
    let isSelected: Bool
    var onTap: () -> Void
    
    // Block color mapping
    private var blockColor: Color {
        switch block.blockID {
        case 0: return .gray
        case 1, 2: return .blue
        case 3, 4, 5: return .green
        case 6: return .orange  // Hub - Gold
        case 7, 8, 9, 10: return .purple
        case 11, 12: return .red
        default: return .blue
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Block Number with Progress Ring
                ZStack {
                    // Progress Ring
                    Circle()
                        .stroke(blockColor.opacity(0.2), lineWidth: 4)
                        .frame(width: 60, height: 60)
                    
                    Circle()
                        .trim(from: 0, to: block.progress)
                        .stroke(blockColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))
                    
                    // Block Number
                    VStack(spacing: 2) {
                        Text("\(block.blockID)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(blockColor)
                        
                        if block.isHub {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }
                }
                
                // Title
                VStack(spacing: 4) {
                    Text(block.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    if !block.titleArabic.isEmpty {
                        Text(block.titleArabic)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                
                // Progress Label
                HStack(spacing: 4) {
                    Text("\(block.completedSubLevels)/\(block.totalSubLevels)")
                        .font(.caption2)
                        .fontWeight(.medium)
                    
                    Text("완료")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
                
                // CEFR Badge
                if !block.cefrLevel.isEmpty {
                    Text(block.cefrLevel)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(blockColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(blockColor.opacity(0.15))
                        .cornerRadius(6)
                }
            }
            .padding()
            .frame(width: 130, height: 180)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.background)
                    .shadow(color: .black.opacity(isSelected ? 0.15 : 0.05), radius: isSelected ? 12 : 6, y: isSelected ? 6 : 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? blockColor : .clear, lineWidth: 2)
            )
            .opacity(block.isLocked ? 0.6 : 1.0)
            .overlay(lockOverlay)
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var lockOverlay: some View {
        if block.isLocked {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial.opacity(0.5))
                
                Image(systemName: "lock.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: 16) {
        BlockCardView(
            block: CurriculumBlock(blockID: 6, title: "Form I 완전정복", titleArabic: "الفعل الثلاثي", cefrLevel: "B1", isHub: true, totalSubLevels: 6),
            isSelected: true,
            onTap: {}
        )
        
        BlockCardView(
            block: CurriculumBlock(blockID: 7, title: "Form II-IV", titleArabic: "الأفعال المزيدة", cefrLevel: "B1", isHub: false, totalSubLevels: 4),
            isSelected: false,
            onTap: {}
        )
    }
    .padding()
    .background(Color.gray.opacity(0.1))
}
