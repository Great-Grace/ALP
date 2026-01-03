// StrictTypingQuizView.swift
// Unified Study Interface with Implicit FSRS
// NO manual Easy/Hard buttons - behavior-based grading

import SwiftUI
import SwiftData

struct StrictTypingQuizView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let level: StudyLevel
    
    @State private var viewModel = StrictTypingQuizViewModel()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress Bar
                ProgressView(value: viewModel.progress)
                    .tint(.blue)
                    .padding()
                
                switch viewModel.quizState {
                case .loading:
                    loadingView
                case .active, .showingFeedback:
                    if let word = viewModel.currentWord {
                        quizContent(word: word)
                    }
                case .completed:
                    resultView
                case .levelUp:
                    levelUpView
                }
            }
            .background(groupedBackground)
            .navigationTitle("학습: \(level.displayTitle)")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("종료") { dismiss() }
                }
                
                if viewModel.quizState == .active || viewModel.quizState == .showingFeedback(isCorrect: true) || viewModel.quizState == .showingFeedback(isCorrect: false) {
                    ToolbarItem(placement: .confirmationAction) {
                        Text(viewModel.questionCount)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onAppear {
                viewModel.setup(level: level, context: modelContext)
            }
            .alert("🎉 레벨 업!", isPresented: $viewModel.showLevelUpAlert) {
                Button("확인") { dismiss() }
            } message: {
                Text("\(viewModel.unlockedLevelName)이 해금되었습니다!")
            }
        }
    }
    
    // MARK: - Quiz Content
    
    private func quizContent(word: Word) -> some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Korean Meaning (What to translate)
            VStack(spacing: 12) {
                Text("아랍어로 쓰세요")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Text(word.korean)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                if let root = word.root, !root.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "cube")
                            .font(.caption2)
                        Text("어근: \(root)")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .padding()
            
            // Input Field
            VStack(spacing: 8) {
                TextField("아랍어를 입력하세요", text: $viewModel.userInput)
                    .font(.system(size: 28))
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.plain)
                    .padding()
                    .background(cardBackground)
                    .cornerRadius(12)
                    .environment(\.layoutDirection, .rightToLeft)
                    .onChange(of: viewModel.userInput) { oldValue, newValue in
                        // "1" key pressed → Hint / Reveal toggle
                        if newValue.contains("1") {
                            // Remove the "1" from input
                            viewModel.userInput = oldValue
                            
                            // Toggle hint → reveal
                            if !viewModel.usedHint {
                                viewModel.requestHint()
                            } else if !viewModel.usedReveal {
                                viewModel.revealAnswer()
                            }
                            return
                        }
                        
                        // Filter: Arabic only (block English, numbers, symbols)
                        let filtered = newValue.filter { char in
                            // Allow Arabic letters (0x0600-0x06FF) and space
                            let scalar = char.unicodeScalars.first?.value ?? 0
                            return (scalar >= 0x0600 && scalar <= 0x06FF) || char == " "
                        }
                        
                        if filtered != newValue {
                            viewModel.userInput = filtered
                            return
                        }
                        
                        // Auto-submit when input matches (vowel-stripped comparison)
                        if !newValue.isEmpty, viewModel.quizState == .active {
                            if let word = viewModel.currentWord,
                               ArabicUtils.isStrictMatch(newValue, word.arabic) {
                                viewModel.checkAnswer()
                            }
                        }
                    }
                
                // Feedback Message
                if !viewModel.feedbackMessage.isEmpty {
                    Text(viewModel.feedbackMessage)
                        .font(.title3)  // Larger feedback text
                        .fontWeight(.medium)
                        .foregroundStyle(feedbackColor)
                        .transition(.opacity)
                        .padding(.top, 8)
                }
            }
            .padding(.horizontal)
            
            // Help Buttons (Hint / Reveal) - LARGER SIZE
            if viewModel.quizState == .active {
                HStack(spacing: 20) {
                    // Hint Button (shows first letter) - Press "1" to activate
                    Button(action: { viewModel.requestHint() }) {
                        HStack(spacing: 8) {
                            Image(systemName: "lightbulb.fill")
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("힌트")
                                    .font(.headline)
                                Text("1키")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .foregroundStyle(viewModel.usedHint ? .gray : .orange)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .frame(minWidth: 120)
                        .background(Color.orange.opacity(viewModel.usedHint ? 0.05 : 0.15))
                        .cornerRadius(16)
                    }
                    .disabled(viewModel.usedHint)
                    
                    // Reveal Button (shows answer) - Press "1" again to reveal
                    Button(action: { viewModel.revealAnswer() }) {
                        HStack(spacing: 8) {
                            Image(systemName: "eye.fill")
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("정답 보기")
                                    .font(.headline)
                                Text("1키 x2")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .foregroundStyle(viewModel.usedReveal ? .gray : .blue)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .frame(minWidth: 120)
                        .background(Color.blue.opacity(viewModel.usedReveal ? 0.05 : 0.15))
                        .cornerRadius(16)
                    }
                    .disabled(viewModel.usedReveal)
                }
                .padding(.top, 16)
            }
            
            Spacer()
            
            // Submit Button
            Button(action: { viewModel.checkAnswer() }) {
                Text("확인")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.userInput.isEmpty ? Color.gray : Color.blue)
                    .cornerRadius(12)
            }
            .disabled(viewModel.userInput.isEmpty || viewModel.quizState != .active)
            .padding()
        }
    }
    
    private var feedbackColor: Color {
        if case .showingFeedback(let isCorrect) = viewModel.quizState {
            return isCorrect ? .green : .red
        }
        return viewModel.usedHint || viewModel.usedReveal ? .orange : .secondary
    }
    
    // MARK: - Result View
    
    private var resultView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Score Circle
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                    .frame(width: 150, height: 150)
                
                Circle()
                    .trim(from: 0, to: viewModel.scorePercentage)
                    .stroke(
                        scoreColor,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 150, height: 150)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: viewModel.scorePercentage)
                
                VStack {
                    Text("\(Int(viewModel.scorePercentage * 100))%")
                        .font(.system(size: 40, weight: .bold))
                    
                    Text("\(viewModel.score)/\(viewModel.words.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Implicit Grade Stats
            VStack(spacing: 12) {
                Text("학습 결과")
                    .font(.headline)
                
                HStack(spacing: 20) {
                    gradeStatView(emoji: "🎯", label: "Easy", count: viewModel.easyCount, color: .green)
                    gradeStatView(emoji: "✓", label: "Good", count: viewModel.goodCount, color: .blue)
                    gradeStatView(emoji: "💪", label: "Hard", count: viewModel.hardCount, color: .orange)
                    gradeStatView(emoji: "🔄", label: "Again", count: viewModel.againCount, color: .red)
                }
            }
            .padding()
            .background(cardBackground)
            .cornerRadius(12)
            
            Spacer()
            
            // Action Buttons
            VStack(spacing: 12) {
                Button(action: { dismiss() }) {
                    Text("완료")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                
                Button(action: { viewModel.retry() }) {
                    Text("다시 학습")
                        .font(.headline)
                        .foregroundStyle(.blue)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                }
            }
            .padding()
        }
    }
    
    private func gradeStatView(emoji: String, label: String, count: Int, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(emoji)
                .font(.title2)
            Text("\(count)")
                .font(.headline)
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
    
    private var scoreColor: Color {
        if viewModel.scorePercentage >= 0.8 {
            return .green
        } else if viewModel.scorePercentage >= 0.5 {
            return .orange
        } else {
            return .red
        }
    }
    
    // MARK: - Level Up View
    
    private var levelUpView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "star.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.yellow)
            
            Text("🎉 축하합니다!")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("\(viewModel.unlockedLevelName)")
                .font(.title2)
                .foregroundStyle(.secondary)
            
            Text("새로운 레벨이 해금되었습니다!")
                .font(.headline)
                .foregroundStyle(.green)
            
            Spacer()
            
            Button(action: { dismiss() }) {
                Text("계속하기")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .cornerRadius(12)
            }
            .padding()
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack {
            ProgressView()
            Text("문제 로딩 중...")
                .foregroundStyle(.secondary)
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

#Preview {
    StrictTypingQuizView(level: StudyLevel(levelID: 1, title: "기초 동사"))
        .modelContainer(for: [StudyLevel.self, Word.self])
}
