// ArticleToken.swift
// Codable structure for tokenized text in Articles

import Foundation

struct ArticleToken: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    
    /// The display word (e.g., "yaktubu")
    let text: String
    
    /// Diacritic-free version for matching (e.g., "yktb")
    let cleanText: String
    
    /// Optional link to a VerbForm or Root entry (if pre-analyzed)
    let rootId: UUID?
    
    /// Is this a key vocabulary word? (vs punctuation or common particles)
    let isTargetWord: Bool
    
    /// Trailing punctuation (e.g., ".")
    let punctuation: String?
}
