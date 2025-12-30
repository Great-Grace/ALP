// ReadingPassage.swift
// Arabic reading passages associated with study levels

import Foundation
import SwiftData

@Model
final class ReadingPassage {
    
    // MARK: - Core Properties
    
    var id: UUID = UUID()
    
    /// Passage title
    var title: String = ""
    
    /// Arabic text content
    var content: String = ""
    
    /// Korean translation
    var translation: String?
    
    /// Level this passage belongs to
    var levelID: Int = 1
    
    /// Difficulty rating (1-5)
    var difficulty: Int = 1
    
    /// Word count
    var wordCount: Int = 0
    
    // MARK: - Relationships
    
    var level: StudyLevel?
    
    // MARK: - Computed Properties
    
    /// Preview text (first 100 characters)
    var preview: String {
        if content.count > 100 {
            return String(content.prefix(100)) + "..."
        }
        return content
    }
    
    // MARK: - Init
    
    init(
        title: String,
        content: String,
        translation: String? = nil,
        levelID: Int = 1,
        difficulty: Int = 1
    ) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.translation = translation
        self.levelID = levelID
        self.difficulty = difficulty
        self.wordCount = content.split(separator: " ").count
    }
}
