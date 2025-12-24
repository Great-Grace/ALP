// StudySessionViewModel - 몰입형 학습 세션 로직
// Non-destructive Input & Reflection Mode

import Foundation
import SwiftData
import Observation

// MARK: - Session State
enum SessionState {
    case loading
    case ready
    case inProgress
    case reflection    // 성찰 모드 (정답 후)
    case completed
}

// MARK: - Hint Level
enum HintLevel: Int {
    case none = 0
    case firstLetter = 1
    case fullAnswer = 2
}

@Observable
class StudySessionViewModel {
    // MARK: - Session State
    var sessionState: SessionState = .loading
    
    // MARK: - Queue
    private(set) var queue: [Word] = []
    private(set) var currentIndex: Int = 0
    
    // MARK: - Quiz Mode
    var currentMode: QuizMode = .general
    
    // MARK: - Current Question
    var currentWord: Word? {
        guard currentIndex < queue.count else { return nil }
        return queue[currentIndex]
    }
    
    /// 정답 (모음 제거된 순수 철자 - 모드 관계없이 항상 clean version 사용)
    var canonicalAnswer: String {
        guard let word = currentWord else { return "" }
        return word.arabicClean // 스키마 최적화로 런타임 연산 제거
    }
    
    /// 화면 표시용 아랍어 단어 (모드에 따라 다름)
    var displayArabic: String {
        guard let word = currentWord else { return "" }
        switch currentMode {
        case .general: return word.arabic
        case .expert: return word.arabicClean
        }
    }
    
    /// 화면 표시용 예문 (모드에 따라 다름)
    var displaySentence: String {
        guard let word = currentWord else { return "" }
        switch currentMode {
        case .general: return word.exampleSentence
        case .expert: return word.sentenceClean
        }
    }
    
    /// 정답 길이
    var answerLength: Int {
        canonicalAnswer.count
    }
    
    // MARK: - User Input (Non-destructive)
    var userInput: String = "" {
        didSet {
            // 입력 변경 시 오류 상태만 리셋 (입력값은 유지)
            if userInput != oldValue {
                isWrong = false
                shakeOffset = 0
            }
            
            // 자동 채점: 길이가 같아지면 검증 (지우지 않음)
            let normalizedInput = normalizeArabic(userInput)
            if !userInput.isEmpty && normalizedInput.count == answerLength {
                autoValidate()
            }
        }
    }
    
    // MARK: - Answer State
    var isAnswered: Bool = false
    var isCorrect: Bool = false
    var isWrong: Bool = false
    var usedHint: Bool = false
    var hintLevel: HintLevel = .none
    var shakeOffset: CGFloat = 0
    
    // MARK: - Question Completion Tracking (for Review Mode)
    private(set) var completedIndices: Set<Int> = []
    
    var isCurrentQuestionCompleted: Bool {
        completedIndices.contains(currentIndex)
    }
    
    // MARK: - Progress
    var progress: Double {
        guard !queue.isEmpty else { return 0 }
        return Double(completedCount) / Double(totalQuestions)
    }
    
    var currentQuestionNumber: Int {
        completedCount + 1
    }
    
    var totalQuestions: Int {
        initialQueueSize
    }
    
    private var initialQueueSize: Int = 0
    private var completedCount: Int = 0
    
    // MARK: - Results
    private(set) var correctCount: Int = 0
    private(set) var wrongCount: Int = 0
    private(set) var wrongWords: [Word] = []
    
    var accuracy: Double {
        let total = correctCount + wrongCount
        guard total > 0 else { return 0 }
        return Double(correctCount) / Double(total) * 100
    }
    
    // MARK: - Settings
    var dailyGoal: Int = 20
    
    private var modelContext: ModelContext?
    private var allWords: [Word] = []
    
    // MARK: - Initialization
    func setup(context: ModelContext) {
        self.modelContext = context
    }
    
    // MARK: - Load Session
    func startSession(mode: QuizMode = .general) {
        guard let context = modelContext else { return }
        self.currentMode = mode
        sessionState = .loading
        
        let descriptor = FetchDescriptor<Word>()
        allWords = (try? context.fetch(descriptor)) ?? []
        
        let targetCount = min(dailyGoal, allWords.count)
        
        guard targetCount > 0 else {
            sessionState = .ready
            return
        }
        
        queue = Array(allWords.shuffled().prefix(targetCount))
        initialQueueSize = queue.count
        currentIndex = 0
        completedCount = 0
        correctCount = 0
        wrongCount = 0
        wrongWords = []
        completedIndices = []  // Reset completion tracking
        
        prepareCurrentQuestion()
        sessionState = .inProgress
    }
    
    // MARK: - Prepare Question
    private func prepareCurrentQuestion() {
        userInput = ""
        isAnswered = false
        isCorrect = false
        isWrong = false
        usedHint = false
        hintLevel = .none
        shakeOffset = 0
    }
    
    // MARK: - Auto Validation (Non-destructive)
    private func autoValidate() {
        guard currentWord != nil, !isAnswered else { return }
        
        let normalizedInput = normalizeArabic(userInput)
        let normalizedAnswer = canonicalAnswer
        
        if normalizedInput == normalizedAnswer {
            // 정답 → 성찰 모드로 전환
            handleCorrectAnswer()
        } else {
            // 오답 → 흔들기만 (입력 유지)
            handleWrongInput()
        }
    }
    
    private func handleCorrectAnswer() {
        isCorrect = true
        isAnswered = true
        completedIndices.insert(currentIndex)  // Mark as completed
        
        if !usedHint {
            correctCount += 1
        } else {
            wrongCount += 1
            if let word = currentWord {
                wrongWords.append(word)
            }
        }
        
        saveQuizHistory()
        completedCount += 1
        
        // 성찰 모드로 전환 (즉시 다음으로 넘어가지 않음)
        sessionState = .reflection
    }
    
    private func handleWrongInput() {
        isWrong = true
        
        // Shake 애니메이션만 (입력 유지 - Non-destructive)
        shakeOffset = 10
        
        // 오답 기록 (처음 틀렸을 때만)
        if let word = currentWord, !wrongWords.contains(where: { $0.id == word.id }) {
            wrongCount += 1
            wrongWords.append(word)
            queue.append(word) // Re-queue
        }
        
        // Shake 후 상태 리셋 (입력은 유지)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.shakeOffset = 0
            // isWrong은 사용자가 입력을 수정할 때까지 유지
        }
    }
    
    // MARK: - Hint System
    func requestHint() {
        guard !isAnswered else { return }
        
        usedHint = true
        
        switch hintLevel {
        case .none:
            hintLevel = .firstLetter
        case .firstLetter:
            hintLevel = .fullAnswer
        case .fullAnswer:
            break
        }
    }
    
    var hintText: String? {
        guard let word = currentWord else { return nil }
        
        switch hintLevel {
        case .none:
            return nil
        case .firstLetter:
            return String(canonicalAnswer.prefix(1)) // Hint also uses clean answer check logic mostly, but display might vary. Let's use canonical logic.
        case .fullAnswer:
            return canonicalAnswer
        }
    }
    
    // MARK: - Navigation (Reflection Mode)
    
    /// 다음 문제로 이동
    func goToNext() {
        currentIndex += 1
        
        if currentIndex >= queue.count {
            sessionState = .completed
        } else {
            navigateToQuestion(at: currentIndex)
        }
    }
    
    /// 이전 문제로 이동 (리뷰용)
    func goToPrevious() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
        navigateToQuestion(at: currentIndex)
    }
    
    /// 특정 인덱스로 이동 (Review Mode 지원)
    func navigateToQuestion(at index: Int) {
        guard index >= 0 && index < queue.count else { return }
        currentIndex = index
        
        if completedIndices.contains(index) {
            // Review Mode: 완료된 문제는 읽기 전용
            if let word = currentWord {
                userInput = word.arabic
                isAnswered = true
                isCorrect = true
                sessionState = .reflection
            }
        } else {
            // Quiz Mode: 입력 가능
            prepareCurrentQuestion()
            sessionState = .inProgress
        }
    }
    
    var canGoToPrevious: Bool {
        currentIndex > 0
    }
    
    var canGoToNext: Bool {
        true // 항상 다음으로 이동 가능
    }
    
    func skipQuestion() {
        if let word = currentWord {
            if !wrongWords.contains(where: { $0.id == word.id }) {
                wrongCount += 1
                wrongWords.append(word)
                queue.append(word)
            }
        }
        completedCount += 1
        goToNext()
    }
    
    func resetSession() {
        queue = []
        currentIndex = 0
        initialQueueSize = 0
        completedCount = 0
        correctCount = 0
        wrongCount = 0
        wrongWords = []
        completedIndices = []
        sessionState = .loading
    }
    
    // MARK: - Arabic Normalization
    func normalizeArabic(_ text: String) -> String {
        return text.withoutDiacritics.trimmingCharacters(in: .whitespaces)
    }
    
    // MARK: - Quiz History
    private func saveQuizHistory() {
        guard let context = modelContext, let word = currentWord else { return }
        
        let history = QuizHistory(
            quizType: "typing",
            quizMode: currentMode.rawValue,
            isCorrect: isCorrect && !usedHint,
            userAnswer: userInput,
            word: word
        )
        context.insert(history)
        try? context.save()
    }
}
