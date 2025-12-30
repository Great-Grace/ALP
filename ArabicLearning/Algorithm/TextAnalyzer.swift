// TextAnalyzer.swift
// Analyzes Arabic text to identify known vocabulary (Tokenization & Matching)

import Foundation
import SwiftData

// MARK: - Analysis Result Models
struct TextToken: Identifiable, Hashable {
    let id = UUID()
    let text: String           // The actual text segment (word or punctuation)
    let cleanText: String      // Diacritic-free version for matching
    let isWord: Bool           // True if it's a word, False if punctuation/whitespace
    
    // Analysis Result
    var matchedWordId: UUID?   // ID of the matching Word in DB (if any)
    var status: LearningStatus? // The status of the matched word
}

// MARK: - Text Analyzer Service
final class TextAnalyzer {
    static let shared = TextAnalyzer()
    private init() {}
    
    /// Tokenizes text and matches against the database
    @MainActor
    func analyze(text: String, context: ModelContext) -> [TextToken] {
        // 1. Tokenize (Simple split by whitespace and punctuation)
        // Note: For robust Arabic tokenization, we ideally need a specialized NLP library,
        // but for now, we'll use CharacterSet separation.
        let tokens = tokenize(text)
        
        // 2. Fetch all clean words for matching (Optimization: Fetch only needed if dataset is huge)
        // For now, we fetch all words and create a map for O(1) lookup.
        // In a large DB, we would query only the visible tokens.
        let descriptor = FetchDescriptor<Word>()
        guard let allWords = try? context.fetch(descriptor) else { return tokens }
        
        // Create Dictionary: Clean Arabic -> Word
        // If there are duplicates, the latest one or "mastered" one could take precedence.
        var wordMap: [String: Word] = [:]
        for word in allWords {
            wordMap[word.arabicClean] = word
            // Also map the full form just in case
            if wordMap[word.arabic] == nil {
                wordMap[word.arabic] = word
            }
        }
        
        // 3. Match Tokens
        var analyzedTokens: [TextToken] = []
        
        for var token in tokens {
            if token.isWord {
                // Try exact match on clean text
                if let match = wordMap[token.cleanText] {
                    token.matchedWordId = match.id
                    token.status = match.status
                }
                // Fallback: Try match on raw text (if distinct)
                else if let match = wordMap[token.text] {
                    token.matchedWordId = match.id
                    token.status = match.status
                }
            }
            analyzedTokens.append(token)
        }
        
        return analyzedTokens
    }
    
    /// Splits text into tokens (Words vs Punctuation/Spaces)
    private func tokenize(_ text: String) -> [TextToken] {
        var tokens: [TextToken] = []
        var currentToken = ""
        
        // Note: For robust Arabic tokenization, specialized NLP would be ideal.
        // Simple approach: Iterate chars and split on non-word characters.
        for char in text {
            if char.isWhitespace || char.isPunctuation || char.isSymbol {
                // If we have a gathered word, push it
                if !currentToken.isEmpty {
                    tokens.append(createToken(from: currentToken, isWord: true))
                    currentToken = ""
                }
                // Push the separator as a separate token
                tokens.append(createToken(from: String(char), isWord: false))
            } else {
                currentToken.append(char)
            }
        }
        
        // Append last token
        if !currentToken.isEmpty {
            tokens.append(createToken(from: currentToken, isWord: true))
        }
        
        return tokens
    }
    
    private func createToken(from text: String, isWord: Bool) -> TextToken {
        return TextToken(
            text: text,
            cleanText: text.withoutDiacritics, // Assumes String+Diacritics.swift exists
            isWord: isWord,
            matchedWordId: nil,
            status: nil
        )
    }
}
