// CurriculumMapView.swift
// Full-screen level selection and curriculum overview

import SwiftUI
import SwiftData

struct CurriculumMapView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query(sort: \StudyLevel.levelID) private var levels: [StudyLevel]
    
    @State private var selectedLevel: StudyLevel?
    @State private var showingLevelDetail = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Stats
                    progressHeader
                    
                    // Level Cards
                    LazyVStack(spacing: 16) {
                        ForEach(levels) { level in
                            LevelMapCard(level: level) {
                                selectedLevel = level
                                showingLevelDetail = true
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(groupedBackground)
            .navigationTitle("커리큘럼")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { dismiss() }
                }
            }
            .sheet(isPresented: $showingLevelDetail) {
                if let level = selectedLevel {
                    NavigationStack {
                        LevelDetailView(level: level)
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button("닫기") { showingLevelDetail = false }
                                }
                            }
                    }
                }
            }
        }
    }
    
    // MARK: - Progress Header
    
    private var progressHeader: some View {
        VStack(spacing: 16) {
            // Progress Ring
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                    .frame(width: 100, height: 100)
                
                Circle()
                    .trim(from: 0, to: progressPercentage)
                    .stroke(
                        LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                
                VStack {
                    Text("\(Int(progressPercentage * 100))%")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("완료")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Stats Row
            HStack(spacing: 32) {
                VStack {
                    Text("\(passedCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.green)
                    Text("통과한 레벨")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                VStack {
                    Text("\(levels.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("전체 레벨")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                VStack {
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
        .padding()
        .background(cardBackground)
        .cornerRadius(16)
        .padding(.horizontal)
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

// MARK: - Level Map Card

struct LevelMapCard: View {
    let level: StudyLevel
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
                            .foregroundStyle(.white.opacity(0.7))
                    } else {
                        Text("\(level.levelID)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    }
                }
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(level.displayTitle)
                        .font(.headline)
                        .foregroundStyle(level.isLocked ? .secondary : .primary)
                    
                    Text(level.levelDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    // Progress bar
                    if !level.isLocked {
                        ProgressView(value: level.bestScore)
                            .tint(level.isPassed ? .green : .blue)
                    }
                }
                
                Spacer()
                
                // Status/Score
                VStack {
                    if level.isPassed {
                        Text("\(Int(level.bestScore * 100))%")
                            .font(.headline)
                            .foregroundStyle(.green)
                    } else if !level.isLocked {
                        Text("\(level.wordCount)")
                            .font(.headline)
                        Text("단어")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding()
            #if os(iOS)
            .background(Color(uiColor: .systemBackground))
            #else
            .background(Color(nsColor: .controlBackgroundColor))
            #endif
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .disabled(level.isLocked)
        .opacity(level.isLocked ? 0.6 : 1.0)
    }
}

#Preview {
    CurriculumMapView()
        .modelContainer(for: [Word.self, StudyLevel.self])
}
