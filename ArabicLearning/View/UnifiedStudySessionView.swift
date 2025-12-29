// UnifiedStudySessionView.swift
// Unified Quiz Session with Cloze and Dual-Column support

import SwiftUI
import SwiftData

struct UnifiedStudySessionView: View {
    let quizState: QuizState
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var viewModel = UnifiedStudyViewModel()
    @State private var showExitConfirm = false
    
    // Animation trigger
    @State private var animationTrigger: Int = 0
    
    var body: some View {
        ZStack {
            // Background
            backgroundLayer
            
            VStack(spacing: 0) {
                // Header
                sessionHeader
                
                // Progress Bar
                if viewModel.sessionState != .completed {
                    progressBar
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                }
                
                // Main Content
                mainContent
            }
        }
        .onAppear {
            viewModel.setup(context: modelContext)
            viewModel.startUnifiedSession(quizState: quizState)
        }
        .alert("학습을 중단하시겠습니까?", isPresented: $showExitConfirm) {
            Button("계속하기", role: .cancel) {}
            Button("종료", role: .destructive) { dismiss() }
        } message: {
            Text("진행 상황은 자동 저장됩니다.")
        }
    }
    
    // MARK: - Background
    private var backgroundLayer: some View {
        LinearGradient(
            colors: [Color.white, Color.gray.opacity(0.1)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Header
    private var sessionHeader: some View {
        HStack {
            // Close Button
            Button(action: { showExitConfirm = true }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.secondary)
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            
            Spacer()
            
            // Quiz Type Badge
            HStack(spacing: 6) {
                Image(systemName: viewModel.headerIcon)
                    .font(.caption)
                Text(viewModel.headerTitle)
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            
            Spacer()
            
            // Progress Counter
            Text("\(viewModel.currentQuestionNumber) / \(viewModel.totalQuestions)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }
    
    // MARK: - Progress Bar
    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 6)
                
                // Progress
                RoundedRectangle(cornerRadius: 4)
                    .fill(progressColor)
                    .frame(width: geo.size.width * viewModel.progress, height: 6)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.progress)
            }
        }
        .frame(height: 6)
    }
    
    private var progressColor: Color {
        switch viewModel.currentQuizType {
        case .cloze: return .blue
        case .dualColumn: return .purple
        case .none: return .gray
        }
    }
    
    // MARK: - Main Content
    @ViewBuilder
    private var mainContent: some View {
        switch viewModel.sessionState {
        case .loading:
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Spacer()
            
        case .ready:
            emptyStateView
            
        case .inProgress:
            quizContent
            
        case .completed:
            completedView
        }
    }
    
    // MARK: - Quiz Content (Switch by Type)
    @ViewBuilder
    private var quizContent: some View {
        if let item = viewModel.currentItem {
            ZStack {
                switch item {
                case .cloze(let word):
                    ClozeQuizCard(
                        word: word,
                        onComplete: { outcome in
                            viewModel.handleClozeResult(word: word, outcome: outcome)
                            advanceToNext()
                        }
                    )
                    .id("cloze-\(word.id)")
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                    
                case .dualColumn(let quiz):
                    DualColumnQuizView(
                        quiz: quiz,
                        onComplete: { correct in
                            viewModel.handleDualColumnResult(quiz: quiz, correct: correct)
                            advanceToNext()
                        }
                    )
                    .id("dual-\(quiz.id)")
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .scale(scale: 1.05).combined(with: .opacity)
                    ))
                }
            }
            .animation(.easeInOut(duration: 0.35), value: viewModel.currentIndex)
        }
    }
    
    private func advanceToNext() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation {
                viewModel.goToNext()
                animationTrigger += 1
            }
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("학습할 내용이 없습니다")
                .font(.title3)
                .fontWeight(.medium)
            
            Button("돌아가기") { dismiss() }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.blue)
                .cornerRadius(12)
            
            Spacer()
        }
    }
    
    // MARK: - Completed View
    private var completedView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            Text("학습 완료! 🎉")
                .font(.title)
                .fontWeight(.bold)
            
            // Stats
            HStack(spacing: 40) {
                statItem(value: "\(viewModel.correctCount)", label: "정답", color: .green)
                statItem(value: "\(viewModel.wrongCount)", label: "오답", color: .red)
                statItem(value: "\(Int(viewModel.accuracy * 100))%", label: "정확도", color: .blue)
            }
            
            Button(action: { dismiss() }) {
                Text("완료")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue)
                    .cornerRadius(14)
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
        .padding()
    }
    
    private func statItem(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Cloze Quiz Card (Simplified)
struct ClozeQuizCard: View {
    let word: Word
    let onComplete: (ReviewOutcome) -> Void
    
    @State private var userInput: String = ""
    @State private var isSubmitted: Bool = false
    @State private var isCorrect: Bool = false
    @State private var hintLevel: Int = 0
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Korean Meaning
            Text(word.korean)
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            // Sentence with Blank
            Text(word.exampleSentence.replacingOccurrences(of: word.arabic, with: "______"))
                .font(.system(size: 24, weight: .medium, design: .serif))
                .multilineTextAlignment(.center)
                .environment(\.layoutDirection, .rightToLeft)
                .padding(.horizontal)
            
            // Input Field
            HStack {
                TextField("اكتب هنا", text: $userInput)
                    .font(.system(size: 28, weight: .medium, design: .serif))
                    .multilineTextAlignment(.center)
                    .environment(\.layoutDirection, .rightToLeft)
                    .focused($isFocused)
                    .onSubmit { submitAnswer() }
                    .disabled(isSubmitted)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(inputBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(inputBorderColor, lineWidth: 2)
                    )
            )
            .padding(.horizontal, 24)
            
            // Hint Button
            if !isSubmitted {
                Button(action: requestHint) {
                    Text(hintButtonText)
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
            
            Spacer()
            
            // Submit Button
            if !isSubmitted {
                Button(action: submitAnswer) {
                    Text("확인")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(userInput.isEmpty ? Color.gray : Color.blue)
                        .cornerRadius(14)
                }
                .disabled(userInput.isEmpty)
                .padding(.horizontal, 24)
            } else {
                // Show correct answer
                VStack(spacing: 8) {
                    Text(isCorrect ? "정답! 🎉" : "오답")
                        .font(.headline)
                        .foregroundColor(isCorrect ? .green : .red)
                    
                    if !isCorrect {
                        Text("정답: \(word.arabic)")
                            .font(.title3)
                            .fontWeight(.medium)
                    }
                }
                .padding()
                .onAppear {
                    let outcome: ReviewOutcome = hintLevel == 0 ? .clean : (hintLevel == 1 ? .hint : .reveal)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        onComplete(outcome)
                    }
                }
            }
        }
        .padding(.bottom, 32)
        .onAppear { isFocused = true }
    }
    
    private var hintButtonText: String {
        switch hintLevel {
        case 0: return "힌트 보기"
        case 1: return "정답 보기"
        default: return ""
        }
    }
    
    private var inputBackground: Color {
        if isSubmitted {
            return isCorrect ? Color.green.opacity(0.1) : Color.red.opacity(0.1)
        }
        return Color.gray.opacity(0.1)
    }
    
    private var inputBorderColor: Color {
        if isSubmitted {
            return isCorrect ? .green : .red
        }
        return .gray.opacity(0.3)
    }
    
    private func requestHint() {
        hintLevel += 1
        if hintLevel == 1 {
            // First letter hint
            if let first = word.arabicClean.first {
                userInput = String(first)
            }
        } else if hintLevel >= 2 {
            // Full answer
            userInput = word.arabicClean
        }
    }
    
    private func submitAnswer() {
        let normalized = userInput.filter { !$0.isWhitespace }
        let correct = normalized == word.arabicClean
        
        withAnimation {
            isSubmitted = true
            isCorrect = correct
        }
    }
}

// MARK: - Preview
#Preview {
    UnifiedStudySessionView(quizState: .bridge)
}
