// CurriculumDataLoader.swift
// Loads curriculum data with level assignment

import Foundation
import SwiftData

struct CurriculumDataLoader {
    
    // MARK: - Load Levels and Words
    
    /// Loads all curriculum data (levels + words) from CSV
    @MainActor
    static func loadCurriculum(context: ModelContext, verifiedOnly: Bool = false) throws -> Int {
        // 1. Seed default levels if needed
        StudyLevel.seedLevels(context: context)
        
        // 2. Load verb forms CSV
        guard let url = Bundle.main.url(forResource: "verb_forms", withExtension: "csv"),
              let csvString = try? String(contentsOf: url, encoding: .utf8) else {
            throw CurriculumLoaderError.fileNotFound
        }
        
        // 3. Parse and import
        return try importFromCSV(csvString, context: context, verifiedOnly: verifiedOnly)
    }
    
    // MARK: - CSV Import
    
    @MainActor
    private static func importFromCSV(_ csvString: String, context: ModelContext, verifiedOnly: Bool) throws -> Int {
        let lines = csvString.components(separatedBy: .newlines)
        guard lines.count > 1 else { return 0 }
        
        // Find column indices from header
        let header = parseCSVLine(lines[0])
        let columnMap = Dictionary(uniqueKeysWithValues: header.enumerated().map { ($1, $0) })
        
        // Fetch existing levels
        let levelDescriptor = FetchDescriptor<StudyLevel>()
        let existingLevels = try context.fetch(levelDescriptor)
        var levelMap: [Int: StudyLevel] = Dictionary(uniqueKeysWithValues: existingLevels.map { ($0.levelID, $0) })
        
        var importedCount = 0
        
        for i in 1..<lines.count {
            let line = lines[i]
            guard !line.isEmpty else { continue }
            
            let columns = parseCSVLine(line)
            
            // Parse required fields
            guard let rootIdx = columnMap["root"], rootIdx < columns.count,
                  let formIdx = columnMap["verb_form"], formIdx < columns.count,
                  let wordIdx = columnMap["arabic_word"], wordIdx < columns.count else {
                continue
            }
            
            let root = columns[rootIdx].trimmingCharacters(in: .whitespaces)
            let formNumber = Int(columns[formIdx].trimmingCharacters(in: .whitespaces)) ?? 1
            let arabicWord = columns[wordIdx].trimmingCharacters(in: .whitespaces)
            
            guard !arabicWord.isEmpty else { continue }
            
            // Parse verified filter
            let verified = columnMap["verified"].flatMap { i in
                i < columns.count ? columns[i].trimmingCharacters(in: .whitespaces) == "Y" : nil
            } ?? false
            
            if verifiedOnly && !verified {
                continue
            }
            
            // Parse level - with AUTO-LEVELING strategy if all levels are 1
            // Strategy: First 100 → L1, Next 200 → L2, Next 300 → L3, etc.
            let levelID: Int = {
                // Check if CSV has a valid level column with varied values
                if let levelIdx = columnMap["level"], levelIdx < columns.count {
                    let levelStr = columns[levelIdx].trimmingCharacters(in: .whitespaces)
                    let csvLevel = Int(levelStr) ?? 1
                    
                    // If CSV level is explicitly set (not all 1s), use it
                    if csvLevel > 1 {
                        return csvLevel
                    }
                }
                
                // AUTO-LEVELING: Distribute based on row index
                return calculateAutoLevel(for: importedCount)
            }()
            
            // Get or create level
            let level: StudyLevel
            if let existingLevel = levelMap[levelID] {
                level = existingLevel
            } else {
                level = StudyLevel(
                    levelID: levelID,
                    title: "레벨 \(levelID)",
                    description: "",
                    isLocked: levelID > 1
                )
                context.insert(level)
                levelMap[levelID] = level
            }
            
            // Parse optional fields
            let pattern = columnMap["pattern"].flatMap { i in
                i < columns.count ? columns[i].trimmingCharacters(in: .whitespaces) : nil
            } ?? ""
            
            let nuanceBasic = columnMap["nuance_korean"].flatMap { i in
                i < columns.count ? columns[i].trimmingCharacters(in: .whitespaces) : nil
            } ?? ""
            
            let meaningKorean = columnMap["meaning_korean"].flatMap { i in
                i < columns.count ? columns[i].trimmingCharacters(in: .whitespaces) : nil
            } ?? ""
            
            // Enriched fields
            let meaningPrimary = columnMap["meaning_primary"].flatMap { i in
                i < columns.count ? columns[i].trimmingCharacters(in: .whitespaces) : nil
            }
            
            let meaningSecondary = columnMap["meaning_secondary"].flatMap { i in
                i < columns.count ? columns[i].trimmingCharacters(in: .whitespaces) : nil
            }
            
            let nuanceKorean = columnMap["nuance_kr"].flatMap { i in
                i < columns.count ? columns[i].trimmingCharacters(in: .whitespaces) : nil
            }
            
            let exampleSentence = columnMap["example_sentence"].flatMap { i in
                i < columns.count ? columns[i].trimmingCharacters(in: .whitespaces) : nil
            }
            
            let sentenceMeaning = columnMap["sentence_meaning"].flatMap { i in
                i < columns.count ? columns[i].trimmingCharacters(in: .whitespaces) : nil
            }
            
            // Create VerbForm
            let verbForm = VerbForm(
                root: root,
                formNumber: formNumber,
                pattern: pattern,
                nuanceBasic: nuanceBasic,
                arabicWord: arabicWord,
                meaningKorean: meaningKorean,
                verified: verified,
                meaningPrimary: meaningPrimary,
                meaningSecondary: meaningSecondary,
                nuanceKorean: nuanceKorean,
                exampleSentence: exampleSentence,
                exampleSentenceMeaning: sentenceMeaning
            )
            context.insert(verbForm)
            
            // Create Word for curriculum
            let word = Word(
                arabic: arabicWord,
                korean: meaningPrimary ?? meaningKorean,
                exampleSentence: exampleSentence ?? "",
                sentenceKorean: sentenceMeaning ?? ""
            )
            word.levelID = levelID
            word.level = level
            word.root = root
            word.pattern = pattern
            word.verbForm = formNumber
            word.nuanceKorean = nuanceKorean
            
            context.insert(word)
            importedCount += 1
        }
        
        try context.save()
        return importedCount
    }
    
    // MARK: - CSV Parser (Quote-aware)
    
    private static func parseCSVLine(_ line: String) -> [String] {
        var columns: [String] = []
        var current = ""
        var inQuotes = false
        
        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                columns.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        columns.append(current)
        
        return columns
    }
    
    // MARK: - Auto-Leveling Strategy
    
    /// Calculates level based on word index using progressive distribution
    /// Level 1: 0-99 (100 words)
    /// Level 2: 100-299 (200 words)
    /// Level 3: 300-599 (300 words)
    /// Level 4: 600-999 (400 words)
    /// Level 5: 1000+ (remaining)
    private static func calculateAutoLevel(for index: Int) -> Int {
        switch index {
        case 0..<100:
            return 1  // First 100 words (beginner)
        case 100..<300:
            return 2  // Next 200 words
        case 300..<600:
            return 3  // Next 300 words
        case 600..<1000:
            return 4  // Next 400 words
        default:
            return 5  // Remaining (advanced)
        }
    }
}

// MARK: - Error Types

enum CurriculumLoaderError: Error {
    case fileNotFound
    case parseError
}
