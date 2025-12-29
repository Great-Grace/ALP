// VerbFormLoader.swift
// verb_forms.csv → SwiftData VerbForm 변환

import Foundation
import SwiftData

struct VerbFormRow {
    let root: String
    let formNumber: Int
    let formLabel: String
    let pattern: String
    let nuanceKorean: String
    let arabicWord: String
    let meaningKorean: String
    let verified: Bool
}

struct VerbFormLoader {
    
    /// CSV 문자열 파싱
    static func parseCSV(_ csvString: String) -> [VerbFormRow] {
        var rows: [VerbFormRow] = []
        let lines = csvString.components(separatedBy: .newlines)
        
        for (index, line) in lines.enumerated() {
            guard index > 0 && !line.isEmpty else { continue }
            
            let columns = parseCSVLine(line)
            guard columns.count >= 8 else { continue }
            
            let row = VerbFormRow(
                root: columns[0].trimmingCharacters(in: .whitespaces),
                formNumber: Int(columns[1].trimmingCharacters(in: .whitespaces)) ?? 1,
                formLabel: columns[2].trimmingCharacters(in: .whitespaces),
                pattern: columns[3].trimmingCharacters(in: .whitespaces),
                nuanceKorean: columns[4].trimmingCharacters(in: .whitespaces),
                arabicWord: columns[5].trimmingCharacters(in: .whitespaces),
                meaningKorean: columns[6].trimmingCharacters(in: .whitespaces),
                verified: columns[7].trimmingCharacters(in: .whitespaces) == "Y"
            )
            rows.append(row)
        }
        
        return rows
    }
    
    /// 따옴표 처리 파서
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
            // 검증된 항목만 import (또는 모든 항목)
            let verbForm = VerbForm(
                root: row.root,
                formNumber: row.formNumber,
                formLabel: row.formLabel,
                pattern: row.pattern,
                nuanceKorean: row.nuanceKorean,
                arabicWord: row.arabicWord,
                meaningKorean: row.meaningKorean,
                verified: row.verified
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
                formLabel: row.formLabel,
                pattern: row.pattern,
                nuanceKorean: row.nuanceKorean,
                arabicWord: row.arabicWord,
                meaningKorean: row.meaningKorean,
                verified: true
            )
            context.insert(verbForm)
            importedCount += 1
        }
        
        try context.save()
        return importedCount
    }
    
    /// 번들에서 로드
    @MainActor
    static func loadFromBundle(context: ModelContext, verifiedOnly: Bool = true) throws -> Int {
        guard let url = Bundle.main.url(forResource: "verb_forms", withExtension: "csv"),
              let csvString = try? String(contentsOf: url, encoding: .utf8) else {
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
