// StrictTypingQuizViewModel.swift
// Clean MVVM ViewModel for Strict Typing Quiz

import SwiftUI
import SwiftData

// MARK: - Typing Quiz State

enum TypingQuizState: Equatable {
    case loading
    case active
    case showingFeedback(isCorrect: Bool)
    case completed
}

// MARK: - ViewModel

@MainActor
@Observable
class StrictTypingQuizViewModel {
    
    // MARK: - Dependencies
    
    private var modelContext: ModelContext?
    private(set) var level: StudyLevel?
    
    // MARK: - State
    
    private(set) var words: [Word] = []
    private(set) var currentIndex: Int = 0
    private(set) var score: Int = 0
    private(set) var quizState: TypingQuizState = .loading
    private(set) var feedbackMessage: String = ""
    
    var userInput: String = ""
    
    // MARK: - Computed Properties
    
    var currentWord: Word? {
        guard currentIndex < words.count else { return nil }
        return words[currentIndex]
    }
    
    var progress: Double {
        guard !words.isEmpty else { return 0 }
        return Double(currentIndex) / Double(words.count)
    }
    
    var scorePercentage: Double {
        guard !words.isEmpty else { return 0 }
        return Double(score) / Double(words.count)
    }
    
    var isPassed: Bool {
        scorePercentage >= 0.8
    }
    
    var questionCount: String {
        "\(currentIndex + 1)/\(words.count)"
    }
    
    // MARK: - Setup
    
    func setup(level: StudyLevel, context: ModelContext) {
        self.level = level
        self.modelContext = context
        loadWords()
    }
    
    // MARK: - Actions
    
    func loadWords() {
        guard let level = level, let context = modelContext else { return }
        
        quizState = .loading
        
        let levelID = level.levelID
        var descriptor = FetchDescriptor<Word>(
            predicate: #Predicate { $0.levelID == levelID }
        )
        
        // Performance: Limit fetch to 100 words (Level 5 has 3000+)
        descriptor.fetchLimit = 100
        
        if let fetchedWords = try? context.fetch(descriptor) {
            // Shuffle and take 10 for quiz
            words = Array(fetchedWords.shuffled().prefix(10))
            quizState = words.isEmpty ? .completed : .active
        } else {
            words = []
            quizState = .completed
        }
    }
    
    func checkAnswer() {
        guard let word = currentWord else { return }
        
        // ✅ All grading logic is HERE in ViewModel
        let isCorrect = ArabicUtils.isStrictMatch(userInput, word.arabic)
        
        if isCorrect {
            score += 1
            feedbackMessage = "정답! ✓"
        } else {
            let correctAnswer = ArabicUtils.normalize(word.arabic)
            feedbackMessage = "오답. 정답: \(correctAnswer)"
        }
        
        quizState = .showingFeedback(isCorrect: isCorrect)
        
        // Auto-advance after delay
        Task {
            try? await Task.sleep(for: .seconds(1))
            advanceToNext()
        }
    }
    
    func advanceToNext() {
        userInput = ""
        
        if currentIndex < words.count - 1 {
            currentIndex += 1
            quizState = .active
        } else {
            finalizeQuiz()
        }
    }
    
    func retry() {
        currentIndex = 0
        score = 0
        userInput = ""
        feedbackMessage = ""
        loadWords()
    }
    
    // MARK: - Private
    
    private func finalizeQuiz() {
        quizState = .completed
        
        // Update level score in database
        if let level = level, let context = modelContext {
            level.updateScore(scorePercentage, context: context)
        }
    }
}
