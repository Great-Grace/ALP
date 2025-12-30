// Article.swift
// Reading Material Model - SwiftData with Structured Token Storage

import Foundation
import SwiftData

@Model
final class Article {
    var id: UUID = UUID()
    var title: String = ""
    var difficultyLevel: Int = 1      // 1=Novice, 2=Intermediate, 3=Advanced
    var contentJSON: Data = Data()    // Stores [ArticleToken] as JSON
    var isRead: Bool = false
    var addedAt: Date = Date()
    
    // Metadata
    var source: String?
    
    // Relationships
    @Relationship(inverse: \Word.articles)
    var words: [Word] = []
    
    init(
        title: String,
        tokens: [ArticleToken],
        difficultyLevel: Int = 1,
        source: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.difficultyLevel = difficultyLevel
        self.source = source
        self.addedAt = Date()
        self.isRead = false
        
        // Encode tokens to JSON
        if let data = try? JSONEncoder().encode(tokens) {
            self.contentJSON = data
        }
    }
    
    // Helper to access tokens
    var tokens: [ArticleToken] {
        get {
            guard !contentJSON.isEmpty else { return [] }
            return (try? JSONDecoder().decode([ArticleToken].self, from: contentJSON)) ?? []
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                contentJSON = data
            }
        }
    }
    
    /// Convenience: Returns all token text as a single string (for preview)
    var content: String {
        return tokens.map { $0.text + ($0.punctuation ?? "") }.joined(separator: " ")
    }
}
