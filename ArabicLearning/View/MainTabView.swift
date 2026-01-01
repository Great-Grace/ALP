// MainTabView.swift
// Unified 2-Tab Navigation: Learning + Management

import SwiftUI
import SwiftData

struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Learning Hub (학습)
            LearningHubView()
                .tabItem {
                    Label("학습", systemImage: "graduationcap.fill")
                }
                .tag(0)
            
            // Tab 2: Management (관리)
            ManagementView()
                .tabItem {
                    Label("관리", systemImage: "gearshape.fill")
                }
                .tag(1)
        }
    }
}

// MARK: - Management View (Support Center)

struct ManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var words: [Word]
    @Query(sort: \StudyLevel.levelID) private var levels: [StudyLevel]
    
    @State private var showingAdmin = false
    
    var body: some View {
        NavigationStack {
            List {
                // FSRS Stats Section
                Section("학습 통계") {
                    statsRow(icon: "textformat.abc", title: "총 단어", value: "\(words.count)개", color: .blue)
                    statsRow(icon: "star.fill", title: "마스터", value: "\(masteredCount)개", color: .yellow)
                    statsRow(icon: "flame.fill", title: "학습중", value: "\(learningCount)개", color: .orange)
                    statsRow(icon: "clock.fill", title: "신규", value: "\(newCount)개", color: .gray)
                }
                
                // Level Progress
                Section("레벨별 진행") {
                    ForEach(levels) { level in
                        levelRow(level)
                    }
                }
                
                // Actions
                Section("데이터 관리") {
                    NavigationLink {
                        AdminView()
                    } label: {
                        Label("고급 관리", systemImage: "wrench.and.screwdriver")
                    }
                }
                
                // App Info
                Section {
                    HStack {
                        Text("버전")
                        Spacer()
                        Text("3.0 (Unified Hub)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("관리")
        }
    }
    
    // MARK: - Computed Stats
    
    private var masteredCount: Int {
        words.filter { $0.status == .mastered }.count
    }
    
    private var learningCount: Int {
        words.filter { $0.status == .learning }.count
    }
    
    private var newCount: Int {
        words.filter { $0.status == .new }.count
    }
    
    // MARK: - Row Builders
    
    private func statsRow(icon: String, title: String, value: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
            
            Text(title)
            
            Spacer()
            
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
    
    private func levelRow(_ level: StudyLevel) -> some View {
        HStack {
            // Status Icon
            Image(systemName: level.isPassed ? "checkmark.circle.fill" : level.isLocked ? "lock.fill" : "circle")
                .foregroundStyle(level.isPassed ? .green : level.isLocked ? .gray : .orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(level.displayTitle)
                    .font(.subheadline)
                
                if !level.isLocked {
                    ProgressView(value: level.bestScore)
                        .tint(level.isPassed ? .green : .blue)
                }
            }
            
            Spacer()
            
            if level.isPassed {
                Text("\(Int(level.bestScore * 100))%")
                    .font(.caption)
                    .foregroundStyle(.green)
            } else {
                Text("\(level.wordCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [Word.self, StudyLevel.self])
}
