// LearningHubView.swift
// Unified Learning Dashboard - The Centerpiece
// Uses Horizontal Scroll for Library, Enum-based logic

import SwiftUI
import SwiftData

struct LearningHubView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = LearningHubViewModel()
    @State private var showingCurriculumMap = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Level Selector Header (Trigger)
                    levelHeader
                    
                    // Progress Overview
                    progressSection
                    
                    // Dynamic Action Card (Centerpiece)
                    actionCard
                    
                    // Level Library - HORIZONTAL SCROLL
                    if !viewModel.passages.isEmpty || viewModel.currentLevel != nil {
                        librarySection
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding()
            }
            .background(groupedBackground)
            .navigationTitle("학습")
            .onAppear {
                viewModel.setup(context: modelContext)
            }
            .navigationDestination(isPresented: $showingCurriculumMap) {
                CurriculumMapView(onLevelSelected: { level in
                    viewModel.selectLevel(level)
                    showingCurriculumMap = false
                })
            }
            // Daily Session - FULL SCREEN NAVIGATION (not popup!)
            .navigationDestination(isPresented: $viewModel.showingDailySession) {
                if let level = viewModel.currentLevel {
                    StrictTypingQuizView(level: level)
                }
            }
            .navigationDestination(isPresented: $viewModel.showingStructureQuiz) {
                if let level = viewModel.currentLevel {
                    StrictTypingQuizView(level: level)
                }
            }
            .sheet(isPresented: $viewModel.showingPassageReading) {
                if let level = viewModel.currentLevel {
                    PassageReadingView(level: level)
                }
            }
        }
    }
    
    // MARK: - Level Header (Trigger)
    
    private var levelHeader: some View {
        Button(action: { showingCurriculumMap = true }) {
            HStack(spacing: 16) {
                // Level Badge
                ZStack {
                    Circle()
                        .fill(levelColor.gradient)
                        .frame(width: 56, height: 56)
                    
                    if let level = viewModel.currentLevel {
                        if level.isPassed {
                            Image(systemName: "checkmark")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                        } else {
                            Text("\(level.levelID)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                        }
                    }
                }
                
                // Level Info
                VStack(alignment: .leading, spacing: 4) {
                    Text("현재 레벨")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(viewModel.currentLevel?.displayTitle ?? "레벨 선택")
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    // Level Type Badge (Uses Enum!)
                    levelTypeBadge
                }
                
                Spacer()
                
                // Navigation Arrow
                VStack {
                    Image(systemName: "chevron.right")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    
                    Text("전환")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(cardBackground)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }
    
    /// Type badge using enum - NO magic numbers
    private var levelTypeBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: viewModel.currentLevelType.icon)
                .font(.caption2)
            Text(viewModel.currentLevelType.displayName)
                .font(.caption2)
        }
        .foregroundStyle(viewModel.currentActionColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(viewModel.currentActionColor.opacity(0.15))
        .cornerRadius(8)
    }
    
    // MARK: - Progress Section
    
    private var progressSection: some View {
        HStack(spacing: 12) {
            progressCard(
                title: "숙련도",
                value: "\(Int(viewModel.currentMastery * 100))%",
                icon: "chart.line.uptrend.xyaxis",
                color: .green
            )
            
            progressCard(
                title: "단어",
                value: "\(viewModel.currentLevel?.wordCount ?? 0)",
                icon: "textformat.abc",
                color: .blue
            )
            
            progressCard(
                title: "최고 점수",
                value: "\(Int((viewModel.currentLevel?.bestScore ?? 0) * 100))%",
                icon: "star.fill",
                color: .orange
            )
        }
    }
    
    private func progressCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(cardBackground)
        .cornerRadius(12)
    }
    
    // MARK: - Dynamic Action Card (Uses Enum - NO magic numbers!)
    
    private var actionCard: some View {
        VStack(spacing: 0) {
            // Main Action Button
            Button(action: { viewModel.startSession() }) {
                HStack(spacing: 16) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.2))
                            .frame(width: 56, height: 56)
                        
                        Image(systemName: viewModel.currentActionIcon)
                            .font(.title2)
                            .foregroundStyle(.white)
                    }
                    
                    // Text (Uses viewModel computed properties - enum based)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.currentActionTitle)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                        
                        Text(viewModel.currentActionSubtitle)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    // Play Button
                    ZStack {
                        Circle()
                            .fill(.white)
                            .frame(width: 48, height: 48)
                        
                        Image(systemName: "play.fill")
                            .font(.title3)
                            .foregroundStyle(viewModel.currentActionColor)
                    }
                }
                .padding(20)
                .background(
                    LinearGradient(
                        colors: [viewModel.currentActionColor, viewModel.currentActionColor.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(20)
                .shadow(color: viewModel.currentActionColor.opacity(0.4), radius: 12, y: 6)
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.isDailySessionAvailable)
            
            // NO separate Level Test button - auto-progression at 80% mastery
            // The daily session IS the study method
        }
    }
    
    // MARK: - Library Section (HORIZONTAL SCROLL!)
    
    private var librarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("레벨 라이브러리", systemImage: "books.vertical")
                    .font(.headline)
                
                Spacer()
                
                if viewModel.passages.count > 3 {
                    Button("전체 보기") {
                        // Could navigate to full list
                    }
                    .font(.caption)
                    .foregroundStyle(.blue)
                }
            }
            
            // HORIZONTAL SCROLL VIEW for compact dashboard
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Reading Practice Card
                    if let level = viewModel.currentLevel {
                        readingPracticeCard(level: level)
                    }
                    
                    // Passage Cards
                    ForEach(viewModel.passages.prefix(5)) { passage in
                        passageCard(passage)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    /// Reading practice card
    private func readingPracticeCard(level: StudyLevel) -> some View {
        NavigationLink {
            PassageReadingView(level: level)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: "book.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
                
                Text("읽기 연습")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("탭하여 단어 학습")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 120, height: 100)
            .padding()
            .background(cardBackground)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    /// Compact passage card for horizontal scroll
    private func passageCard(_ passage: ReadingPassage) -> some View {
        Button(action: { viewModel.openPassage(passage) }) {
            VStack(alignment: .leading, spacing: 8) {
                Text(passage.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                Text(passage.content.prefix(40) + "...")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                
                Spacer()
                
                HStack {
                    Image(systemName: "doc.text")
                        .font(.caption2)
                    Text("읽기")
                        .font(.caption2)
                }
                .foregroundStyle(.blue)
            }
            .frame(width: 140, height: 100)
            .padding()
            .background(cardBackground)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Helpers
    
    private var levelColor: Color {
        viewModel.currentActionColor
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
