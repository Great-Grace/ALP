// CSVDataLoader - CSV → SwiftData 변환
// Morphology-Based Spiral Curriculum 지원

import Foundation
import SwiftData

// MARK: - CSV Row (Morphology Extended)
struct CSVWordRow {
    let chapter: String
    let arabic: String
    let korean: String
    let exampleSentence: String
    let sentenceKorean: String
    
    // Morphology fields
    let root: String?
    let pattern: String?
    let verbForm: Int?
    let complexityLevel: Int
    let morphologyType: String?
}

// MARK: - CSV Data Loader
struct CSVDataLoader {
    
    /// CSV 문자열을 파싱하여 WordRow 배열로 반환
    /// 지원 형식: 5컬럼 (기본) 또는 10컬럼 (형태론)
    static func parseCSV(_ csvString: String) -> [CSVWordRow] {
        var rows: [CSVWordRow] = []
        let lines = csvString.components(separatedBy: .newlines)
        
        // 헤더 분석
        guard let headerLine = lines.first else { return [] }
        let headers = headerLine.components(separatedBy: ",")
        let hasMorphology = headers.count >= 10
        
        // 데이터 파싱
        for (index, line) in lines.enumerated() {
            guard index > 0 && !line.isEmpty else { continue }
            
            let columns = parseCSVLine(line)
            guard columns.count >= 5 else { continue }
            
            let row: CSVWordRow
            
            if hasMorphology && columns.count >= 10 {
                // 10-column morphology format
                row = CSVWordRow(
                    chapter: columns[0].trimmingCharacters(in: .whitespaces),
                    arabic: columns[1].trimmingCharacters(in: .whitespaces),
                    korean: columns[2].trimmingCharacters(in: .whitespaces),
                    exampleSentence: columns[3].trimmingCharacters(in: .whitespaces),
                    sentenceKorean: columns[4].trimmingCharacters(in: .whitespaces),
                    root: columns[5].isEmpty ? nil : columns[5].trimmingCharacters(in: .whitespaces),
                    pattern: columns[6].isEmpty ? nil : columns[6].trimmingCharacters(in: .whitespaces),
                    verbForm: Int(columns[7].trimmingCharacters(in: .whitespaces)),
                    complexityLevel: Int(columns[8].trimmingCharacters(in: .whitespaces)) ?? 1,
                    morphologyType: columns[9].isEmpty ? nil : columns[9].trimmingCharacters(in: .whitespaces)
                )
            } else {
                // 5-column legacy format
                row = CSVWordRow(
                    chapter: columns[0].trimmingCharacters(in: .whitespaces),
                    arabic: columns[1].trimmingCharacters(in: .whitespaces),
                    korean: columns[2].trimmingCharacters(in: .whitespaces),
                    exampleSentence: columns[3].trimmingCharacters(in: .whitespaces),
                    sentenceKorean: columns[4].trimmingCharacters(in: .whitespaces),
                    root: nil,
                    pattern: nil,
                    verbForm: nil,
                    complexityLevel: 1,
                    morphologyType: nil
                )
            }
            rows.append(row)
        }
        
        return rows
    }
    
    /// 쉼표가 포함된 필드 처리 (따옴표 지원)
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
    
    /// CSV를 새 VocabularyBook으로 가져오기
    @MainActor
    static func importCSVAsBook(_ csvString: String, bookName: String, context: ModelContext) throws -> Int {
        let rows = parseCSV(csvString)
        guard !rows.isEmpty else { return 0 }
        
        let book = VocabularyBook(name: bookName)
        context.insert(book)
        
        var chapterCache: [String: Chapter] = [:]
        var orderIndex = 1
        var importedCount = 0
        
        for row in rows {
            // 챕터 조회 또는 생성
            let chapter: Chapter
            if let cached = chapterCache[row.chapter] {
                chapter = cached
            } else {
                let existingChapter = book.chapters.first { $0.name == row.chapter }
                if let existing = existingChapter {
                    chapter = existing
                } else {
                    chapter = Chapter(
                        name: row.chapter,
                        orderIndex: orderIndex,
                        book: book
                    )
                    context.insert(chapter)
                    orderIndex += 1
                }
                chapterCache[row.chapter] = chapter
            }
            
            // 단어 생성 (형태론 필드 포함)
            let word = Word(
                arabic: row.arabic,
                korean: row.korean,
                exampleSentence: row.exampleSentence,
                sentenceKorean: row.sentenceKorean,
                chapter: chapter
            )
            
            // 형태론 필드 적용
            word.root = row.root
            word.pattern = row.pattern
            word.verbForm = row.verbForm
            word.complexityLevel = row.complexityLevel
            if let typeStr = row.morphologyType {
                word.morphologyType = MorphologyType(rawValue: typeStr)
            }
            
            context.insert(word)
            importedCount += 1
        }
        
        try context.save()
        return importedCount
    }
    
    /// 기존 호환 import
    @MainActor
    static func importCSV(_ csvString: String, context: ModelContext) throws -> Int {
        return try importCSVAsBook(csvString, bookName: "가져온 단어", context: context)
    }
    
    /// 번들 샘플 데이터 로드
    @MainActor
    static func loadSampleData(context: ModelContext) throws -> Int {
        guard let url = Bundle.main.url(forResource: "sample_words", withExtension: "csv"),
              let csvString = try? String(contentsOf: url, encoding: .utf8) else {
            throw CSVLoaderError.fileNotFound
        }
        
        return try importCSV(csvString, context: context)
    }
}

enum CSVLoaderError: Error {
    case fileNotFound
    case parseError
}
