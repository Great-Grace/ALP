// StrictTypingQuizView.swift
// Clean MVVM View - Only UI, no business logic

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
                }
            }
            .background(groupedBackground)
            .navigationTitle("레벨 \(level.levelID) 테스트")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("종료") { dismiss() }
                }
                
                if viewModel.quizState != .completed {
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
        }
    }
    
    // MARK: - Quiz Content (Pure UI)
    
    private func quizContent(word: Word) -> some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Korean Meaning
            VStack(spacing: 12) {
                Text("다음 뜻을 아랍어로 쓰세요")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Text(word.korean)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                if let root = word.root, !root.isEmpty {
                    Text("어근: \(root)")
                        .font(.caption)
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
                    .disabled(viewModel.quizState != .active)
                
                // Feedback
                if case .showingFeedback(let isCorrect) = viewModel.quizState {
                    Text(viewModel.feedbackMessage)
                        .font(.caption)
                        .foregroundStyle(isCorrect ? .green : .red)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal)
            
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
            .accessibilityLabel("답안 확인")
            .accessibilityHint("입력한 아랍어가 정답인지 확인합니다")
            .padding()
        }
    }
    
    // MARK: - Result View (Pure UI)
    
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
                        viewModel.isPassed ? Color.green : Color.orange,
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
            
            // Result Message
            VStack(spacing: 8) {
                if viewModel.isPassed {
                    Label("통과!", systemImage: "checkmark.seal.fill")
                        .font(.title)
                        .foregroundStyle(.green)
                    
                    Text("다음 레벨이 해금되었습니다!")
                        .foregroundStyle(.secondary)
                } else {
                    Label("아쉬워요", systemImage: "xmark.circle.fill")
                        .font(.title)
                        .foregroundStyle(.orange)
                    
                    Text("80% 이상 맞춰야 통과입니다.\n다시 학습하고 도전해보세요!")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Action Buttons
            VStack(spacing: 12) {
                Button(action: { dismiss() }) {
                    Text(viewModel.isPassed ? "완료" : "돌아가기")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(viewModel.isPassed ? Color.green : Color.blue)
                        .cornerRadius(12)
                }
                
                if !viewModel.isPassed {
                    Button(action: { viewModel.retry() }) {
                        Text("다시 도전")
                            .font(.headline)
                            .foregroundStyle(.blue)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                    }
                }
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
