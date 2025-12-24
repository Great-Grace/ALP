// CSVDataExporter.swift
// 데이터베이스 전체 내용을 CSV로 내보내기 (검증용)

import Foundation

struct CSVDataExporter {
    
    /// Word 배열을 CSV 문자열로 변환 (모든 필드 포함)
    static func generateFullCSV(from words: [Word]) -> String {
        var csv = "chapter,arabic,arabic_clean,korean,example_sentence,sentence_clean,sentence_korean\n"
        
        for word in words {
            let row = [
                word.chapter?.name ?? "Unknown",
                escapeCSV(word.arabic),
                escapeCSV(word.arabicClean),
                escapeCSV(word.korean),
                escapeCSV(word.exampleSentence),
                escapeCSV(word.sentenceClean),
                escapeCSV(word.sentenceKorean)
            ]
            csv.append(row.joined(separator: ",") + "\n")
        }
        
        return csv
    }
    
    // CSV 특수문자 처리 (따옴표, 쉼표 등)
    private static func escapeCSV(_ text: String) -> String {
        var escaped = text
        if text.contains(",") || text.contains("\"") || text.contains("\n") {
            escaped = escaped.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return text
    }
}
