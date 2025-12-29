// ReviewScheduler.swift
// Custom FSRS (Free Spaced Repetition Scheduler) v5 Implementation
// 3-Tier System: Clean / Hint / Reveal

import Foundation

// MARK: - Review Outcome (3-Tier System)
enum ReviewOutcome: Int {
    case clean = 3    // 순수 기억 인출 성공 (No hint, no reveal)
    case hint = 2     // 힌트 사용 후 정답 (Partial recall)
    case reveal = 1   // 정답 보고 타이핑 (Memory failure)
}

// MARK: - ReviewScheduler (Singleton)
final class ReviewScheduler {
    static let shared = ReviewScheduler()
    
    private init() {}
    
    // MARK: - Constants (FSRS v5 Optimized)
    
    /// Forgetting curve constants
    private let factor: Double = -0.1054
    private let decay: Double = -0.5
    
    /// Stability growth weight (higher D = more reward for success)
    private let wDifficulty: Double = 0.02  // 더 급격한 성장
    
    /// Penalty multipliers (3-Tier)
    private let hintPenalty: Double = 0.75    // Hint: 25% 감소 (관대)
    private let revealPenalty: Double = 0.40  // Reveal: 60% 감소 (엄격)
    
    /// Difficulty adjustment values
    private let cleanDifficultyDelta: Double = -0.1   // 쉬워짐
    private let hintDifficultyDelta: Double = 0.3     // 어려워짐
    private let revealDifficultyDelta: Double = 1.0   // 매우 어려워짐
    
    /// Bounds
    private let minDifficulty: Double = 1.0
    private let maxDifficulty: Double = 10.0
    private let minStability: Double = 1.0
    private let maxStability: Double = 365.0
    
    // MARK: - 1.1 Calculate Retrievability
    /// Forgetting Curve: R(t) = (1 + factor * t / S)^decay
    func calculateRetrievability(stability: Double, daysSince: Double) -> Double {
        let safeStability = max(stability, 0.1)
        let base = 1.0 + (factor * daysSince / safeStability)
        let retrievability = pow(max(base, 0.0), decay)
        return min(max(retrievability, 0.0), 1.0)
    }
    
    // MARK: - 1.2 Update Stability (3-Tier)
    /// Updates stability based on review outcome
    /// - Parameters:
    ///   - outcome: Clean / Hint / Reveal
    ///   - currentS: Current stability
    ///   - currentD: Current difficulty
    ///   - isNewCard: Whether this is first-time learning
    /// - Returns: New stability value
    func updateStability(
        outcome: ReviewOutcome,
        currentS: Double,
        currentD: Double,
        isNewCard: Bool = false
    ) -> Double {
        let safeS = max(currentS, minStability)
        let safeD = max(min(currentD, maxDifficulty), minDifficulty)
        
        var newS: Double
        
        switch outcome {
        case .clean:
            // 순수 기억 인출 성공: S 폭발적 성장
            // S_new = S * (1 + w * D^(-0.5) * S^(-0.5))
            // 난이도가 높을수록 보상 큼 (어려운 걸 외웠으니 칭찬)
            let growthFactor = 1.0 + wDifficulty * pow(safeD, -0.5) * pow(safeS, -0.5)
            
            // 난이도가 높으면 추가 보너스
            let difficultyBonus = 1.0 + (safeD - 5.0) * 0.02
            newS = safeS * growthFactor * max(difficultyBonus, 1.0)
            
        case .hint:
            // 힌트 사용: 망각 직전 상태, S 소폭 삭감
            if isNewCard {
                // 새 카드는 페널티 없이 기본값 유지
                newS = max(safeS, 2.0)
            } else {
                newS = safeS * hintPenalty
            }
            
        case .reveal:
            // 정답 보기: 인출 실패, S 대폭 삭감
            if isNewCard {
                // 새 카드는 페널티 없이 초기화
                newS = minStability
            } else {
                newS = safeS * revealPenalty
            }
        }
        
        return min(max(newS, minStability), maxStability)
    }
    
    // MARK: - 1.3 Update Difficulty (3-Tier)
    /// Updates difficulty based on review outcome
    func updateDifficulty(outcome: ReviewOutcome, currentD: Double) -> Double {
        var newD: Double
        
        switch outcome {
        case .clean:
            newD = currentD + cleanDifficultyDelta  // -0.1
        case .hint:
            newD = currentD + hintDifficultyDelta   // +0.3
        case .reveal:
            newD = currentD + revealDifficultyDelta // +1.0
        }
        
        return min(max(newD, minDifficulty), maxDifficulty)
    }
    
    // MARK: - 1.4 Calculate Next Review Date
    /// Calculates next review date with fuzzing
    func calculateNextReviewDate(stability: Double) -> Date {
        // Interval: ceil(1.8 * S)
        let baseInterval = ceil(1.8 * stability)
        
        // Fuzzing to prevent clustering
        var fuzz: Int = 0
        if baseInterval > 20 {
            fuzz = Int.random(in: -2...2)
        } else if baseInterval > 10 {
            fuzz = Int.random(in: -1...1)
        }
        
        let finalInterval = max(1, Int(baseInterval) + fuzz)
        return Calendar.current.date(byAdding: .day, value: finalInterval, to: Date()) ?? Date()
    }
    
    // MARK: - Convenience: Process Review (3-Tier)
    /// Processes a complete review and returns updated values
    func processReview(
        currentStability: Double,
        currentDifficulty: Double,
        outcome: ReviewOutcome,
        isNewCard: Bool = false
    ) -> (stability: Double, difficulty: Double, nextReviewDate: Date) {
        let newS = updateStability(outcome: outcome, currentS: currentStability, currentD: currentDifficulty, isNewCard: isNewCard)
        let newD = updateDifficulty(outcome: outcome, currentD: currentDifficulty)
        let nextDate = calculateNextReviewDate(stability: newS)
        
        return (newS, newD, nextDate)
    }
}
