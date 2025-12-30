// StudyLevel.swift
// Level-based curriculum progression model

import Foundation
import SwiftData

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
    
    init(levelID: Int, title: String = "", description: String = "", isLocked: Bool = true) {
        self.levelID = levelID
        self.title = title
        self.levelDescription = description
        self.isLocked = isLocked
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
        
        // Create default levels
        let defaultLevels: [(id: Int, title: String, desc: String)] = [
            (1, "기초 동사 I", "1형 기본 동사 50개"),
            (2, "기초 동사 II", "2-3형 파생 동사"),
            (3, "중급 동사 I", "4-5형 파생 동사"),
            (4, "중급 동사 II", "6-7형 파생 동사"),
            (5, "고급 동사", "8-10형 파생 동사"),
        ]
        
        for (index, info) in defaultLevels.enumerated() {
            let level = StudyLevel(
                levelID: info.id,
                title: info.title,
                description: info.desc,
                isLocked: index > 0 // Level 1 is unlocked
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
