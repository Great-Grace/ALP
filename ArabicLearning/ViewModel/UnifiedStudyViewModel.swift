// UnifiedStudyViewModel.swift
// Unified Quiz Session ViewModel supporting both Cloze and Dual-Column

import Foundation
import SwiftData
import Observation

// MARK: - Unified Session State
enum UnifiedSessionState {
    case loading
    case ready
    case inProgress
    case completed
}

// MARK: - Current Quiz Info
enum CurrentQuizType: Equatable {
    case cloze
    case dualColumn
    case none
}

@Observable
class UnifiedStudyViewModel {
    // MARK: - Dependencies
    private var modelContext: ModelContext?
    
    // MARK: - Session State
    var sessionState: UnifiedSessionState = .loading
    
    // MARK: - Unified Queue
    private(set) var queue: [QuizItemWrapper] = []
    private(set) var currentIndex: Int = 0
    
    // MARK: - Current Item
    var currentItem: QuizItemWrapper? {
        guard currentIndex < queue.count else { return nil }
        return queue[currentIndex]
    }
    
    var currentQuizType: CurrentQuizType {
        guard let item = currentItem else { return .none }
        switch item {
        case .cloze: return .cloze
        case .dualColumn: return .dualColumn
        }
    }
    
    // MARK: - Cloze Specific (Word)
    var currentWord: Word? {
        guard case .cloze(let word) = currentItem else { return nil }
        return word
    }
    
    // MARK: - Dual-Column Specific
    var currentDualColumnQuiz: DualColumnQuizItem? {
        guard case .dualColumn(let quiz) = currentItem else { return nil }
        return quiz
    }
    
    // MARK: - Statistics
    var completedCount: Int = 0
    var correctCount: Int = 0
    var wrongCount: Int = 0
    var wrongItems: [QuizItemWrapper] = []
    var initialQueueSize: Int = 0
    
    var totalQuestions: Int { initialQueueSize }
    var currentQuestionNumber: Int { min(currentIndex + 1, totalQuestions) }
    var progress: Double {
        guard initialQueueSize > 0 else { return 0 }
        return Double(completedCount) / Double(initialQueueSize)
    }
    var accuracy: Double {
        guard completedCount > 0 else { return 0 }
        return Double(correctCount) / Double(completedCount)
    }
    
    // MARK: - VerbForm Lookup Cache
    private var verbFormCache: [String: VerbForm] = [:]
    
    // MARK: - Setup
    func setup(context: ModelContext) {
        self.modelContext = context
        loadVerbFormCache()
    }
    
    private func loadVerbFormCache() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<VerbForm>()
        if let verbForms = try? context.fetch(descriptor) {
            for verbForm in verbForms {
                // Cache by arabicWord for lookup
                verbFormCache[verbForm.arabicWord] = verbForm
            }
        }
    }
    
    // MARK: - Start Session
    @MainActor
    func startUnifiedSession(quizState: QuizState) {
        guard let context = modelContext else { return }
        sessionState = .loading
        
        // Generate unified session
        queue = QuizGenerator.shared.generateUnifiedSession(
            state: quizState,
            context: context,
            limit: 30
        )
        
        if queue.isEmpty {
            sessionState = .ready
            return
        }
        
        initialQueueSize = queue.count
        currentIndex = 0
        completedCount = 0
        correctCount = 0
        wrongCount = 0
        wrongItems = []
        
        sessionState = .inProgress
    }
    
    // MARK: - Start Legacy (Word-only)
    @MainActor
    func startLegacySession(words: [Word]) {
        sessionState = .loading
        
        queue = words.map { .cloze($0) }
        
        if queue.isEmpty {
            sessionState = .ready
            return
        }
        
        initialQueueSize = queue.count
        currentIndex = 0
        completedCount = 0
        correctCount = 0
        wrongCount = 0
        wrongItems = []
        
        sessionState = .inProgress
    }
    
    // MARK: - Handle Cloze Result
    func handleClozeResult(word: Word, outcome: ReviewOutcome) {
        // Apply FSRS to Word
        word.applyReviewResult(outcome: outcome)
        
        // Update stats
        completedCount += 1
        if outcome == .clean {
            correctCount += 1
        } else {
            wrongCount += 1
            wrongItems.append(.cloze(word))
        }
        
        // Save context
        try? modelContext?.save()
    }
    
    // MARK: - Handle Dual-Column Result ⭐
    func handleDualColumnResult(quiz: DualColumnQuizItem, correct: Bool) {
        // Find corresponding VerbForm
        if let verbForm = findVerbForm(for: quiz) {
            let outcome: ReviewOutcome = correct ? .clean : .reveal
            verbForm.applyReviewResult(outcome: outcome)
        }
        
        // Update stats
        completedCount += 1
        if correct {
            correctCount += 1
        } else {
            wrongCount += 1
            wrongItems.append(.dualColumn(quiz))
        }
        
        // Save context
        try? modelContext?.save()
    }
    
    // MARK: - Find VerbForm for Quiz
    private func findVerbForm(for quiz: DualColumnQuizItem) -> VerbForm? {
        // Try cache first
        let arabicWord = quiz.displayCard.mainText
        if let cached = verbFormCache[arabicWord] {
            return cached
        }
        
        // Fallback: query by root if available
        guard let context = modelContext else { return nil }
        
        // For synthesis type, mainText is the root
        if quiz.type == .constructiveSynthesis {
            let root = quiz.displayCard.mainText
            let descriptor = FetchDescriptor<VerbForm>(
                predicate: #Predicate { $0.root == root }
            )
            return try? context.fetch(descriptor).first
        }
        
        return nil
    }
    
    // MARK: - Navigation
    func goToNext() {
        guard currentIndex < queue.count - 1 else {
            sessionState = .completed
            return
        }
        currentIndex += 1
    }
    
    func goToPrevious() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
    }
    
    var canGoToNext: Bool { currentIndex < queue.count - 1 }
    var canGoToPrevious: Bool { currentIndex > 0 }
    
    // MARK: - Header Info
    var headerTitle: String {
        switch currentQuizType {
        case .cloze: return "단어 학습"
        case .dualColumn: return "구조 훈련"
        case .none: return "학습"
        }
    }
    
    var headerIcon: String {
        switch currentQuizType {
        case .cloze: return "text.book.closed"
        case .dualColumn: return "rectangle.split.2x1"
        case .none: return "book"
        }
    }
}
