// CurriculumView.swift
// Main view showing level-based curriculum progression

import SwiftUI
import SwiftData

struct CurriculumView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Query(sort: \StudyLevel.levelID) private var levels: [StudyLevel]
    
    @State private var selectedLevel: StudyLevel?
    @State private var showingDetail = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // ⚠️ Data Loss Warning Banner
                    if appState.isInMemoryMode {
                        dataLossWarningBanner
                    }
                    
                    // Header
                    headerSection
                    
                    // Level List
                    LazyVStack(spacing: 12) {
                        ForEach(levels) { level in
                            LevelCard(level: level)
                                .onTapGesture {
                                    if !level.isLocked {
                                        selectedLevel = level
                                        showingDetail = true
                                    }
                                }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(groupedBackground)
            .navigationTitle("커리큘럼")
            .navigationDestination(isPresented: $showingDetail) {
                if let level = selectedLevel {
                    LevelDetailView(level: level)
                }
            }
            .onAppear {
                seedLevelsIfNeeded()
            }
        }
    }
    
    // MARK: - Data Loss Warning Banner
    private var dataLossWarningBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(.white)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("데이터 저장 불가")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Text("임시 모드로 실행 중. 앱 종료 시 진행 상황이 사라집니다.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.9))
            }
            
            Spacer()
        }
        .padding()
        .background(Color.red.gradient)
        .cornerRadius(12)
        .padding(.horizontal)
        .accessibilityLabel("경고: 데이터 저장 불가")
        .accessibilityHint("임시 모드로 실행 중입니다. 앱 종료 시 진행 상황이 사라집니다.")
    }
    
    // MARK: - Header
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("아랍어 동사 마스터")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("레벨별로 동사를 학습하고 테스트를 통과하세요")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            // Progress
            if !levels.isEmpty {
                let passed = levels.filter { $0.isPassed }.count
                HStack {
                    Text("진행률")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    ProgressView(value: Double(passed), total: Double(levels.count))
                        .tint(.green)
                    
                    Text("\(passed)/\(levels.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial)
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    // MARK: - Seed Levels
    private func seedLevelsIfNeeded() {
        if levels.isEmpty {
            StudyLevel.seedLevels(context: modelContext)
        }
    }
    
    // MARK: - Platform Colors
    private var groupedBackground: Color {
        #if os(iOS)
        return Color(uiColor: .systemGroupedBackground)
        #else
        return Color(nsColor: .windowBackgroundColor)
        #endif
    }
}

// MARK: - Level Card

struct LevelCard: View {
    let level: StudyLevel
    
    var body: some View {
        HStack(spacing: 16) {
            // Level Number
            ZStack {
                Circle()
                    .fill(level.isLocked ? Color.gray.opacity(0.3) : levelColor)
                    .frame(width: 50, height: 50)
                
                if level.isPassed {
                    Image(systemName: "checkmark")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                } else if level.isLocked {
                    Image(systemName: "lock.fill")
                        .font(.title3)
                        .foregroundStyle(.gray)
                } else {
                    Text("\(level.levelID)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }
            }
            
            // Level Info
            VStack(alignment: .leading, spacing: 4) {
                Text(level.displayTitle)
                    .font(.headline)
                    .foregroundStyle(level.isLocked ? .secondary : .primary)
                
                Text(level.levelDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if level.bestScore > 0 {
                    Text("최고 점수: \(Int(level.bestScore * 100))%")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                }
            }
            
            Spacer()
            
            // Status Icon
            Image(systemName: level.isLocked ? "chevron.right" : "chevron.right.circle.fill")
                .font(.title3)
                .foregroundStyle(level.isLocked ? Color.gray : Color.blue)
        }
        .padding()
        .background(level.isLocked ? Color.gray.opacity(0.1) : cardBackground)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
        .opacity(level.isLocked ? 0.7 : 1.0)
    }
    
    private var levelColor: Color {
        switch level.levelID {
        case 1: return .blue
        case 2: return .green
        case 3: return .orange
        case 4: return .purple
        case 5: return .red
        default: return .blue
        }
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
    CurriculumView()
        .modelContainer(for: [StudyLevel.self, Word.self])
}
