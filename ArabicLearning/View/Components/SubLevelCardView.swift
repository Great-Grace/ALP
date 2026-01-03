// SubLevelCardView.swift
// Reusable sub-level card for 50 curriculum sub-levels

import SwiftUI
import SwiftData

struct SubLevelCardView: View {
    let subLevel: SubLevel
    let blockColor: Color
    var onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Header: Title + Progress
                HStack {
                    // Sub-level ID Badge
                    Text(subLevel.subLevelID)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(blockColor)
                        .cornerRadius(6)
                    
                    Spacer()
                    
                    // Progress Ring
                    ZStack {
                        Circle()
                            .stroke(blockColor.opacity(0.2), lineWidth: 3)
                            .frame(width: 32, height: 32)
                        
                        Circle()
                            .trim(from: 0, to: subLevel.progress)
                            .stroke(blockColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .frame(width: 32, height: 32)
                            .rotationEffect(.degrees(-90))
                        
                        if subLevel.isCompleted {
                            Image(systemName: "checkmark")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(blockColor)
                        } else {
                            Text("\(subLevel.progressPercentage)")
                                .font(.system(size: 10))
                                .fontWeight(.bold)
                                .foregroundStyle(blockColor)
                        }
                    }
                }
                
                // Title
                Text(subLevel.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                // Concept
                Text(subLevel.concept)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                
                Spacer(minLength: 0)
                
                // Footer: Word count
                HStack {
                    Image(systemName: "textformat.abc")
                        .font(.caption2)
                    
                    Text("\(subLevel.targetWordCount)개 단어")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
                
                // Status Badge
                statusBadge
            }
            .padding()
            .frame(width: 200, height: 180)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.background)
                    .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(subLevel.progress > 0 ? blockColor.opacity(0.3) : .clear, lineWidth: 1)
            )
            .opacity(subLevel.isLocked ? 0.6 : 1.0)
            .overlay(lockOverlay)
        }
        .buttonStyle(.plain)
        .disabled(subLevel.isLocked)
    }
    
    @ViewBuilder
    private var statusBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: subLevel.statusIcon)
                .font(.caption2)
            
            Text(statusText)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundStyle(statusColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.15))
        .cornerRadius(6)
    }
    
    private var statusText: String {
        if subLevel.isCompleted { return "완료" }
        if subLevel.progress > 0 { return "학습 중" }
        if subLevel.isLocked { return "잠금" }
        return "시작하기"
    }
    
    private var statusColor: Color {
        if subLevel.isCompleted { return .green }
        if subLevel.progress > 0 { return .orange }
        if subLevel.isLocked { return .gray }
        return blockColor
    }
    
    @ViewBuilder
    private var lockOverlay: some View {
        if subLevel.isLocked {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial.opacity(0.3))
                
                VStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.title3)
                    
                    Text("이전 레벨 완료 필요")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: 16) {
        SubLevelCardView(
            subLevel: SubLevel(subLevelID: "6-3", blockID: 6, orderInBlock: 3, title: "1형 능동분사", concept: "فَاعِل 패턴", targetWordCount: 40, isLocked: false),
            blockColor: .orange,
            onTap: {}
        )
        
        SubLevelCardView(
            subLevel: SubLevel(subLevelID: "6-4", blockID: 6, orderInBlock: 4, title: "1형 수동분사", concept: "مَفْعُول 패턴", targetWordCount: 40, isLocked: true),
            blockColor: .orange,
            onTap: {}
        )
    }
    .padding()
    .background(Color.gray.opacity(0.1))
}
