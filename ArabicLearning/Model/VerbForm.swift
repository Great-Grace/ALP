// VerbForm.swift
// 동사 파생형 모델 - Enriched Semantic Data Support

import Foundation
import SwiftData

@Model
final class VerbForm {
    var id: UUID = UUID()
    
    // MARK: - Core Data
    
    /// 어근 (아랍어, 하이픈 구분) - 예: "ك-ت-ب"
    var root: String = ""
    
    /// 어근 (모음/하이픈 제거, 검색용) - 예: "كتب"
    var rootClean: String = ""
    
    /// 동사 형태 번호 (1~10)
    var formNumber: Int = 1
    
    /// 패턴 (아랍어) - "فَعَلَ", "فَعَّلَ", ...
    var pattern: String = ""
    
    /// 뉘앙스/의미 (한국어) - 기본 형태 뉘앙스 "사동/강조", "상호동작", ...
    var nuanceBasic: String = ""
    
    /// 아랍어 단어 (완전 모음) - "كَتَبَ"
    var arabicWord: String = ""
    
    /// 아랍어 단어 (모음 제거, 검색용) - "كتب"
    var arabicWordClean: String = ""
    
    /// 한국어 뜻 (레거시) - "쓰다"
    var meaningKorean: String = ""
    
    /// CAMeL 검증 여부
    var verified: Bool = false
    
    // MARK: - Enriched Data (NEW)
    
    /// 주요 의미 (한국어, 1-2단어) - "쓰다"
    var meaningPrimary: String?
    
    /// 보조 의미 (여러 용법) - "기록하다; 저술하다"
    var meaningSecondary: String?
    
    /// 상세 뉘앙스 설명 (한국어) - "타동사이며, 물리적 쓰기 행위를 나타냄"
    var nuanceKorean: String?
    
    /// 예문 (모음부호 포함 아랍어)
    var exampleSentence: String?
    
    /// 예문 한국어 번역
    var exampleSentenceMeaning: String?
    
    // MARK: - Computed (Presentation Layer)
    
    /// 형태 라벨 (동적 생성) - "1형", "2형", ...
    var formLabel: String {
        return "\(formNumber)형"
    }
    
    /// 표시용 의미 (Primary 우선, 없으면 Legacy)
    var displayMeaning: String {
        if let primary = meaningPrimary, !primary.isEmpty {
            return primary
        }
        return meaningKorean
    }
    
    /// 표시용 뉘앙스 (상세 설명 우선)
    var displayNuance: String {
        if let nuance = nuanceKorean, !nuance.isEmpty {
            return nuance
        }
        return nuanceBasic
    }
    
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
    
    // MARK: - Computed: Retrievability
    
    var currentRetrievability: Double {
        guard let lastDate = lastReviewedAt else { return 0.0 }
        let elapsedDays = Date().timeIntervalSince(lastDate) / 86400
        return ReviewScheduler.shared.calculateRetrievability(stability: stability, daysSince: elapsedDays)
    }
    
    var needsReview: Bool {
        guard lastReviewedAt != nil else { return status == .new }
        return currentRetrievability < 0.9
    }
    
    // MARK: - Init
    
    init(
        root: String,
        formNumber: Int,
        pattern: String,
        nuanceBasic: String,
        arabicWord: String,
        meaningKorean: String = "",
        verified: Bool = false,
        // Enriched data
        meaningPrimary: String? = nil,
        meaningSecondary: String? = nil,
        nuanceKorean: String? = nil,
        exampleSentence: String? = nil,
        exampleSentenceMeaning: String? = nil
    ) {
        self.id = UUID()
        self.root = root
        self.rootClean = root.replacingOccurrences(of: "-", with: "").withoutDiacritics
        self.formNumber = formNumber
        self.pattern = pattern
        self.nuanceBasic = nuanceBasic
        self.arabicWord = arabicWord
        self.arabicWordClean = arabicWord.withoutDiacritics
        self.meaningKorean = meaningKorean
        self.verified = verified
        // Enriched
        self.meaningPrimary = meaningPrimary
        self.meaningSecondary = meaningSecondary
        self.nuanceKorean = nuanceKorean
        self.exampleSentence = exampleSentence
        self.exampleSentenceMeaning = exampleSentenceMeaning
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
