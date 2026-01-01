// CurriculumMapView.swift
// Full-Screen Level Selection - Strategic Map

import SwiftUI
import SwiftData

struct CurriculumMapView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query(sort: \StudyLevel.levelID) private var levels: [StudyLevel]
    
    var onLevelSelected: ((StudyLevel) -> Void)?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Progress Overview
                progressHeader
                
                // Level Roadmap
                levelRoadmap
                
                // Tips Section
                tipsSection
            }
            .padding()
        }
        .background(groupedBackground)
        .navigationTitle("커리큘럼")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
    }
    
    // MARK: - Progress Header
    
    private var progressHeader: some View {
        VStack(spacing: 20) {
            // Progress Ring
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 14)
                    .frame(width: 120, height: 120)
                
                Circle()
                    .trim(from: 0, to: progressPercentage)
                    .stroke(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(duration: 0.8), value: progressPercentage)
                
                VStack(spacing: 2) {
                    Text("\(Int(progressPercentage * 100))%")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("완료")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Stats Row
            HStack(spacing: 40) {
                VStack(spacing: 4) {
                    Text("\(passedCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.green)
                    Text("통과")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                VStack(spacing: 4) {
                    Text("\(levels.count - passedCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.orange)
                    Text("진행중")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                VStack(spacing: 4) {
                    Text("\(totalWords)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.blue)
                    Text("총 단어")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(24)
        .background(cardBackground)
        .cornerRadius(20)
    }
    
    // MARK: - Level Roadmap
    
    private var levelRoadmap: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("학습 로드맵")
                .font(.headline)
            
            ForEach(levels) { level in
                LevelRoadmapCard(
                    level: level,
                    isSelected: false,
                    onTap: {
                        if !level.isLocked {
                            onLevelSelected?(level)
                            dismiss()
                        }
                    }
                )
            }
        }
    }
    
    // MARK: - Tips Section
    
    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("학습 팁", systemImage: "lightbulb.fill")
                .font(.headline)
                .foregroundStyle(.orange)
            
            VStack(alignment: .leading, spacing: 8) {
                tipRow(icon: "1.circle.fill", text: "레벨 1-3은 어휘 중심 학습")
                tipRow(icon: "2.circle.fill", text: "레벨 4-5는 문법/구조 학습")
                tipRow(icon: "3.circle.fill", text: "80% 이상 마스터리로 다음 레벨 해금")
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    private func tipRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.orange)
            Text(text)
                .font(.subheadline)
        }
    }
    
    // MARK: - Computed
    
    private var passedCount: Int {
        levels.filter { $0.isPassed }.count
    }
    
    private var progressPercentage: Double {
        guard !levels.isEmpty else { return 0 }
        return Double(passedCount) / Double(levels.count)
    }
    
    private var totalWords: Int {
        levels.reduce(0) { $0 + $1.wordCount }
    }
    
    private var groupedBackground: Color {
        #if os(iOS)
        return Color(uiColor: .systemGroupedBackground)
        #else
        return Color(nsColor: .windowBackgroundColor)
        #endif
    }
    
    private var cardBackground: Color {
        #if os(iOS)
        return Color(uiColor: .systemBackground)
        #else
        return Color(nsColor: .controlBackgroundColor)
        #endif
    }
}

// MARK: - Level Roadmap Card

struct LevelRoadmapCard: View {
    let level: StudyLevel
    let isSelected: Bool
    let onTap: () -> Void
    
    private var levelColor: Color {
        if level.isLocked { return .gray }
        if level.isPassed { return .green }
        
        switch level.levelID {
        case 1: return .blue
        case 2: return .green
        case 3: return .orange
        case 4: return .purple
        case 5: return .red
        default: return .blue
        }
    }
    
    private var levelType: String {
        switch level.levelID {
        case 1...3: return "어휘"
        case 4...5: return "구조"
        default: return "어휘"
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Level Badge
                ZStack {
                    Circle()
                        .fill(levelColor.gradient)
                        .frame(width: 56, height: 56)
                    
                    if level.isPassed {
                        Image(systemName: "checkmark")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    } else if level.isLocked {
                        Image(systemName: "lock.fill")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.7))
                    } else {
                        Text("\(level.levelID)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    }
                }
                
                // Info
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(level.displayTitle)
                            .font(.headline)
                            .foregroundStyle(level.isLocked ? .secondary : .primary)
                        
                        // Type Badge
                        Text(levelType)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(levelColor.opacity(0.15))
                            .foregroundStyle(levelColor)
                            .cornerRadius(4)
                    }
                    
                    Text("\(level.wordCount) 단어 · \(level.levelDescription)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    
                    // Progress Bar
                    if !level.isLocked {
                        ProgressView(value: level.bestScore)
                            .tint(level.isPassed ? .green : levelColor)
                    }
                }
                
                Spacer()
                
                // Right Indicator
                VStack(alignment: .trailing, spacing: 4) {
                    if level.isPassed {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    } else if !level.isLocked {
                        Text("\(Int(level.bestScore * 100))%")
                            .font(.headline)
                            .foregroundStyle(levelColor)
                    }
                    
                    if !level.isLocked {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            #if os(iOS)
            .background(Color(uiColor: .systemBackground))
            #else
            .background(Color(nsColor: .controlBackgroundColor))
            #endif
            .cornerRadius(16)
            .opacity(level.isLocked ? 0.6 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(level.isLocked)
    }
}

#Preview {
    NavigationStack {
        CurriculumMapView()
    }
    .modelContainer(for: [Word.self, StudyLevel.self])
}
