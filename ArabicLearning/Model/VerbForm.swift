// VerbForm.swift
// 동사 파생형 모델 - Dual-Column Quiz 전용

import Foundation
import SwiftData

@Model
final class VerbForm {
    var id: UUID = UUID()
    
    // MARK: - Core Data
    
    /// 어근 (아랍어) - 예: "ك-ت-ب"
    var root: String = ""
    
    /// 동사 형태 번호 (1~10)
    var formNumber: Int = 1
    
    /// 형태 라벨 (한국어) - "1형", "2형", ...
    var formLabel: String = "1형"
    
    /// 패턴 (아랍어) - "فَعَلَ", "فَعَّلَ", ...
    var pattern: String = ""
    
    /// 뉘앙스/의미 (한국어) - "사동/강조", "상호동작", ...
    var nuanceKorean: String = ""
    
    /// 아랍어 단어 (완전 모음) - "كَتَبَ"
    var arabicWord: String = ""
    
    /// 한국어 뜻 - "쓰다"
    var meaningKorean: String = ""
    
    /// CAMeL 검증 여부
    var verified: Bool = false
    
    // MARK: - FSRS (Dual-Column Quiz용)
    
    /// Difficulty: 1.0 ~ 10.0
    var difficulty: Double = 5.0
    
    /// Stability (일 단위)
    var stability: Double = 1.0
    
    /// 다음 복습일
    var nextReviewDate: Date?
    
    /// 마지막 복습 시간
    var lastReviewedAt: Date?
    
    /// 연속 정답 수
    var streak: Int = 0
    
    /// 학습 상태
    var statusRaw: String = "new"
    var status: LearningStatus {
        get { LearningStatus(rawValue: statusRaw) ?? .new }
        set { statusRaw = newValue.rawValue }
    }
    
    // MARK: - Computed
    
    /// 현재 인출 가능성
    var currentRetrievability: Double {
        guard let lastDate = lastReviewedAt else { return 0.0 }
        let elapsedDays = Date().timeIntervalSince(lastDate) / 86400
        return ReviewScheduler.shared.calculateRetrievability(stability: stability, daysSince: elapsedDays)
    }
    
    /// 복습 필요 여부
    var needsReview: Bool {
        guard lastReviewedAt != nil else { return status == .new }
        return currentRetrievability < 0.9
    }
    
    // MARK: - Init
    
    init(
        root: String,
        formNumber: Int,
        formLabel: String,
        pattern: String,
        nuanceKorean: String,
        arabicWord: String,
        meaningKorean: String = "",
        verified: Bool = false
    ) {
        self.id = UUID()
        self.root = root
        self.formNumber = formNumber
        self.formLabel = formLabel
        self.pattern = pattern
        self.nuanceKorean = nuanceKorean
        self.arabicWord = arabicWord
        self.meaningKorean = meaningKorean
        self.verified = verified
    }
    
    // MARK: - FSRS Apply
    
    func applyReviewResult(outcome: ReviewOutcome) {
        let isNewCard = (status == .new)
        
        let result = ReviewScheduler.shared.processReview(
            currentStability: stability,
            currentDifficulty: difficulty,
            outcome: outcome,
            isNewCard: isNewCard
        )
        
        self.stability = result.stability
        self.difficulty = result.difficulty
        self.nextReviewDate = result.nextReviewDate
        self.lastReviewedAt = Date()
        
        switch outcome {
        case .clean:
            self.streak += 1
            if self.streak >= 3 && self.stability >= 21 {
                self.status = .mastered
            } else {
                self.status = .review
            }
        case .hint:
            self.status = .learning
        case .reveal:
            self.streak = 0
            self.status = .learning
        }
    }
}
