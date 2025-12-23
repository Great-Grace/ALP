// CSVDataLoader - CSV → SwiftData 변환
// Python 프로토타입의 data_loader.py 로직 이식

import Foundation
import SwiftData

struct CSVWordRow {
    let chapter: String
    let arabic: String
    let pronunciation: String
    let korean: String
    let exampleSentence: String
    let sentenceKorean: String
}

// actor 대신 struct로 변경 (static 함수 사용을 위해)
struct CSVDataLoader {
    
    /// CSV 문자열을 파싱하여 WordRow 배열로 반환
    static func parseCSV(_ csvString: String) -> [CSVWordRow] {
        var rows: [CSVWordRow] = []
        let lines = csvString.components(separatedBy: .newlines)
        
        // 첫 줄은 헤더, 스킵
        for (index, line) in lines.enumerated() {
            guard index > 0 && !line.isEmpty else { continue }
            
            let columns = line.components(separatedBy: ",")
            guard columns.count >= 6 else { continue }
            
            let row = CSVWordRow(
                chapter: columns[0].trimmingCharacters(in: .whitespaces),
                arabic: columns[1].trimmingCharacters(in: .whitespaces),
                pronunciation: columns[2].trimmingCharacters(in: .whitespaces),
                korean: columns[3].trimmingCharacters(in: .whitespaces),
                exampleSentence: columns[4].trimmingCharacters(in: .whitespaces),
                sentenceKorean: columns[5].trimmingCharacters(in: .whitespaces)
            )
            rows.append(row)
        }
        
        return rows
    }
    
    /// CSV Row를 SwiftData 모델로 변환 및 저장 (기존 호환)
    @MainActor
    static func importCSV(_ csvString: String, context: ModelContext) throws -> Int {
        return try importCSVAsBook(csvString, bookName: "가져온 단어", context: context)
    }
    
    /// CSV를 새 VocabularyBook으로 가져오기
    @MainActor
    static func importCSVAsBook(_ csvString: String, bookName: String, context: ModelContext) throws -> Int {
        let rows = parseCSV(csvString)
        guard !rows.isEmpty else { return 0 }
        
        // 새 단어장 생성
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
                // 기존 챕터 검색 - 같은 Book 내에서만
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
            
            // 단어 생성
            let word = Word(
                arabic: row.arabic,
                pronunciation: row.pronunciation,
                korean: row.korean,
                exampleSentence: row.exampleSentence,
                sentenceKorean: row.sentenceKorean,
                chapter: chapter
            )
            context.insert(word)
            importedCount += 1
        }
        
        try context.save()
        return importedCount
    }
    
    /// 번들에 포함된 샘플 CSV 로드
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
