// VocabularyService.swift
// Service for adding words from Reader to Vocabulary

import Foundation
import SwiftData

final class VocabularyService {
    
    // MARK: - Context Capture Algorithm
    
    /// Extracts the surrounding sentence from article tokens given the selected token index
    static func extractContextSentence(from tokens: [ArticleToken], selectedIndex: Int) -> String {
        guard selectedIndex >= 0 && selectedIndex < tokens.count else { return "" }
        
        let endingPunctuation: Set<Character> = [".", "?", "!", "؟", "。"]
        
        // Scan backwards to find sentence start
        var startIndex = selectedIndex
        for i in stride(from: selectedIndex - 1, through: 0, by: -1) {
            let token = tokens[i]
            if let punc = token.punctuation, let char = punc.last, endingPunctuation.contains(char) {
                // Previous token ends with punctuation -> current is start of sentence
                startIndex = i + 1
                break
            }
            startIndex = i
        }
        
        // Scan forwards to find sentence end
        var endIndex = selectedIndex
        for i in selectedIndex..<tokens.count {
            let token = tokens[i]
            endIndex = i
            if let punc = token.punctuation, let char = punc.last, endingPunctuation.contains(char) {
                // Found end of sentence
                break
            }
        }
        
        // Combine tokens to form sentence
        let sentenceTokens = tokens[startIndex...endIndex]
        let sentence = sentenceTokens.map { $0.text + ($0.punctuation ?? "") }.joined(separator: " ")
        
        return sentence.trimmingCharacters(in: .whitespaces)
    }
    
    // MARK: - Add to Vocabulary
    
    /// Result of attempting to add a word
    enum AddResult {
        case added(Word)
        case alreadyExists(Word)
        case failed(Error)
    }
    
    /// Adds a word to vocabulary from Reader context
    @MainActor
    static func addToVocabulary(
        token: ArticleToken,
        verbForm: VerbForm?,
        article: Article,
        tokenIndex: Int,
        context: ModelContext
    ) -> AddResult {
        
        // 1. Check if word already exists
        let cleanText = token.cleanText
        let existingDescriptor = FetchDescriptor<Word>(
            predicate: #Predicate { $0.arabicClean == cleanText }
        )
        
        if let existing = try? context.fetch(existingDescriptor).first {
            // Word already exists
            return .alreadyExists(existing)
        }
        
        // 2. Extract context sentence
        let exampleSentence = extractContextSentence(from: article.tokens, selectedIndex: tokenIndex)
        
        // 3. Prepare data
        let arabic = token.text
        let korean = verbForm?.meaningKorean ?? "뜻 입력 필요"
        let sentenceKorean = "" // User can add later
        
        // 4. Create Word
        let newWord = Word(
            arabic: arabic,
            korean: korean,
            exampleSentence: exampleSentence,
            sentenceKorean: sentenceKorean,
            sentenceWithBlank: nil,
            chapter: nil
        )
        
        // 5. Populate morphology fields from VerbForm if available
        if let vf = verbForm {
            newWord.root = vf.root
            newWord.pattern = vf.pattern
            newWord.verbForm = vf.formNumber
            newWord.complexityLevel = vf.formNumber // Use form number as complexity proxy
        }
        
        // 6. Set initial learning status
        newWord.statusRaw = LearningStatus.learning.rawValue
        
        // 7. Link to article
        newWord.articles = [article]
        
        // 8. Insert and save
        context.insert(newWord)
        
        do {
            try context.save()
            return .added(newWord)
        } catch {
            return .failed(error)
        }
    }
    
    /// Find the index of a token in the article's token array
    static func findTokenIndex(token: ArticleToken, in tokens: [ArticleToken]) -> Int {
        return tokens.firstIndex(where: { $0.id == token.id }) ?? 0
    }
}
