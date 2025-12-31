// QuizSessionGenerator.swift
// Generates daily study sessions with 20/10 rule

import Foundation
import SwiftData

/// Session type based on level state
enum SessionType {
    case active      // Current level: New words + Reviews + User-added
    case passive     // Cleared level: Original words only
}

/// Generated session with words
struct StudySession {
    let type: SessionType
    let words: [Word]
    let newWordsCount: Int
    let reviewWordsCount: Int
    let userAddedCount: Int
    
    var totalCount: Int { words.count }
}

/// Service for generating daily study sessions
@MainActor
class QuizSessionGenerator {
    
    // MARK: - Singleton
    
    static let shared = QuizSessionGenerator()
    private init() {}
    
    // MARK: - Constants
    
    /// Daily quota
    static let dailyQuota = 30
    
    /// 20/10 Rule: 20 reviews, 10 new words
    static let reviewPriority = 20
    static let newWordsPriority = 10
    
    /// Mature threshold for FSRS (21 days)
    static let matureStabilityThreshold: Double = 21.0
    
    // MARK: - Session Generation
    
    /// Generates a study session for the given level
    func generateSession(
        for level: StudyLevel,
        type: SessionType,
        context: ModelContext
    ) -> StudySession {
        
        switch type {
        case .active:
            return generateActiveSession(for: level, context: context)
        case .passive:
            return generatePassiveSession(for: level, context: context)
        }
    }
    
    // MARK: - Active Session (Daily Learning)
    
    /// Active Level: 20 reviews + 10 new words (with fill logic)
    private func generateActiveSession(
        for level: StudyLevel,
        context: ModelContext
    ) -> StudySession {
        
        let levelID = level.levelID
        
        // 1. Get review items (FSRS overdue + user-added)
        let reviewWords = fetchReviewWords(levelID: levelID, context: context)
        
        // 2. Get new words for this level
        let newWords = fetchNewWords(levelID: levelID, context: context)
        
        // 3. Apply 20/10 rule with fill logic
        var selectedReviews: [Word] = []
        var selectedNew: [Word] = []
        
        // Priority 1: Up to 20 review words
        let reviewCount = min(reviewWords.count, Self.reviewPriority)
        selectedReviews = Array(reviewWords.prefix(reviewCount))
        
        // Priority 2: Up to 10 new words
        let remainingQuota = Self.dailyQuota - selectedReviews.count
        let newCount = min(newWords.count, min(Self.newWordsPriority, remainingQuota))
        selectedNew = Array(newWords.prefix(newCount))
        
        // Fill logic: If reviews < 20, add more new words
        if selectedReviews.count < Self.reviewPriority && selectedNew.count < remainingQuota {
            let additionalNew = Array(newWords.dropFirst(newCount).prefix(remainingQuota - newCount))
            selectedNew.append(contentsOf: additionalNew)
        }
        
        // Fill logic: If new words < 10, add more reviews
        if selectedNew.count < Self.newWordsPriority && selectedReviews.count < remainingQuota {
            let additionalReviews = Array(reviewWords.dropFirst(reviewCount).prefix(remainingQuota - selectedNew.count - reviewCount))
            selectedReviews.append(contentsOf: additionalReviews)
        }
        
        // Combine and shuffle
        var allWords = selectedReviews + selectedNew
        allWords.shuffle()
        
        // Count user-added words
        let userAddedCount = allWords.filter { $0.isUserAdded }.count
        
        return StudySession(
            type: .active,
            words: allWords,
            newWordsCount: selectedNew.count,
            reviewWordsCount: selectedReviews.count,
            userAddedCount: userAddedCount
        )
    }
    
    // MARK: - Passive Session (Review Only)
    
    /// Passive Level: Only original words from this level
    private func generatePassiveSession(
        for level: StudyLevel,
        context: ModelContext
    ) -> StudySession {
        
        let levelID = level.levelID
        
        // Fetch only original (non-user-added) words
        var descriptor = FetchDescriptor<Word>(
            predicate: #Predicate { 
                $0.levelID == levelID && $0.isUserAdded == false 
            }
        )
        descriptor.fetchLimit = 50  // Reasonable limit
        
        let words = (try? context.fetch(descriptor)) ?? []
        
        return StudySession(
            type: .passive,
            words: words.shuffled(),
            newWordsCount: 0,
            reviewWordsCount: words.count,
            userAddedCount: 0
        )
    }
    
    // MARK: - Fetch Helpers
    
    /// Fetches words that need review (overdue by FSRS or user-added)
    private func fetchReviewWords(levelID: Int, context: ModelContext) -> [Word] {
        let now = Date()
        
        // Fetch all words for level (or user-added from any level)
        let descriptor = FetchDescriptor<Word>()
        
        guard let allWords = try? context.fetch(descriptor) else {
            return []
        }
        
        // Filter: Current level OR user-added, AND needs review
        return allWords.filter { word in
            let isThisLevel = word.levelID == levelID
            let isUserAdded = word.isUserAdded
            let needsReview = word.needsReview || (word.nextReviewDate ?? .distantFuture) <= now
            
            return (isThisLevel || isUserAdded) && needsReview && word.status != .new
        }
        .sorted { ($0.nextReviewDate ?? .distantPast) < ($1.nextReviewDate ?? .distantPast) }
    }
    
    /// Fetches new words that haven't been studied yet
    private func fetchNewWords(levelID: Int, context: ModelContext) -> [Word] {
        let descriptor = FetchDescriptor<Word>(
            predicate: #Predicate { 
                $0.levelID == levelID
            }
        )
        
        guard let words = try? context.fetch(descriptor) else {
            return []
        }
        
        // Filter: New status only
        return words.filter { $0.status == .new }
    }
}
