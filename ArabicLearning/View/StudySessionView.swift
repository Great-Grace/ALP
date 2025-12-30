// StudySessionView - 몰입형 학습 화면
// Premium Design & Immersive Experience

import SwiftUI
import SwiftData

struct StudySessionView: View {
    var mode: QuizMode
    var selectedChapterIds: Set<UUID> // 챕터 필터링용
    var studyLimit: Int = 20  // 학습 개수
    
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
                        onDismiss: { dismiss() },
                        onContinue: { additionalCount in
                            // Restart session with additional words
                            viewModel.startSession(mode: mode, selectedChapterIds: selectedChapterIds, limit: additionalCount)
                        }
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
            viewModel.startSession(mode: mode, selectedChapterIds: selectedChapterIds, limit: studyLimit)
            forceFocus()
        }
        .onChange(of: viewModel.currentIndex) { _, _ in
            forceFocus()
        }
        .onChange(of: viewModel.sessionState) { _, _ in
            forceFocus()
        }
        #if os(macOS)
        .navigationBarBackButtonHidden(true)
        .onKeyPress(.leftArrow) {
            if viewModel.canGoToPrevious {
                viewModel.goToPrevious()
                forceFocus()
            }
            return .handled
        }
        .onKeyPress(.rightArrow) {
            if viewModel.sessionState == .reflection {
                viewModel.goToNext()
                forceFocus()
            }
            return .handled
        }
        .onKeyPress(.return) {
            if viewModel.sessionState == .reflection {
                viewModel.goToNext()
                forceFocus()
            }
            return .handled
        }
        .onKeyPress(.space) {
            if viewModel.sessionState == .reflection {
                viewModel.goToNext()
                forceFocus()
            }
            return .handled
        }
        // '1' 키: 힌트/정답 보기 + 입력 클리어
        .onKeyPress(KeyEquivalent("1")) {
            if viewModel.sessionState == .inProgress {
                viewModel.requestHintWithClear()
                forceFocus()
            }
            return .handled
        }
        #endif
        .alert("학습을 중단하시겠습니까?", isPresented: $showExitConfirm) {
            Button("계속하기", role: .cancel) {}
            Button("종료", role: .destructive) { dismiss() }
        } message: {
            Text("진행 상황은 자동 저장됩니다.")
        }
    }
    
    // MARK: - Focus Helper
    private func forceFocus() {
        isInputFocused = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isInputFocused = true
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
                #if os(macOS)
                Color(nsColor: .windowBackgroundColor)
                #else
                AnimatedGradientBackground(colors: [
                    Color.backgroundPrimary,
                    Color(hex: "F0F3F9")
                ])
                #endif
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
            
            // 빈 공간 (스킵 버튼 제거)
            Color.clear
                .frame(width: 44, height: 44)
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
    
    // MARK: - Question Content (2단 구성)
    private var questionContent: some View {
        ZStack {
            if let word = viewModel.currentWord {
                VStack(spacing: Design.spacingXL) {
                    Spacer()
                    
                    // TOP: 아랍어 문장 (블러 처리된 정답)
                    if viewModel.sessionState == .reflection {
                        Text(viewModel.displaySentence)
                            .appFont(AppFont.arabicTitle())
                            .foregroundStyle(viewModel.isCorrect ? Color.success : Color.textPrimary)
                            .multilineTextAlignment(.center)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        arabicSentenceWithBlank(word: word)
                    }
                    
                    // BOTTOM: 한국어 해석 (괄호 제거 + 정답 강조)
                    processedKoreanTranslation(word.sentenceKorean)
                        .multilineTextAlignment(.center)
                    
                    Spacer()
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
        VStack(spacing: Design.spacingM) {
            if viewModel.sessionState == .reflection {
                // Next Button (정답 후)
                VStack(spacing: 8) {
                    Text("✓ 정답!")
                        .font(.headline)
                        .foregroundStyle(Color.success)
                    
                    Text("Enter, Space, 또는 → 키로 다음 문제")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Button("다음 문제") {
                        viewModel.goToNext()
                        forceFocus()
                    }
                    .buttonStyle(PremiumButtonStyle())
                }
                .padding(.horizontal, Design.spacingL)
            } else {
                // Input Area with Hint ABOVE
                VStack(spacing: 12) {
                    // Hint Display (입력창 위에 명확하게 표시)
                    if viewModel.hintLevel != .none && viewModel.userInput.isEmpty {
                        HStack {
                            Text("힌트:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Text(viewModel.hintText ?? "")
                                .font(AppFont.arabicTitle())
                                .foregroundStyle(Color.orange)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.orange.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // Input Row
                    HStack(spacing: Design.spacingM) {
                        // Hint Button
                        Button(action: { viewModel.requestHint() }) {
                            VStack(spacing: 4) {
                                Image(systemName: "lightbulb.fill")
                                    .font(.title2)
                                Text(viewModel.hintButtonText)
                                    .font(.caption)
                            }
                            .foregroundStyle(viewModel.hintLevel != .none ? Color.warning : Color.secondary)
                            .padding(12)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: Design.shadowSofter.color, radius: 10)
                        }
                        .buttonStyle(.plain)
                        
                        // Input Field (심플하게)
                        TextField("아랍어 입력", text: $viewModel.userInput)
                            .font(AppFont.arabicTitle())
                            .multilineTextAlignment(.center)
                            .environment(\.layoutDirection, .rightToLeft)
                            .focused($isInputFocused)
                            .textFieldStyle(.plain)
                            .padding()
                            .frame(height: 60)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: Design.radiusMedium))
                            .shadow(color: Design.shadowSofter.color, radius: 10)
                            .overlay(
                                RoundedRectangle(cornerRadius: Design.radiusMedium)
                                    .stroke(viewModel.isWrong ? Color.error : Color.clear, lineWidth: 2)
                            )
                            #if os(macOS)
                            .onKeyPress(KeyEquivalent("1")) {
                                viewModel.requestHintWithClear()
                                return .handled
                            }
                            .onKeyPress(.return) {
                                if viewModel.sessionState == .reflection {
                                    viewModel.goToNext()
                                }
                                return .handled
                            }
                            .onKeyPress(.space) {
                                if viewModel.sessionState == .reflection {
                                    viewModel.goToNext()
                                    return .handled
                                }
                                return .ignored  // Allow space in text input
                            }
                            #endif
                    }
                }
                .padding(.horizontal, Design.spacingL)
            }
        }
        .padding(.bottom, Design.spacingL)
    }
    
    // MARK: - Helpers
    
    /// 한국어 해석: 괄호 제거 + 다중 타겟 단어 Accent 강조 (system .primary 기반)
    private func processedKoreanTranslation(_ sentence: String) -> Text {
        let (targets, cleaned) = sentence.extractAllParenthesisContent()
        
        guard !targets.isEmpty else {
            return Text(sentence.withoutQuotes)
                .font(.title2)
                .foregroundStyle(.primary)
        }
        
        let attributed = cleaned.highlightedAttributedString(targets: targets, highlightColor: .accent)
        return Text(attributed)
            .font(.title2)
            .foregroundStyle(.primary)
    }
    
    private func highlightedKoreanTranslation(fullSentence: String, target: String) -> Text {
        var attributedString = AttributedString(fullSentence)
        
        if let range = attributedString.range(of: target) {
            attributedString[range].foregroundColor = .primary
            attributedString[range].font = AppFont.body().bold()
        }
        
        return Text(attributedString)
            .font(AppFont.body())
            .foregroundStyle(Color.textSecondary)
    }
    
    @ViewBuilder
    private func arabicSentenceWithBlank(word: Word) -> some View {
        // Split sentence by spaces and show each word, blurring the answer
        let words = viewModel.displaySentence.components(separatedBy: " ")
        let answerClean = viewModel.displayArabic.withoutDiacritics
        
        // Using FlowLayout-like wrapping with HStack
        HStack(spacing: 8) {
            ForEach(Array(words.enumerated()), id: \.offset) { index, wordText in
                let isAnswer = wordText.withoutDiacritics.contains(answerClean) ||
                               answerClean.contains(wordText.withoutDiacritics)
                
                Text(wordText)
                    .appFont(AppFont.arabicBody())
                    .foregroundStyle(Color.textPrimary)
                    .padding(.horizontal, isAnswer ? 12 : 0)
                    .padding(.vertical, isAnswer ? 6 : 0)
                    .background(
                        isAnswer ?
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.primary.opacity(0.15))
                        : nil
                    )
                    .blur(radius: isAnswer ? 8 : 0)
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .offset(x: viewModel.shakeOffset)
        .animation(.default, value: viewModel.shakeOffset)
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
