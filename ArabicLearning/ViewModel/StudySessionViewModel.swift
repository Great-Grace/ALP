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
            // 아랍어만 입력 허용
            let filtered = userInput.arabicOnly
            if filtered != userInput {
                userInput = filtered
                return
            }
            
            // 입력 변경 시 오류 상태만 리셋 (입력값은 유지)
            if userInput != oldValue {
                isWrong = false
                shakeOffset = 0
            }
            
            // 자동 채점: 공백 제거 후 비교
            let normalizedInput = userInput.normalizedForComparison
            let normalizedAnswer = canonicalAnswer.withoutSpaces
            if !userInput.isEmpty && normalizedInput.count == normalizedAnswer.count {
                autoValidate()
            }
        }
    }
    
    // MARK: - Answer State
    var isAnswered: Bool = false
    var isCorrect: Bool = false
    var isWrong: Bool = false
    var usedHint: Bool = false
    var hasRevealedAnswer: Bool = false  // 3-Tier: 정답 보기 사용 여부
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
    var dailyGoal: Int = 30
    
    // MARK: - Mastery Tracking (Clean Solve Only)
    private(set) var masteredCount: Int = 0
    
    private var modelContext: ModelContext?
    private var allWords: [Word] = []
    
    // MARK: - Initialization
    func setup(context: ModelContext) {
        self.modelContext = context
    }
    
    // MARK: - Load Session (Spiral Curriculum + SRS)
    func startSession(mode: QuizMode = .general, selectedChapterIds: Set<UUID>? = nil, limit: Int = 20) {
        guard let context = modelContext else { return }
        self.currentMode = mode
        sessionState = .loading
        
        // Store limit for progress tracking
        self.dailyGoal = limit
        
        // 1. Load all words
        let descriptor = FetchDescriptor<Word>()
        allWords = (try? context.fetch(descriptor)) ?? []
        
        // 2. Apply chapter filter
        var filteredWords = allWords
        if let chapterIds = selectedChapterIds, !chapterIds.isEmpty {
            filteredWords = allWords.filter { word in
                guard let chapterId = word.chapter?.id else { return false }
                return chapterIds.contains(chapterId)
            }
        }
        
        // 3. Get or create UserProgress
        let progressDescriptor = FetchDescriptor<UserProgress>()
        var userProgress: UserProgress
        if let existing = try? context.fetch(progressDescriptor).first {
            userProgress = existing
        } else {
            userProgress = UserProgress()
            context.insert(userProgress)
        }
        
        // 4. Get current quiz state from spiral curriculum
        let currentQuizState = QuizGenerator.shared.getCurrentState(progress: userProgress)
        
        // 5. Generate session based on state (using provided limit)
        var sessionQueue = QuizGenerator.shared.generateSession(
            state: currentQuizState,
            allWords: filteredWords,
            limit: limit
        )
        
        // 6. If state-based is empty, fallback to FSRS-based selection
        if sessionQueue.isEmpty {
            let today = Date()
            
            // Priority 1: Words due for review
            let reviewWords = filteredWords.filter { word in
                guard let reviewDate = word.nextReviewDate else { return false }
                return reviewDate <= today
            }.sorted { ($0.nextReviewDate ?? .distantFuture) < ($1.nextReviewDate ?? .distantFuture) }
            
            // Priority 2: New words
            let newWords = filteredWords.filter { $0.status == .new }
            
            // Priority 3: Learning words
            let learningWords = filteredWords.filter { $0.status == .learning && $0.nextReviewDate == nil }
            
            // 60% review, 40% new/learning
            let reviewCount = min(reviewWords.count, (limit * 6) / 10)
            let remainingSlots = limit - reviewCount
            
            sessionQueue.append(contentsOf: reviewWords.prefix(reviewCount))
            sessionQueue.append(contentsOf: (newWords + learningWords).shuffled().prefix(remainingSlots))
        }
        
        guard !sessionQueue.isEmpty else {
            sessionState = .ready
            return
        }
        
        queue = sessionQueue.shuffled()
        initialQueueSize = queue.count
        currentIndex = 0
        completedCount = 0
        masteredCount = 0
        correctCount = 0
        wrongCount = 0
        wrongWords = []
        completedIndices = []
        
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
        hasRevealedAnswer = false  // 3-Tier: 리셋
        hintLevel = .none
        shakeOffset = 0
    }
    
    // MARK: - Auto Validation (Non-destructive)
    private func autoValidate() {
        guard currentWord != nil, !isAnswered else { return }
        
        // 공백 제거 후 비교
        let normalizedInput = userInput.normalizedForComparison
        let normalizedAnswer = canonicalAnswer.withoutSpaces
        
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
        completedIndices.insert(currentIndex)
        
        if !usedHint {
            // Clean Solve: 마스터리 카운트 증가
            correctCount += 1
            masteredCount += 1
            updateWordFSRS(correct: true)
        } else {
            // Hint 사용: 큐 뒤로 재배치
            wrongCount += 1
            if let word = currentWord {
                wrongWords.append(word)
            }
            reQueueCurrentWord()
            updateWordFSRS(correct: false)
        }
        
        saveQuizHistory()
        completedCount += 1
        
        // 세션 완료 체크
        if masteredCount >= dailyGoal {
            sessionState = .completed
        } else {
            sessionState = .reflection
        }
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
    
    // MARK: - Hint System (3-Tier)
    func requestHint() {
        guard !isAnswered else { return }
        
        usedHint = true
        
        switch hintLevel {
        case .none:
            hintLevel = .firstLetter
        case .firstLetter:
            hintLevel = .fullAnswer
            hasRevealedAnswer = true  // 정답 보기 = Reveal
        case .fullAnswer:
            break
        }
    }
    
    /// 힌트 요청 + 입력 클리어 ('1' 키용)
    func requestHintWithClear() {
        userInput = ""  // 입력 강제 클리어
        requestHint()
    }
    
    // MARK: - Re-queue (Perfect Mastery Loop)
    private func reQueueCurrentWord() {
        guard let word = currentWord else { return }
        // 현재 인덱스+3 ~ 끝 사이 랜덤 위치에 삽입
        let minIndex = min(currentIndex + 3, queue.count)
        let insertIndex = Int.random(in: minIndex...queue.count)
        queue.insert(word, at: insertIndex)
    }
    
    // MARK: - FSRS Integration (3-Tier System)
    private func updateWordFSRS(correct: Bool) {
        guard let word = currentWord else { return }
        
        // Priority: Reveal > Hint > Clean
        let outcome: ReviewOutcome
        if hasRevealedAnswer {
            outcome = .reveal  // 정답 보고 입력
        } else if usedHint {
            outcome = .hint    // 힌트 사용 후 정답
        } else if correct {
            outcome = .clean   // 순수 기억 인출
        } else {
            outcome = .reveal  // 잘못 입력 = 기억 실패
        }
        
        word.applyReviewResult(outcome: outcome)
    }
    
    /// 힌트 버튼 텍스트 (상태에 따라 변경)
    var hintButtonText: String {
        switch hintLevel {
        case .none:
            return "힌트"
        case .firstLetter:
            return "정답"
        case .fullAnswer:
            return "정답"
        }
    }
    
    /// 첫 글자 힌트
    var firstLetterHint: String? {
        guard hintLevel == .firstLetter else { return nil }
        return String(canonicalAnswer.prefix(1))
    }
    
    /// Ghost text 표시 여부
    var showGhostText: Bool {
        return hintLevel == .fullAnswer && userInput.isEmpty && !isAnswered
    }
    
    var hintText: String? {
        guard let word = currentWord else { return nil }
        
        switch hintLevel {
        case .none:
            return nil
        case .firstLetter:
            // 모음 포함된 첫 글자 (학습에 도움됨)
            return String(word.arabic.prefix(1))
        case .fullAnswer:
            // 모음 포함된 전체 정답 (학습용)
            return word.arabic
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
