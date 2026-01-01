// Word Model - SwiftData
// 아랍어 단어 정보 (Cloze Test 지원 + Custom FSRS)

import Foundation
import SwiftData

// MARK: - Learning Status (SRS)
enum LearningStatus: String, Codable {
    case new = "new"
    case learning = "learning"
    case review = "review"
    case mastered = "mastered"
}

// MARK: - Morphology Type (형태론 분류)
enum MorphologyType: String, Codable {
    case sound = "Sound"           // 완전동사/명사 (Strong)
    case hollow = "Hollow"         // 속빈동사 (중간 약자음: قال، نام)
    case defective = "Defective"   // 불완전동사 (끝 약자음: مشى، دعا)
    case hamzated = "Hamzated"     // 함자동사 (أ 포함: أكل، قرأ)
    case rigid = "Rigid"           // 변하지않는 단어 (전치사, 접속사)
}

@Model
final class Word {
    var id: UUID = UUID()
    var arabic: String = ""             // 아랍어 단어 (정답)
    var korean: String = ""             // 한국어 뜻
    var exampleSentence: String = ""    // 완전한 아랍어 예문
    var sentenceKorean: String = ""     // 예문의 한국어 해석
    var sentenceWithBlank: String = ""  // 빈칸 처리된 예문

    
    // Dual Storage - 최적화를 위한 모음 제거 버전
    var arabicClean: String = ""        // 모음 없는 단어 (예: بيت)
    var sentenceClean: String = ""      // 모음 없는 예문 (예: هذا بيت جميل)
    
    // MARK: - Morphology (형태론)
    
    /// 어근 (Root/Radical) - 예: "ك-ت-ب"
    var root: String?
    
    /// 패턴 (Pattern/Wazan) - 예: "فَاعِل", "مَفْعُول", "فِعَال"
    var pattern: String?
    
    /// 동사 형태 (Form 1-10) - nil이면 명사/기타
    var verbForm: Int?
    
    /// 복잡도 레벨 (Spiral Curriculum)
    /// 1: 구체명사, 완전동사(과거), 전치사
    /// 2: 파생명사, 완전동사(현재/미래), 규칙 복수
    /// 3: 약동사(Hollow/Defective), 불규칙 복수, Form 2-10 심화
    var complexityLevel: Int = 1
    
    // MARK: - Curriculum Level
    
    /// Level ID for curriculum progression (default: 1)
    var levelID: Int = 1
    
    /// Sub-level ID (e.g., "6-3" for Block 6, Sub 3)
    var subLevelID: String?
    
    /// Relationship to StudyLevel (legacy)
    var level: StudyLevel?
    
    /// Relationship to SubLevel (new 50-level system)
    var subLevel: SubLevel?
    
    /// 형태론 유형
    /// Sound(완전), Hollow(속빈), Defective(불완전), Hamzated(함자), Rigid(변하지않는)
    var morphologyTypeRaw: String?
    var morphologyType: MorphologyType? {
        get { morphologyTypeRaw.flatMap { MorphologyType(rawValue: $0) } }
        set { morphologyTypeRaw = newValue?.rawValue }
    }
    
    // MARK: - Dual-Column Quiz (Korean Localization)
    
    /// 동사 형태 라벨 (한국어) - 예: "1형", "2형", ... "10형"
    var verbFormLabel: String? {
        guard let form = verbForm else { return nil }
        return "\(form)형"
    }
    
    /// 뉘앙스/의미 (한국어) - 예: "사동/강조", "상호동작", "재귀"
    var nuanceKorean: String?
    
    // MARK: - Spiral Curriculum Fields (L2/L3/L8)
    
    /// Level 2: Noun-Adjective phrase components (JSON)
    /// Example: {"noun": "بَيْت", "adj": "كَبِير"}
    var phraseComponents: String?
    
    /// Level 3: Link to singular form ID (for plural pairs)
    var singularForm: String?
    
    /// Level 8: Sentence grammatical analysis (JSON)
    /// Example: {"verb": "ذَهَبَ", "subject": "الطَّالِبُ", "object": "الْمَدْرَسَةِ"}
    var sentenceAnalysis: String?
    
    /// Gender: "M" (masculine) or "F" (feminine)
    var gender: String?
    
    /// CEFR Level: A1, A2, B1, B2, C1, C2
    var cefr: String?
    
    /// Data type: "vocabulary", "phrase", "plural_pair", "sentence"
    var dataType: String?
    // MARK: - Custom FSRS (DSR Framework)
    
    /// Difficulty: 1.0 (Easiest) ~ 10.0 (Hardest)
    var difficulty: Double = 5.0
    
    /// Stability: 기억 지속 기간 (일 단위), 1.0 ~ 365.0+
    var stability: Double = 1.0
    
    /// 다음 복습 예정일
    var nextReviewDate: Date?
    
    /// 마지막 복습 시간
    var lastReviewedAt: Date?
    
    /// 연속 정답 수 (보조 지표)
    var streak: Int = 0
    
    /// Is this word due for review? (nextReviewDate <= now)
    var isDueForReview: Bool {
        guard let nextDate = nextReviewDate else {
            return status != .mastered // New words are due unless mastered
        }
        return nextDate <= Date()
    }
    /// Learning Status
    var statusRaw: String = LearningStatus.new.rawValue
    var status: LearningStatus {
        get { LearningStatus(rawValue: statusRaw) ?? .new }
        set { statusRaw = newValue.rawValue }
    }
    
    // MARK: - Computed: Current Retrievability
    /// 현재 시점의 인출 가능성 (0.0 ~ 1.0)
    var currentRetrievability: Double {
        guard let lastDate = lastReviewedAt else { return 0.0 }
        let elapsedDays = Date().timeIntervalSince(lastDate) / 86400  // seconds to days
        return ReviewScheduler.shared.calculateRetrievability(stability: stability, daysSince: elapsedDays)
    }
    
    /// 복습 필요 여부 (R이 90% 이하로 떨어지면 복습 필요)
    var needsReview: Bool {
        guard lastReviewedAt != nil else { return status == .new }
        return currentRetrievability < 0.9
    }
    
    // MARK: - User-Added Tracking
    
    /// True if user added this word from reading (tap-to-add)
    var isUserAdded: Bool = false
    
    /// Level ID where user added this word (for tracking)
    var addedFromLevelID: Int?
    
    var createdAt: Date = Date()
    
    // Relationship - 퀴즈 기록
    @Relationship(deleteRule: .cascade, inverse: \QuizHistory.word)
    var quizHistory: [QuizHistory] = []
    
    // Relationship - Appearing Articles (Many-to-Many)
    var articles: [Article]? = []
    
    init(
        arabic: String,
        korean: String,
        exampleSentence: String = "",
        sentenceKorean: String = "",
        sentenceWithBlank: String? = nil
    ) {
        self.id = UUID()
        self.arabic = arabic
        self.korean = korean
        self.exampleSentence = exampleSentence
        self.sentenceKorean = sentenceKorean
        
        // 모음 제거 버전 자동 생성
        self.arabicClean = arabic.withoutDiacritics
        self.sentenceClean = exampleSentence.withoutDiacritics
        
        // 빈칸 자동 생성
        self.sentenceWithBlank = sentenceWithBlank ?? exampleSentence.replacingOccurrences(of: arabic, with: "(______)")
        self.createdAt = Date()
        
        // FSRS 초기값
        self.difficulty = 5.0
        self.stability = 1.0
        self.statusRaw = LearningStatus.new.rawValue
        self.streak = 0
    }
    
    // MARK: - FSRS Update Method (3-Tier System)
    /// 복습 결과 적용
    /// - Parameters:
    ///   - outcome: Clean/Hint/Reveal
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
        
        // Status 업데이트 (3-Tier)
        switch outcome {
        case .clean:
            self.streak += 1
            if self.streak >= 3 && self.stability >= 21 {
                self.status = .mastered
            } else {
                self.status = .review
            }
        case .hint:
            // Hint는 streak 유지 (한 번 실수 정도는 봐줌)
            self.status = .learning
        case .reveal:
            self.streak = 0
            self.status = .learning
        }
    }
}
