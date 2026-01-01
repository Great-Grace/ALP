// SubLevel.swift
// Sub-level within a curriculum block (50 sub-levels for 12 blocks)

import Foundation
import SwiftData

@Model
final class SubLevel {
    
    // MARK: - Core Properties
    
    /// Sub-level ID (e.g., "6-3" for Block 6, Sub 3)
    @Attribute(.unique) var subLevelID: String = ""
    
    /// Block ID this sub-level belongs to (0-12)
    var blockID: Int = 0
    
    /// Order within block (1, 2, 3...)
    var orderInBlock: Int = 0
    
    /// Title in Korean (e.g., "1형 능동분사")
    var title: String = ""
    
    /// Single concept learned (e.g., "فَاعِل 패턴")
    var concept: String = ""
    
    /// Expected word count
    var targetWordCount: Int = 30
    
    /// Is this sub-level locked?
    var isLocked: Bool = true
    
    /// Progress (0.0 - 1.0)
    var progress: Double = 0.0
    
    /// Completion status
    var isCompleted: Bool = false
    
    /// Parent block reference
    var block: CurriculumBlock?
    
    /// Words in this sub-level
    @Relationship(deleteRule: .cascade, inverse: \Word.subLevel)
    var words: [Word]? = []
    
    // MARK: - Computed Properties
    
    var progressPercentage: Int {
        Int(progress * 100)
    }
    
    var statusIcon: String {
        if isCompleted { return "checkmark.circle.fill" }
        if progress > 0 { return "arrow.right.circle" }
        return "circle"
    }
    
    // MARK: - Initializer
    
    init(
        subLevelID: String,
        blockID: Int,
        orderInBlock: Int,
        title: String,
        concept: String,
        targetWordCount: Int = 30,
        isLocked: Bool = true
    ) {
        self.subLevelID = subLevelID
        self.blockID = blockID
        self.orderInBlock = orderInBlock
        self.title = title
        self.concept = concept
        self.targetWordCount = targetWordCount
        self.isLocked = isLocked
    }
}
