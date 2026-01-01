// StrictTypingQuizViewModel.swift
// Unified Study & Quiz ViewModel with Implicit FSRS Grading
// NO manual Easy/Hard buttons - behavior-based grading

import SwiftUI
import SwiftData

// MARK: - Typing Quiz State

enum TypingQuizState: Equatable {
    case loading
    case active
    case showingFeedback(isCorrect: Bool)
    case completed
    case levelUp  // New: Level unlocked celebration
}

// MARK: - Implicit FSRS Grade

/// Grading determined by USER BEHAVIOR, not manual selection
enum ImplicitGrade {
    case easy   // Correct on first try
    case good   // Correct after using hint
    case hard   // Correct after revealing answer
    case again  // Incorrect
    
    /// FSRS stability multiplier
    var stabilityFactor: Double {
        switch self {
        case .easy: return 2.5
        case .good: return 2.0
        case .hard: return 1.5
        case .again: return 0.5
        }
    }
    
    /// FSRS difficulty adjustment
    var difficultyDelta: Double {
        switch self {
        case .easy: return -0.2
        case .good: return 0.0
        case .hard: return 0.1
        case .again: return 0.3
        }
    }
}

// MARK: - ViewModel

@MainActor
@Observable
class StrictTypingQuizViewModel {
    
    // MARK: - Dependencies
    
    private var modelContext: ModelContext?
    private(set) var level: StudyLevel?
    
    // MARK: - Quiz State
    
    private(set) var words: [Word] = []
    private(set) var currentIndex: Int = 0
    private(set) var score: Int = 0
    private(set) var quizState: TypingQuizState = .loading
    private(set) var feedbackMessage: String = ""
    
    var userInput: String = ""
    
    // MARK: - Behavior Tracking (for Implicit FSRS)
    
    /// User used hint for current word (e.g., showed first letter)
    private(set) var usedHint: Bool = false
    
    /// User revealed the answer for current word
    private(set) var usedReveal: Bool = false
    
    /// Number of attempts on current word
    private(set) var attemptCount: Int = 0
    
    // MARK: - Session Stats
    
    private(set) var easyCount: Int = 0
    private(set) var goodCount: Int = 0
    private(set) var hardCount: Int = 0
    private(set) var againCount: Int = 0
    
    // MARK: - Level Up State
    
    var showLevelUpAlert: Bool = false
    var unlockedLevelName: String = ""
    
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
    
    var questionCount: String {
        "\(currentIndex + 1)/\(words.count)"
    }
    
    /// Hint: Shows first letter of the word
    var hintText: String? {
        guard let word = currentWord, !word.arabic.isEmpty else { return nil }
        let firstChar = word.arabic.prefix(1)
        return "\(firstChar)..."
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
        
        // Performance: Limit for large levels
        descriptor.fetchLimit = 100
        
        if let fetchedWords = try? context.fetch(descriptor) {
            // 20/10 Rule: Prioritize due reviews, then new words
            let dueForReview = fetchedWords.filter { $0.isDueForReview }
            let newWords = fetchedWords.filter { $0.status == .new }
            
            var sessionWords: [Word] = []
            sessionWords.append(contentsOf: dueForReview.prefix(20))
            sessionWords.append(contentsOf: newWords.prefix(max(0, 30 - sessionWords.count)))
            
            // Shuffle for variety, limit to 30
            words = Array(sessionWords.shuffled().prefix(30))
            quizState = words.isEmpty ? .completed : .active
        } else {
            words = []
            quizState = .completed
        }
    }
    
    /// User requests a hint (shows first letter)
    func requestHint() {
        usedHint = true
        feedbackMessage = hintText ?? ""
    }
    
    /// User reveals the answer
    func revealAnswer() {
        usedReveal = true
        if let word = currentWord {
            feedbackMessage = "정답: \(word.arabic)"
        }
    }
    
    /// Check user's answer and apply implicit FSRS grading
    func checkAnswer() {
        guard let word = currentWord else { return }
        
        attemptCount += 1
        let isCorrect = ArabicUtils.isStrictMatch(userInput, word.arabic)
        
        if isCorrect {
            // Determine implicit grade based on BEHAVIOR
            let grade = determineImplicitGrade()
            applyFSRS(to: word, grade: grade)
            
            score += 1
            feedbackMessage = gradeEmoji(grade) + " 정답!"
            
            // Track stats
            switch grade {
            case .easy: easyCount += 1
            case .good: goodCount += 1
            case .hard: hardCount += 1
            case .again: break // Won't happen on correct
            }
        } else {
            feedbackMessage = "다시 시도해보세요"
            
            // If 3 attempts failed, show answer and mark as Again
            if attemptCount >= 3 {
                applyFSRS(to: word, grade: .again)
                againCount += 1
                feedbackMessage = "정답: \(word.arabic)"
                
                // Force advance after showing answer
                quizState = .showingFeedback(isCorrect: false)
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    advanceToNext()
                }
                return
            }
            return // Don't advance - let user retry
        }
        
        quizState = .showingFeedback(isCorrect: isCorrect)
        
        // Auto-advance after delay
        Task {
            try? await Task.sleep(for: .seconds(1))
            advanceToNext()
        }
    }
    
    /// Determine grade based on user behavior (NO manual buttons!)
    private func determineImplicitGrade() -> ImplicitGrade {
        if usedReveal {
            return .hard  // Saw the answer first
        } else if usedHint {
            return .good  // Needed help
        } else if attemptCount == 1 {
            return .easy  // First try success!
        } else {
            return .good  // Multiple attempts but got it
        }
    }
    
    /// Apply FSRS algorithm to word
    private func applyFSRS(to word: Word, grade: ImplicitGrade) {
        // Update stability
        word.stability = max(0.1, word.stability * grade.stabilityFactor)
        
        // Update difficulty
        word.difficulty = max(1, min(10, word.difficulty + grade.difficultyDelta))
        
        // Update next review date
        let interval = word.stability * (grade == .again ? 0.5 : 1.0)
        word.nextReviewDate = Date().addingTimeInterval(interval * 24 * 60 * 60)
        
        // Update status based on stability
        if word.stability > 21 {
            word.statusRaw = LearningStatus.mastered.rawValue
        } else if word.stability > 1 {
            word.statusRaw = LearningStatus.learning.rawValue
        }
        
        // Update streak
        if grade != .again {
            word.streak += 1
        } else {
            word.streak = 0
        }
    }
    
    func advanceToNext() {
        // Reset behavior tracking for next word
        userInput = ""
        usedHint = false
        usedReveal = false
        attemptCount = 0
        feedbackMessage = ""
        
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
        usedHint = false
        usedReveal = false
        attemptCount = 0
        feedbackMessage = ""
        easyCount = 0
        goodCount = 0
        hardCount = 0
        againCount = 0
        loadWords()
    }
    
    // MARK: - Finalization
    
    private func finalizeQuiz() {
        quizState = .completed
        
        guard let level = level, let context = modelContext else { return }
        
        // Save context
        try? context.save()
        
        // Check for auto-progression (mastery > 80%)
        checkAutoProgression()
    }
    
    /// Check if user should auto-unlock next level
    private func checkAutoProgression() {
        guard let level = level, let context = modelContext else { return }
        
        // Calculate mastery: words with stability > 21 days
        let levelID = level.levelID
        let wordDescriptor = FetchDescriptor<Word>(
            predicate: #Predicate { $0.levelID == levelID }
        )
        
        guard let allWords = try? context.fetch(wordDescriptor) else { return }
        
        let masteredCount = allWords.filter { $0.stability > 21 }.count
        let mastery = allWords.isEmpty ? 0 : Double(masteredCount) / Double(allWords.count)
        
        // Auto-unlock at 80%
        if mastery >= 0.8 && !level.isPassed {
            level.isPassed = true
            
            // Unlock next level
            let nextLevelID = level.levelID + 1
            let nextDescriptor = FetchDescriptor<StudyLevel>(
                predicate: #Predicate { $0.levelID == nextLevelID }
            )
            
            if let nextLevel = try? context.fetch(nextDescriptor).first {
                if nextLevel.isLocked {
                    nextLevel.isLocked = false
                    unlockedLevelName = nextLevel.displayTitle
                    
                    try? context.save()
                    
                    // Trigger celebration
                    showLevelUpAlert = true
                    quizState = .levelUp
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func gradeEmoji(_ grade: ImplicitGrade) -> String {
        switch grade {
        case .easy: return "🎯"
        case .good: return "✓"
        case .hard: return "💪"
        case .again: return "🔄"
        }
    }
}
