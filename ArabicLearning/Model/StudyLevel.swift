// StudyLevel.swift
// Level-based curriculum progression model

import Foundation
import SwiftData

// MARK: - Level Type Enum (No Magic Numbers!)

/// Determines the learning mode and quiz type for each level
enum LevelType: String, Codable, CaseIterable {
    case vocabulary  // 어휘 중심: 20/10 Mixed Quiz
    case grammar     // 문법/구조 중심: Structure Analysis Quiz
    
    var displayName: String {
        switch self {
        case .vocabulary: return "어휘 학습"
        case .grammar: return "구조 학습"
        }
    }
    
    var icon: String {
        switch self {
        case .vocabulary: return "textformat.abc"
        case .grammar: return "rectangle.3.group"
        }
    }
    
    var actionTitle: String {
        switch self {
        case .vocabulary: return "오늘의 어휘 학습"
        case .grammar: return "문장 구조 학습"
        }
    }
    
    var actionSubtitle: String {
        switch self {
        case .vocabulary: return "복습 20개 + 신규 10개"
        case .grammar: return "구조 분석 및 패턴 학습"
        }
    }
    
    var color: String {
        switch self {
        case .vocabulary: return "orange"
        case .grammar: return "purple"
        }
    }
}
@Model
final class StudyLevel {
    
    // MARK: - Core Properties
    
    /// Primary key (1, 2, 3...)
    @Attribute(.unique) var levelID: Int = 1
    
    /// Level title (e.g., "Level 1: Essential Verbs")
    var title: String = ""
    
    /// Level description
    var levelDescription: String = ""
    
    /// Whether this level is locked
    var isLocked: Bool = true
    
    /// Pass threshold (0.0 - 1.0, default 80%)
    var passThreshold: Double = 0.8
    
    /// User's best score on this level's test (0.0 - 1.0)
    var bestScore: Double = 0.0
    
    /// Whether the level test has been passed
    var isPassed: Bool = false
    
    /// Level type (vocabulary or grammar) - stored as raw string for SwiftData
    var levelTypeRaw: String = LevelType.vocabulary.rawValue
    
    /// Computed property for type-safe access
    var levelType: LevelType {
        get { LevelType(rawValue: levelTypeRaw) ?? .vocabulary }
        set { levelTypeRaw = newValue.rawValue }
    }
    // MARK: - Relationships
    
    @Relationship(deleteRule: .nullify, inverse: \Word.level)
    var words: [Word]? = []
    
    @Relationship(deleteRule: .cascade, inverse: \ReadingPassage.level)
    var passages: [ReadingPassage]? = []
    
    // MARK: - Computed Properties
    
    var wordCount: Int {
        words?.count ?? 0
    }
    
    var passageCount: Int {
        passages?.count ?? 0
    }
    
    var displayTitle: String {
        if title.isEmpty {
            return "레벨 \(levelID)"
        }
        return title
    }
    
    var statusIcon: String {
        if isPassed {
            return "checkmark.circle.fill"
        } else if isLocked {
            return "lock.fill"
        } else {
            return "circle"
        }
    }
    
    // MARK: - Init
    
    init(levelID: Int, title: String = "", description: String = "", isLocked: Bool = true, type: LevelType = .vocabulary) {
        self.levelID = levelID
        self.title = title
        self.levelDescription = description
        self.isLocked = isLocked
        self.levelTypeRaw = type.rawValue
    }
    
    // MARK: - Static: Seed Levels
    
    /// Creates default levels if database is empty
    @MainActor
    static func seedLevels(context: ModelContext) {
        // Check if levels exist
        let descriptor = FetchDescriptor<StudyLevel>()
        guard let count = try? context.fetchCount(descriptor), count == 0 else {
            return
        }
        
        // 8-Level Curriculum (2026 Re-Architecture)
        // Levels 1, 4-7: vocabulary
        // Levels 2, 3: grammar/structure
        // Level 8: sentence
        let defaultLevels: [(id: Int, title: String, desc: String, type: LevelType)] = [
            (1, "기초 어휘", "기초 단어 및 표현", .vocabulary),
            (2, "명사-형용사 구문", "성수일치 학습", .grammar),
            (3, "단수-복수", "불규칙 복수형 학습", .grammar),
            (4, "동사 I", "Form 1-2 기본 동사", .vocabulary),
            (5, "동사 II", "Form 3-4 파생 동사", .vocabulary),
            (6, "동사 III", "Form 5-7 파생 동사", .vocabulary),
            (7, "동사 IV", "Form 8-10 파생 동사", .vocabulary),
            (8, "문장 분석", "복합 문장 구조 학습", .grammar),
        ]
        
        for (index, info) in defaultLevels.enumerated() {
            let level = StudyLevel(
                levelID: info.id,
                title: info.title,
                description: info.desc,
                isLocked: index > 0, // Level 1 is unlocked
                type: info.type
            )
            context.insert(level)
        }
        
        try? context.save()
    }
    
    // MARK: - Progress Methods
    
    /// Marks the level as passed and unlocks the next level
    @MainActor
    func markAsPassed(context: ModelContext) {
        self.isPassed = true
        
        // Unlock next level
        let nextLevelID = self.levelID + 1
        let descriptor = FetchDescriptor<StudyLevel>(
            predicate: #Predicate { $0.levelID == nextLevelID }
        )
        
        if let nextLevel = try? context.fetch(descriptor).first {
            nextLevel.isLocked = false
        }
        
        try? context.save()
    }
    
    /// Updates best score and checks for pass
    @MainActor
    func updateScore(_ score: Double, context: ModelContext) {
        if score > self.bestScore {
            self.bestScore = score
        }
        
        if score >= self.passThreshold && !self.isPassed {
            markAsPassed(context: context)
        }
        
        try? context.save()
    }
}
