// MainTabView.swift
// Unified Tab Navigation: Learning + Management

import SwiftUI
import SwiftData

struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Learning Hub (Unified Learning Experience)
            LearningHubView()
                .tabItem {
                    Label("학습", systemImage: "graduationcap.fill")
                }
                .tag(0)
            
            // Tab 2: Management (Settings, Stats, Admin)
            ManagementView()
                .tabItem {
                    Label("관리", systemImage: "gearshape.fill")
                }
                .tag(1)
        }
    }
}

// MARK: - Management View (Consolidated Admin)

struct ManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var words: [Word]
    @Query private var levels: [StudyLevel]
    
    var body: some View {
        NavigationStack {
            List {
                // Stats Section
                Section("학습 통계") {
                    statsRow(icon: "textformat.abc", title: "총 단어", value: "\(words.count)개")
                    statsRow(icon: "graduationcap", title: "레벨", value: "\(levels.count)개")
                    statsRow(icon: "star.fill", title: "마스터한 단어", value: "\(masteredCount)개")
                }
                
                // Progress Section
                Section("진행 상황") {
                    ForEach(levels.sorted(by: { $0.levelID < $1.levelID })) { level in
                        levelProgressRow(level)
                    }
                }
                
                // Data Management
                Section("데이터 관리") {
                    NavigationLink {
                        AdminView()
                    } label: {
                        Label("고급 관리", systemImage: "wrench.and.screwdriver")
                    }
                }
                
                // App Info
                Section("정보") {
                    HStack {
                        Text("버전")
                        Spacer()
                        Text("2.0 (Adaptive Engine)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("관리")
        }
    }
    
    private var masteredCount: Int {
        words.filter { $0.status == .mastered }.count
    }
    
    private func statsRow(icon: String, title: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.blue)
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
    
    private func levelProgressRow(_ level: StudyLevel) -> some View {
        HStack {
            Image(systemName: level.statusIcon)
                .foregroundStyle(level.isPassed ? .green : level.isLocked ? .gray : .orange)
            
            VStack(alignment: .leading) {
                Text(level.displayTitle)
                    .font(.subheadline)
                Text("\(level.wordCount) 단어")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if level.isPassed {
                Text("\(Int(level.bestScore * 100))%")
                    .foregroundStyle(.green)
            }
        }
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [Word.self, StudyLevel.self])
}
