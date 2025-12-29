// FSRSTests.swift
// Unit Tests for Custom FSRS Algorithm (3-Tier System)

import XCTest
@testable import ArabicLearning

final class FSRSTests: XCTestCase {
    
    var scheduler: ReviewScheduler!
    
    override func setUp() {
        super.setUp()
        scheduler = ReviewScheduler.shared
    }
    
    // MARK: - Test 1: Retention Decay
    func testRetentionDecay() {
        let stability: Double = 10.0
        
        let r0 = scheduler.calculateRetrievability(stability: stability, daysSince: 0)
        let r5 = scheduler.calculateRetrievability(stability: stability, daysSince: 5)
        let r10 = scheduler.calculateRetrievability(stability: stability, daysSince: 10)
        let r20 = scheduler.calculateRetrievability(stability: stability, daysSince: 20)
        
        XCTAssertGreaterThan(r0, r5, "R at day 0 should be > R at day 5")
        XCTAssertGreaterThan(r5, r10, "R at day 5 should be > R at day 10")
        XCTAssertGreaterThan(r10, r20, "R at day 10 should be > R at day 20")
        XCTAssertGreaterThan(r0, 0.99, "R at day 0 should be ~1.0")
        XCTAssertGreaterThanOrEqual(r20, 0.0, "R should be >= 0")
        XCTAssertLessThanOrEqual(r0, 1.0, "R should be <= 1")
    }
    
    // MARK: - Test 2: Stability Growth on Clean
    func testStabilityGrowthOnClean() {
        let initialS: Double = 5.0
        let difficulty: Double = 5.0
        
        let newS = scheduler.updateStability(
            outcome: .clean,
            currentS: initialS,
            currentD: difficulty,
            isNewCard: false
        )
        
        XCTAssertGreaterThan(newS, initialS, "Stability should increase on clean solve")
    }
    
    // MARK: - Test 3: Stability Penalty (3-Tier)
    func testStabilityPenalty3Tier() {
        let initialS: Double = 10.0
        let difficulty: Double = 5.0
        
        // Hint → 25% decrease (multiply by 0.75)
        let afterHint = scheduler.updateStability(
            outcome: .hint,
            currentS: initialS,
            currentD: difficulty,
            isNewCard: false
        )
        
        let expectedHintS = initialS * 0.75
        XCTAssertEqual(afterHint, expectedHintS, accuracy: 0.01, "Hint should reduce S by 25%")
        
        // Reveal → 60% decrease (multiply by 0.40)
        let afterReveal = scheduler.updateStability(
            outcome: .reveal,
            currentS: initialS,
            currentD: difficulty,
            isNewCard: false
        )
        
        let expectedRevealS = initialS * 0.40
        XCTAssertEqual(afterReveal, expectedRevealS, accuracy: 0.01, "Reveal should reduce S by 60%")
    }
    
    // MARK: - Test 4: New Card Exception
    func testNewCardException() {
        let initialS: Double = 1.0
        let difficulty: Double = 5.0
        
        // New card with hint → no penalty (S stays >= 2)
        let afterHint = scheduler.updateStability(
            outcome: .hint,
            currentS: initialS,
            currentD: difficulty,
            isNewCard: true
        )
        XCTAssertGreaterThanOrEqual(afterHint, 2.0, "New card hint should not apply penalty")
        
        // New card with reveal → S stays at min (1.0)
        let afterReveal = scheduler.updateStability(
            outcome: .reveal,
            currentS: initialS,
            currentD: difficulty,
            isNewCard: true
        )
        XCTAssertEqual(afterReveal, 1.0, accuracy: 0.01, "New card reveal should stay at 1.0")
    }
    
    // MARK: - Test 5: Fuzzing Check
    func testFuzzingVariation() {
        let stability: Double = 30.0
        var dates: Set<Date> = []
        
        for _ in 0..<10 {
            let nextDate = scheduler.calculateNextReviewDate(stability: stability)
            dates.insert(nextDate)
        }
        
        XCTAssertGreaterThan(dates.count, 1, "Fuzzing should produce variation in dates")
    }
    
    // MARK: - Test 6: Difficulty Update (3-Tier)
    func testDifficultyUpdate3Tier() {
        let initialD: Double = 5.0
        
        let afterClean = scheduler.updateDifficulty(outcome: .clean, currentD: initialD)
        let afterHint = scheduler.updateDifficulty(outcome: .hint, currentD: initialD)
        let afterReveal = scheduler.updateDifficulty(outcome: .reveal, currentD: initialD)
        
        // Clean → -0.1
        XCTAssertEqual(afterClean, initialD - 0.1, accuracy: 0.01, "Clean should reduce D by 0.1")
        
        // Hint → +0.3
        XCTAssertEqual(afterHint, initialD + 0.3, accuracy: 0.01, "Hint should increase D by 0.3")
        
        // Reveal → +1.0
        XCTAssertEqual(afterReveal, initialD + 1.0, accuracy: 0.01, "Reveal should increase D by 1.0")
    }
    
    // MARK: - Test 7: Bounds Check
    func testBoundsCheck() {
        // Stability minimum
        let minS = scheduler.updateStability(outcome: .reveal, currentS: 0.5, currentD: 5.0, isNewCard: false)
        XCTAssertGreaterThanOrEqual(minS, 1.0, "Stability should not go below 1.0")
        
        // Stability maximum
        let maxS = scheduler.updateStability(outcome: .clean, currentS: 360.0, currentD: 1.0, isNewCard: false)
        XCTAssertLessThanOrEqual(maxS, 365.0, "Stability should not exceed 365.0")
        
        // Difficulty bounds
        let minD = scheduler.updateDifficulty(outcome: .clean, currentD: 1.0)
        XCTAssertGreaterThanOrEqual(minD, 1.0, "Difficulty should not go below 1.0")
        
        let maxD = scheduler.updateDifficulty(outcome: .reveal, currentD: 10.0)
        XCTAssertLessThanOrEqual(maxD, 10.0, "Difficulty should not exceed 10.0")
    }
}
