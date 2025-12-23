// StudySessionView - 몰입형 학습 화면
// Premium Design & Immersive Experience

import SwiftUI
import SwiftData

struct StudySessionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var viewModel = StudySessionViewModel()
    @State private var showExitConfirm = false
    @FocusState private var isInputFocused: Bool
    
    // MARK: - Swipe Gesture State
    @State private var dragOffset: CGFloat = 0
    @GestureState private var isDragging = false
    
    var body: some View {
        ZStack {
            // Dynamic Background
            backgroundLayer
            
            VStack {
                // Header
                sessionHeader
                
                // Progress Bar
                if viewModel.sessionState != .completed {
                    ProgressBar(progress: viewModel.progress)
                        .padding(.horizontal, Design.spacingL)
                        .padding(.top, Design.spacingS)
                }
                
                Spacer()
                
                // Main Content
                switch viewModel.sessionState {
                case .loading:
                    ProgressView()
                        .scaleEffect(1.5)
                case .ready:
                    emptyStateView
                case .inProgress, .reflection:
                    questionContent
                case .completed:
                    ResultView(
                        correctCount: viewModel.correctCount,
                        wrongCount: viewModel.wrongCount,
                        wrongWords: viewModel.wrongWords,
                        accuracy: viewModel.accuracy,
                        onDismiss: { dismiss() }
                    )
                }
                
                Spacer()
                
                // Input or Navigation
                if viewModel.sessionState == .inProgress || viewModel.sessionState == .reflection {
                    bottomControlArea
                }
            }
        }
        .onAppear {
            viewModel.setup(context: modelContext)
            viewModel.startSession()
            isInputFocused = true
        }
        .alert("End Session?", isPresented: $showExitConfirm) {
            Button("Resume", role: .cancel) {}
            Button("End", role: .destructive) { dismiss() }
        } message: {
            Text("Progress will be saved.")
        }
    }
    
    // MARK: - Background Layer
    private var backgroundLayer: some View {
        Group {
            if viewModel.isCorrect {
                Color.success.opacity(0.1)
            } else if viewModel.isWrong {
                Color.error.opacity(0.1)
            } else {
                AnimatedGradientBackground(colors: [
                    Color.backgroundPrimary,
                    Color(hex: "F0F3F9")
                ])
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut, value: viewModel.isCorrect)
        .animation(.easeInOut, value: viewModel.isWrong)
    }
    
    // MARK: - Header
    private var sessionHeader: some View {
        HStack {
            Button(action: { showExitConfirm = true }) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.textSecondary)
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            
            Spacer()
            
            Text("\(viewModel.currentQuestionNumber) / \(viewModel.totalQuestions)")
                .appFont(AppFont.minicaps())
                .foregroundStyle(Color.textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
            
            Spacer()
            
            Button(action: { viewModel.skipQuestion() }) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.textSecondary)
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, Design.spacingL)
        .padding(.top, Design.spacingM)
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: Design.spacingL) {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 60))
                .foregroundStyle(Color.textTertiary)
            
            Text("No Words Available")
                .appFont(AppFont.title3())
                .foregroundStyle(Color.textPrimary)
            
            Button("Go Back") { dismiss() }
                .buttonStyle(PremiumButtonStyle(isFullWidth: false))
        }
    }
    
    // MARK: - Question Content
    private var questionContent: some View {
        ZStack {
            if let word = viewModel.currentWord {
                VStack(spacing: Design.spacingXL) {
                    // Korean Meaning
                    Text(word.korean)
                        .appFont(AppFont.title1())
                        .foregroundStyle(Color.textPrimary)
                        .multilineTextAlignment(.center)
                    
                    // Arabic Sentence
                    if viewModel.sessionState == .reflection {
                       // Complete Sentence
                        Text(word.exampleSentence)
                            .appFont(AppFont.arabicTitle())
                            .foregroundStyle(viewModel.isCorrect ? Color.success : Color.textPrimary)
                            .multilineTextAlignment(.center)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        // Sentence with Blank
                        arabicSentenceWithBlank(word: word)
                    }
                    
                    // Translation
                    Text(word.sentenceKorean)
                        .appFont(AppFont.body())
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, Design.spacingS)
                }
                .padding(Design.spacingL)
                .offset(x: dragOffset)
                .gesture(
                    DragGesture()
                        .updating($isDragging) { _, state, _ in state = true }
                        .onChanged { value in
                             // Handle logic...
                             if viewModel.sessionState == .reflection {
                                 dragOffset = value.translation.width
                             }
                        }
                        .onEnded { value in
                            if viewModel.sessionState == .reflection {
                                if value.translation.width < -100 {
                                    viewModel.goToNext()
                                }
                                dragOffset = 0
                            }
                        }
                )
            }
        }
    }
    
    // MARK: - Bottom Controls
    private var bottomControlArea: some View {
        VStack(spacing: Design.spacingL) {
            if viewModel.sessionState == .reflection {
                // Next Button
                Button("Next") {
                    withAnimation {
                        viewModel.goToNext()
                    }
                }
                .buttonStyle(PremiumButtonStyle())
                .padding(.horizontal, Design.spacingL)
            } else {
                // Input Area
                HStack(spacing: Design.spacingM) {
                    // Hint Button
                    Button(action: { viewModel.requestHint() }) {
                        Image(systemName: "lightbulb.fill")
                            .font(.title2)
                            .foregroundStyle(viewModel.hintLevel != .none ? Color.warning : Color.textTertiary)
                            .padding(16)
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(color: Design.shadowSofter.color, radius: 10)
                    }
                    
                    // Input Field
                    TextField("", text: $viewModel.userInput)
                        .font(AppFont.arabicTitle())
                        .multilineTextAlignment(.center)
                        .environment(\.layoutDirection, .rightToLeft)
                        .padding()
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: Design.radiusMedium))
                        .shadow(color: Design.shadowSofter.color, radius: 10)
                        .overlay(
                            RoundedRectangle(cornerRadius: Design.radiusMedium)
                                .stroke(viewModel.isWrong ? Color.error : Color.clear, lineWidth: 2)
                        )
                        .focused($isInputFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            // Logic handled by ViewModel auto-validation mostly
                        }
                }
                .padding(.horizontal, Design.spacingL)
                
                Text("Type consonants only")
                    .appFont(AppFont.minicaps())
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .padding(.bottom, Design.spacingL)
    }
    
    // MARK: - Helpers
    
    @ViewBuilder
    private func arabicSentenceWithBlank(word: Word) -> some View {
        // Simplified Blank Logic for new Design
         let parts = splitSentence(sentence: word.exampleSentence, answer: word.arabic)
         
         HStack(alignment: .bottom, spacing: 6) {
             if !parts.after.isEmpty {
                 Text(parts.after)
                     .appFont(AppFont.arabicBody())
             }
             
             // The Blank
             RoundedRectangle(cornerRadius: 8)
                 .fill(Color.black.opacity(0.05))
                 .frame(width: 100, height: 50)
                 .overlay(
                    Text(viewModel.userInput)
                        .appFont(AppFont.arabicBody())
                 )
                 .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.textTertiary, style: StrokeStyle(lineWidth: 2, dash: [5]))
                 )
             
             if !parts.before.isEmpty {
                 Text(parts.before)
                     .appFont(AppFont.arabicBody())
             }
         }
         .environment(\.layoutDirection, .rightToLeft)
         .offset(x: viewModel.shakeOffset)
         .animation(.default, value: viewModel.shakeOffset)
    }
    
    private func splitSentence(sentence: String, answer: String) -> (before: String, after: String, found: Bool) {
         // Reusing logic (simplified for brevity in this view, could be in VM)
         // ... (Keeping the original logic essentially)
         // For now, let's assume simple split or use the VM if I move it there.
         // Since I can't move it to VM easily without modifying VM greatly, I'll copy the logic but keep it cleaner.
         
         if let range = sentence.range(of: answer) {
             let before = String(sentence[..<range.lowerBound])
             let after = String(sentence[range.upperBound...])
             return (before, after, true)
         }
         return ("", "", false) // Fallback
    }
}

// MARK: - Progress Bar Component
struct ProgressBar: View {
    let progress: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.black.opacity(0.05))
                    .frame(height: 6)
                
                Capsule()
                    .fill(Design.primaryGradient)
                    .frame(width: geometry.size.width * progress, height: 6)
                    .animation(Design.springSmooth, value: progress)
            }
        }
        .frame(height: 6)
    }
}
