// LearningHubView.swift
// Unified Learning Dashboard with Level-Dependent Actions

import SwiftUI
import SwiftData

struct LearningHubView: View {
    @Environment(\.modelContext) private var modelContext
    
    // Queries
    @Query(sort: \StudyLevel.levelID) private var levels: [StudyLevel]
    
    // State
    @State private var showingCurriculumMap = false
    @State private var showingDailySession = false
    @State private var showingReading = false
    @State private var showingTest = false
    
    /// Current active level (first unlocked, non-passed)
    private var currentLevel: StudyLevel? {
        levels.first { !$0.isLocked && !$0.isPassed } ?? levels.last
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Level Selector Header
                    levelSelectorHeader
                    
                    // Today's Progress
                    todayProgressSection
                    
                    // Primary Action (Level-Dependent)
                    if let level = currentLevel {
                        primaryActionSection(for: level)
                    }
                    
                    // Reading Library Section
                    readingSection
                    
                    // Quick Stats
                    quickStatsSection
                }
                .padding()
            }
            .background(groupedBackground)
            .navigationTitle("아랍어 학습")
            .sheet(isPresented: $showingCurriculumMap) {
                CurriculumMapView()
            }
            .sheet(isPresented: $showingDailySession) {
                if let level = currentLevel {
                    DailySessionView(level: level)
                }
            }
            .sheet(isPresented: $showingReading) {
                if let level = currentLevel {
                    PassageReadingView(level: level)
                }
            }
            .sheet(isPresented: $showingTest) {
                if let level = currentLevel {
                    StrictTypingQuizView(level: level)
                }
            }
        }
    }
    
    // MARK: - Level Selector Header
    
    private var levelSelectorHeader: some View {
        Button(action: { showingCurriculumMap = true }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("현재 레벨")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(currentLevel?.displayTitle ?? "레벨 선택")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                }
                
                Spacer()
                
                // Level Badge
                ZStack {
                    Circle()
                        .fill(levelColor.gradient)
                        .frame(width: 50, height: 50)
                    
                    if let level = currentLevel {
                        if level.isPassed {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.white)
                                .fontWeight(.bold)
                        } else {
                            Text("\(level.levelID)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                        }
                    }
                }
                
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(cardBackground)
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Today's Progress
    
    private var todayProgressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("오늘의 진도")
                .font(.headline)
            
            HStack(spacing: 16) {
                progressItem(
                    icon: "flame.fill",
                    value: "0",
                    label: "학습",
                    color: .orange
                )
                
                progressItem(
                    icon: "arrow.clockwise",
                    value: "0",
                    label: "복습",
                    color: .blue
                )
                
                progressItem(
                    icon: "checkmark.circle",
                    value: "0",
                    label: "완료",
                    color: .green
                )
            }
            .padding()
            .background(cardBackground)
            .cornerRadius(12)
        }
    }
    
    private func progressItem(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            
            Text(value)
                .font(.headline)
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Primary Action (Level-Dependent)
    
    private func primaryActionSection(for level: StudyLevel) -> some View {
        VStack(spacing: 16) {
            // Main Study Button
            Button(action: { showingDailySession = true }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("오늘의 학습 시작")
                            .font(.headline)
                            .foregroundStyle(.white)
                        
                        Text("복습 20개 + 신규 10개")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.white)
                }
                .padding()
                .background(
                    LinearGradient(
                        colors: [.orange, .red],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
            }
            .buttonStyle(.plain)
            
            // Test Button
            Button(action: { showingTest = true }) {
                HStack {
                    Image(systemName: "pencil.and.outline")
                        .foregroundStyle(.blue)
                    
                    Text("레벨 테스트")
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    if level.bestScore > 0 {
                        Text("최고: \(Int(level.bestScore * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(cardBackground)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Reading Section
    
    private var readingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("📖 읽기 연습")
                    .font(.headline)
                
                Spacer()
            }
            
            Button(action: { showingReading = true }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("문장 읽기")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("단어를 탭해서 학습에 추가")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "book.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                }
                .padding()
                .background(cardBackground)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Quick Stats
    
    private var quickStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("통계")
                .font(.headline)
            
            HStack(spacing: 12) {
                statCard(
                    title: "레벨 진행",
                    value: "\(passedLevelsCount)/\(levels.count)",
                    icon: "flag.fill",
                    color: .purple
                )
                
                statCard(
                    title: "학습 단어",
                    value: "\(currentLevel?.wordCount ?? 0)",
                    icon: "textformat.abc",
                    color: .blue
                )
            }
        }
    }
    
    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Spacer()
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .cornerRadius(12)
    }
    
    // MARK: - Helpers
    
    private var passedLevelsCount: Int {
        levels.filter { $0.isPassed }.count
    }
    
    private var levelColor: Color {
        guard let level = currentLevel else { return .blue }
        switch level.levelID {
        case 1: return .blue
        case 2: return .green
        case 3: return .orange
        case 4: return .purple
        case 5: return .red
        default: return .blue
        }
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

#Preview {
    LearningHubView()
        .modelContainer(for: [Word.self, StudyLevel.self])
}
