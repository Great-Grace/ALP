// ProgressionManager.swift
// Manages level unlock logic based on FSRS mastery and test scores

import Foundation
import SwiftData

/// Level unlock type
enum UnlockType {
    case vocabulary  // 80% words mature
    case test        // Pass test with 80%+
    case both        // Requires both conditions
}

/// Progression check result
struct ProgressionResult {
    let canUnlock: Bool
    let masteryPercentage: Double
    let matureWordCount: Int
    let totalWordCount: Int
    let testScore: Double
    let reason: String
}

/// Manages level progression and unlock logic
@MainActor
class ProgressionManager {
    
    // MARK: - Singleton
    
    static let shared = ProgressionManager()
    private init() {}
    
    // MARK: - Constants
    
    /// Mastery threshold: 80% of words must be mature
    static let masteryThreshold: Double = 0.8
    
    /// Test passing score: 80%
    static let testPassingScore: Double = 0.8
    
    /// FSRS Stability threshold for "mature" (21 days)
    static let matureStabilityDays: Double = 21.0
    
    // MARK: - Progression Check
    
    /// Checks if the next level can be unlocked
    func checkProgression(
        for level: StudyLevel,
        unlockType: UnlockType = .test,
        context: ModelContext
    ) -> ProgressionResult {
        
        let masteryData = calculateMastery(for: level, context: context)
        let testScore = level.bestScore
        
        var canUnlock = false
        var reason = ""
        
        switch unlockType {
        case .vocabulary:
            canUnlock = masteryData.percentage >= Self.masteryThreshold
            reason = canUnlock 
                ? "어휘 마스터리 달성! (\(Int(masteryData.percentage * 100))%)" 
                : "어휘 마스터리 필요: \(Int(masteryData.percentage * 100))% / \(Int(Self.masteryThreshold * 100))%"
            
        case .test:
            canUnlock = testScore >= Self.testPassingScore
            reason = canUnlock 
                ? "테스트 통과! (\(Int(testScore * 100))점)" 
                : "테스트 점수 필요: \(Int(testScore * 100))점 / \(Int(Self.testPassingScore * 100))점"
            
        case .both:
            let masteryMet = masteryData.percentage >= Self.masteryThreshold
            let testMet = testScore >= Self.testPassingScore
            canUnlock = masteryMet && testMet
            
            if canUnlock {
                reason = "모든 조건 충족!"
            } else if !masteryMet && !testMet {
                reason = "어휘 마스터리와 테스트 모두 필요"
            } else if !masteryMet {
                reason = "어휘 마스터리 필요: \(Int(masteryData.percentage * 100))%"
            } else {
                reason = "테스트 통과 필요: \(Int(testScore * 100))점"
            }
        }
        
        return ProgressionResult(
            canUnlock: canUnlock,
            masteryPercentage: masteryData.percentage,
            matureWordCount: masteryData.matureCount,
            totalWordCount: masteryData.totalCount,
            testScore: testScore,
            reason: reason
        )
    }
    
    // MARK: - Mastery Calculation
    
    /// Calculates the percentage of mature words in a level
    func calculateMastery(
        for level: StudyLevel, 
        context: ModelContext
    ) -> (percentage: Double, matureCount: Int, totalCount: Int) {
        
        let levelID = level.levelID
        let descriptor = FetchDescriptor<Word>(
            predicate: #Predicate { $0.levelID == levelID && $0.isUserAdded == false }
        )
        
        guard let words = try? context.fetch(descriptor), !words.isEmpty else {
            return (0.0, 0, 0)
        }
        
        // Count mature words (stability >= 21 days)
        let matureWords = words.filter { $0.stability >= Self.matureStabilityDays }
        
        let percentage = Double(matureWords.count) / Double(words.count)
        
        return (percentage, matureWords.count, words.count)
    }
    
    // MARK: - FSRS Update Handler
    
    /// Called after each quiz answer to update FSRS and check progression
    func handleAnswerResponse(
        word: Word,
        grade: AnswerGrade,
        context: ModelContext
    ) {
        // 1. Update FSRS values
        updateFSRS(word: word, grade: grade)
        
        // 2. Check if this triggers level unlock
        if let level = word.level {
            let result = checkProgression(for: level, unlockType: .test, context: context)
            
            if result.canUnlock && !level.isPassed {
                level.markAsPassed(context: context)
            }
        }
        
        try? context.save()
    }
    
    /// Updates FSRS values based on answer grade
    private func updateFSRS(word: Word, grade: AnswerGrade) {
        let now = Date()
        
        switch grade {
        case .easy:
            // Increase stability significantly, decrease difficulty
            word.stability = min(word.stability * 2.5, 365)
            word.difficulty = max(word.difficulty - 0.5, 1.0)
            word.streak += 1
            
        case .good:
            // Normal progression
            word.stability = min(word.stability * 1.8, 365)
            word.difficulty = max(word.difficulty - 0.1, 1.0)
            word.streak += 1
            
        case .hard:
            // Slight increase with difficulty bump
            word.stability = max(word.stability * 1.2, 1.0)
            word.difficulty = min(word.difficulty + 0.3, 10.0)
            word.streak = 0
            
        case .again:
            // Reset stability, significant difficulty increase
            word.stability = 1.0
            word.difficulty = min(word.difficulty + 0.5, 10.0)
            word.streak = 0
        }
        
        // Update review dates
        word.lastReviewedAt = now
        word.nextReviewDate = now.addingTimeInterval(word.stability * 86400)
        
        // Update status
        if word.stability >= ProgressionManager.matureStabilityDays {
            word.status = .mastered
        } else if word.stability >= 7 {
            word.status = .review
        } else {
            word.status = .learning
        }
    }
}

// MARK: - Answer Grade

enum AnswerGrade {
    case again  // Complete failure, reset
    case hard   // Difficult, slight progress
    case good   // Normal success
    case easy   // Very easy, accelerate
}
