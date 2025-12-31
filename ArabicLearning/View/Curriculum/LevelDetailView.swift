// LevelDetailView.swift
// Gateway view for each level with Active/Passive mode

import SwiftUI
import SwiftData

struct LevelDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var level: StudyLevel
    
    @State private var showingReading = false
    @State private var showingTest = false
    @State private var showingDailySession = false
    @State private var progressionResult: ProgressionResult?
    
    /// Determines if this is the active (current) level
    var isActiveLevel: Bool {
        // Active = not locked AND not passed, OR is the highest unlocked level
        !level.isLocked && !level.isPassed
    }
    
    /// Determines if this is a passive (cleared) level
    var isPassiveLevel: Bool {
        level.isPassed
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection
                
                // Progression Stats
                progressionSection
                
                Divider()
                
                // Gateway Actions (Dynamic based on level state)
                gatewayActions
                
                Spacer()
            }
            .padding()
        }
        .background(groupedBackground)
        .navigationTitle(level.displayTitle)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(isPresented: $showingReading) {
            PassageReadingView(level: level)
        }
        .sheet(isPresented: $showingTest) {
            StrictTypingQuizView(level: level)
        }
        .sheet(isPresented: $showingDailySession) {
            DailySessionView(level: level)
        }
        .onAppear {
            checkProgression()
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Level badge with state indicator
            ZStack {
                Circle()
                    .fill(levelColor.gradient)
                    .frame(width: 80, height: 80)
                
                if level.isPassed {
                    Image(systemName: "checkmark")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(.white)
                } else if level.isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.white.opacity(0.8))
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
            
            // Level State Badge
            levelStateBadge
        }
    }
    
    private var levelStateBadge: some View {
        Group {
            if level.isPassed {
                Label("통과됨", systemImage: "checkmark.seal.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(20)
            } else if isActiveLevel {
                Label("현재 학습중", systemImage: "flame.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(20)
            } else if level.isLocked {
                Label("잠김", systemImage: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.gray)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(20)
            }
        }
    }
    
    // MARK: - Progression Stats
    
    private var progressionSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                StatItem(
                    icon: "textformat.abc",
                    value: "\(level.wordCount)",
                    label: "단어"
                )
                
                StatItem(
                    icon: "percent",
                    value: "\(Int(level.bestScore * 100))%",
                    label: "최고 점수"
                )
                
                if let result = progressionResult {
                    StatItem(
                        icon: "graduationcap.fill",
                        value: "\(Int(result.masteryPercentage * 100))%",
                        label: "마스터리"
                    )
                }
            }
            .padding()
            .background(cardBackground)
            .cornerRadius(12)
            
            // Progression hint
            if let result = progressionResult, !level.isPassed {
                Text(result.reason)
                    .font(.caption)
                    .foregroundStyle(result.canUnlock ? .green : .secondary)
                    .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Gateway Actions (Dynamic)
    
    private var gatewayActions: some View {
        VStack(spacing: 16) {
            if level.isLocked {
                // Locked State
                lockedMessage
            } else if isActiveLevel {
                // Active Level: Daily Session + Reading + Test
                activeButtons
            } else if isPassiveLevel {
                // Passive Level: Review Only + Test
                passiveButtons
            }
        }
    }
    
    // MARK: - Active Level Buttons
    
    private var activeButtons: some View {
        VStack(spacing: 16) {
            // Primary: Daily Session (20/10 rule)
            ActionButton(
                title: "일일 학습 시작",
                subtitle: "복습 20개 + 신규 10개",
                icon: "flame.fill",
                color: .orange
            ) {
                showingDailySession = true
            }
            
            // Reading Practice
            ActionButton(
                title: "읽기 연습",
                subtitle: "문장을 읽고 단어 학습에 추가",
                icon: "book.fill",
                color: .green
            ) {
                showingReading = true
            }
            
            // Level Test
            ActionButton(
                title: "레벨 테스트",
                subtitle: "80% 이상 통과시 다음 레벨 해금",
                icon: "pencil.and.outline",
                color: .blue
            ) {
                showingTest = true
            }
        }
    }
    
    // MARK: - Passive Level Buttons
    
    private var passiveButtons: some View {
        VStack(spacing: 16) {
            // Review This Level (Original words only)
            ActionButton(
                title: "교과서 복습",
                subtitle: "이 레벨의 원래 단어만 복습",
                icon: "arrow.clockwise",
                color: .purple
            ) {
                showingDailySession = true
            }
            
            // Reading Practice
            ActionButton(
                title: "읽기 연습",
                subtitle: "지문 읽고 이해하기",
                icon: "book.fill",
                color: .green
            ) {
                showingReading = true
            }
            
            // Re-take Test
            ActionButton(
                title: "레벨 테스트 재도전",
                subtitle: "다시 테스트하기",
                icon: "pencil.and.outline",
                color: .gray
            ) {
                showingTest = true
            }
        }
    }
    
    // MARK: - Locked Message
    
    private var lockedMessage: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            
            Text("이전 레벨을 통과하면 해금됩니다")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(cardBackground.opacity(0.5))
        .cornerRadius(12)
    }
    
    // MARK: - Helpers
    
    private func checkProgression() {
        progressionResult = ProgressionManager.shared.checkProgression(
            for: level,
            unlockType: .test,
            context: modelContext
        )
    }
    
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

// MARK: - Stat Item

struct StatItem: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.secondary)
            
            Text(value)
                .font(.headline)
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Action Button

struct ActionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                    .frame(width: 44, height: 44)
                    .background(color.opacity(0.1))
                    .cornerRadius(12)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            #if os(iOS)
            .background(Color(uiColor: .secondarySystemBackground))
            #else
            .background(Color(nsColor: .controlBackgroundColor))
            #endif
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint(subtitle)
    }
}

// MARK: - Daily Session View (Placeholder)

struct DailySessionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let level: StudyLevel
    
    @State private var session: StudySession?
    @State private var currentIndex = 0
    @State private var showingResult = false
    
    var body: some View {
        NavigationStack {
            VStack {
                if let session = session {
                    if session.words.isEmpty {
                        emptyState
                    } else {
                        sessionContent(session)
                    }
                } else {
                    ProgressView("세션 준비 중...")
                        .onAppear { generateSession() }
                }
            }
            .navigationTitle(level.isPassed ? "교과서 복습" : "일일 학습")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)
            
            Text("오늘 학습 완료!")
                .font(.headline)
            
            Text("모든 복습과 신규 단어를 완료했습니다")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Button("닫기") { dismiss() }
                .buttonStyle(.borderedProminent)
        }
    }
    
    private func sessionContent(_ session: StudySession) -> some View {
        VStack(spacing: 16) {
            // Progress
            ProgressView(value: Double(currentIndex + 1), total: Double(session.words.count))
                .padding(.horizontal)
            
            Text("\(currentIndex + 1) / \(session.words.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            // Session stats
            HStack(spacing: 20) {
                Label("\(session.reviewWordsCount) 복습", systemImage: "arrow.clockwise")
                Label("\(session.newWordsCount) 신규", systemImage: "plus.circle")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            
            Spacer()
            
            // Current word
            if currentIndex < session.words.count {
                let word = session.words[currentIndex]
                
                VStack(spacing: 20) {
                    Text(word.arabic)
                        .font(.system(size: 48))
                    
                    Text(word.korean)
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Grade buttons
            gradeButtons
        }
        .padding()
    }
    
    private var gradeButtons: some View {
        HStack(spacing: 12) {
            gradeButton("다시", grade: .again, color: .red)
            gradeButton("어려움", grade: .hard, color: .orange)
            gradeButton("좋음", grade: .good, color: .blue)
            gradeButton("쉬움", grade: .easy, color: .green)
        }
    }
    
    private func gradeButton(_ title: String, grade: AnswerGrade, color: Color) -> some View {
        Button(action: { handleGrade(grade) }) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(color)
                .foregroundStyle(.white)
                .cornerRadius(10)
        }
    }
    
    private func generateSession() {
        let type: SessionType = level.isPassed ? .passive : .active
        session = QuizSessionGenerator.shared.generateSession(
            for: level,
            type: type,
            context: modelContext
        )
    }
    
    private func handleGrade(_ grade: AnswerGrade) {
        guard let session = session, currentIndex < session.words.count else { return }
        
        let word = session.words[currentIndex]
        
        // Update FSRS and check progression
        ProgressionManager.shared.handleAnswerResponse(
            word: word,
            grade: grade,
            context: modelContext
        )
        
        // Move to next
        if currentIndex < session.words.count - 1 {
            withAnimation {
                currentIndex += 1
            }
        } else {
            dismiss()
        }
    }
}
