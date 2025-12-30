// VerbFormLoader.swift
// verb_forms_final.csv → SwiftData VerbForm 변환 (Enriched Data Support)

import Foundation
import SwiftData

struct VerbFormRow {
    // Core columns
    let root: String
    let formNumber: Int
    let pattern: String
    let nuanceBasic: String
    let arabicWord: String
    let meaningKorean: String
    let verified: Bool
    
    // Enriched columns (NEW)
    let meaningPrimary: String?
    let meaningSecondary: String?
    let nuanceKorean: String?
    let exampleSentence: String?
    let exampleSentenceMeaning: String?
}

struct VerbFormLoader {
    
    // CSV 컬럼 인덱스 (verb_forms_final.csv 기준)
    // 0: root, 1: verb_form, 2: verb_form_label, 3: pattern, 4: nuance_korean (basic),
    // 5: arabic_word, 6: meaning_korean, 7: verified
    // 8: meaning_primary, 9: meaning_secondary, 10: nuance_kr, 11: example_sentence, 12: sentence_meaning
    
    /// CSV 문자열 파싱
    static func parseCSV(_ csvString: String) -> [VerbFormRow] {
        var rows: [VerbFormRow] = []
        let lines = csvString.components(separatedBy: .newlines)
        
        for (index, line) in lines.enumerated() {
            guard index > 0 && !line.isEmpty else { continue }
            
            let columns = parseCSVLine(line)
            guard columns.count >= 8 else { continue }
            
            // Core data
            let row = VerbFormRow(
                root: columns[0].trimmingCharacters(in: .whitespaces),
                formNumber: Int(columns[1].trimmingCharacters(in: .whitespaces)) ?? 1,
                pattern: columns[3].trimmingCharacters(in: .whitespaces),
                nuanceBasic: columns[4].trimmingCharacters(in: .whitespaces),
                arabicWord: columns[5].trimmingCharacters(in: .whitespaces),
                meaningKorean: columns[6].trimmingCharacters(in: .whitespaces),
                verified: columns[7].trimmingCharacters(in: .whitespaces) == "Y",
                // Enriched data (safe access)
                meaningPrimary: safeColumn(columns, index: 8),
                meaningSecondary: safeColumn(columns, index: 9),
                nuanceKorean: safeColumn(columns, index: 10),
                exampleSentence: safeColumn(columns, index: 11),
                exampleSentenceMeaning: safeColumn(columns, index: 12)
            )
            rows.append(row)
        }
        
        return rows
    }
    
    /// 안전한 컬럼 접근 (인덱스 초과 방지)
    private static func safeColumn(_ columns: [String], index: Int) -> String? {
        guard index < columns.count else { return nil }
        let value = columns[index].trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? nil : value
    }
    
    /// 따옴표 처리 CSV 파서 (쉼표가 포함된 문장 처리)
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
    
    /// VerbForm 데이터 import
    @MainActor
    static func importVerbForms(_ csvString: String, context: ModelContext) throws -> Int {
        let rows = parseCSV(csvString)
        guard !rows.isEmpty else { return 0 }
        
        var importedCount = 0
        
        for row in rows {
            let verbForm = VerbForm(
                root: row.root,
                formNumber: row.formNumber,
                pattern: row.pattern,
                nuanceBasic: row.nuanceBasic,
                arabicWord: row.arabicWord,
                meaningKorean: row.meaningKorean,
                verified: row.verified,
                // Enriched
                meaningPrimary: row.meaningPrimary,
                meaningSecondary: row.meaningSecondary,
                nuanceKorean: row.nuanceKorean,
                exampleSentence: row.exampleSentence,
                exampleSentenceMeaning: row.exampleSentenceMeaning
            )
            context.insert(verbForm)
            importedCount += 1
        }
        
        try context.save()
        return importedCount
    }
    
    /// 검증된 VerbForm만 import
    @MainActor
    static func importVerifiedVerbForms(_ csvString: String, context: ModelContext) throws -> Int {
        let rows = parseCSV(csvString).filter { $0.verified }
        guard !rows.isEmpty else { return 0 }
        
        var importedCount = 0
        
        for row in rows {
            let verbForm = VerbForm(
                root: row.root,
                formNumber: row.formNumber,
                pattern: row.pattern,
                nuanceBasic: row.nuanceBasic,
                arabicWord: row.arabicWord,
                meaningKorean: row.meaningKorean,
                verified: true,
                // Enriched
                meaningPrimary: row.meaningPrimary,
                meaningSecondary: row.meaningSecondary,
                nuanceKorean: row.nuanceKorean,
                exampleSentence: row.exampleSentence,
                exampleSentenceMeaning: row.exampleSentenceMeaning
            )
            context.insert(verbForm)
            importedCount += 1
        }
        
        try context.save()
        return importedCount
    }
    
    /// 번들에서 로드 (verb_forms_final.csv 우선, fallback to verb_forms.csv)
    @MainActor
    static func loadFromBundle(context: ModelContext, verifiedOnly: Bool = false) throws -> Int {
        // Try enriched file first
        var url = Bundle.main.url(forResource: "verb_forms_final", withExtension: "csv")
        
        // Fallback to original
        if url == nil {
            url = Bundle.main.url(forResource: "verb_forms", withExtension: "csv")
        }
        
        guard let fileURL = url,
              let csvString = try? String(contentsOf: fileURL, encoding: .utf8) else {
            throw VerbFormLoaderError.fileNotFound
        }
        
        if verifiedOnly {
            return try importVerifiedVerbForms(csvString, context: context)
        } else {
            return try importVerbForms(csvString, context: context)
        }
    }
}

enum VerbFormLoaderError: Error {
    case fileNotFound
    case parseError
}
