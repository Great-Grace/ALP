// LevelDetailView.swift
// Hub view for a specific level showing study options

import SwiftUI
import SwiftData

struct LevelDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var level: StudyLevel
    
    @State private var showingFlashcards = false
    @State private var showingReading = false
    @State private var showingTest = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection
                
                // Stats
                statsSection
                
                Divider()
                
                // Actions
                actionButtons
                
                Spacer()
            }
            .padding()
        }
        .background(groupedBackground)
        .navigationTitle(level.displayTitle)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(isPresented: $showingFlashcards) {
            FlashcardStudyView(level: level)
        }
        .sheet(isPresented: $showingReading) {
            PassageReadingView(level: level)
        }
        .sheet(isPresented: $showingTest) {
            StrictTypingQuizView(level: level)
        }
    }
    
    // MARK: - Header
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Level badge
            ZStack {
                Circle()
                    .fill(levelColor.gradient)
                    .frame(width: 80, height: 80)
                
                if level.isPassed {
                    Image(systemName: "checkmark")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Text("\(level.levelID)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            
            Text(level.displayTitle)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(level.levelDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            // Status
            if level.isPassed {
                Label("통과됨", systemImage: "checkmark.seal.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(20)
            }
        }
    }
    
    // MARK: - Stats
    private var statsSection: some View {
        HStack(spacing: 20) {
            StatItem(
                icon: "textformat.abc",
                value: "\(level.wordCount)",
                label: "단어"
            )
            
            StatItem(
                icon: "doc.text",
                value: "\(level.passageCount)",
                label: "읽기 자료"
            )
            
            StatItem(
                icon: "percent",
                value: "\(Int(level.bestScore * 100))%",
                label: "최고 점수"
            )
        }
        .padding()
        .background(cardBackground)
        .cornerRadius(12)
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: 16) {
            // Study Button
            ActionButton(
                title: "단어 학습",
                subtitle: "플래시카드로 단어 암기",
                icon: "rectangle.stack.fill",
                color: .blue
            ) {
                showingFlashcards = true
            }
            
            // Reading Button (if passages exist)
            if level.passageCount > 0 {
                ActionButton(
                    title: "읽기 연습",
                    subtitle: "지문 읽고 이해하기",
                    icon: "book.fill",
                    color: .green
                ) {
                    showingReading = true
                }
            }
            
            // Test Button
            ActionButton(
                title: "레벨 테스트",
                subtitle: level.isPassed ? "다시 도전하기" : "80% 이상 통과시 다음 레벨 해금",
                icon: "pencil.and.outline",
                color: level.isPassed ? .gray : .orange
            ) {
                showingTest = true
            }
        }
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
    
    // MARK: - Platform Colors
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

// MARK: - Supporting Views

struct StatItem: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ActionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    static var cardBackground: Color {
        #if os(iOS)
        return Color(uiColor: .systemBackground)
        #else
        return Color(nsColor: .controlBackgroundColor)
        #endif
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .background(color.gradient)
                    .cornerRadius(12)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(ActionButton.cardBackground)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint(subtitle)
    }
}

// MARK: - Placeholder Views (to be implemented)

struct FlashcardStudyView: View {
    let level: StudyLevel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("플래시카드 학습")
                    .font(.title)
                Text("\(level.wordCount)개 단어")
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("단어 학습")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }
}

struct PassageReadingView: View {
    let level: StudyLevel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("읽기 연습")
                    .font(.title)
                Text("\(level.passageCount)개 지문")
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("읽기")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }
}
