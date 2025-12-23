// Word Model - SwiftData
// 아랍어 단어 정보 (Cloze Test 지원)

import Foundation
import SwiftData

@Model
final class Word {
    var id: UUID = UUID()
    var arabic: String = ""             // 아랍어 단어 (정답)
    var pronunciation: String = ""      // 발음 (한글)
    var korean: String = ""             // 한국어 뜻
    var exampleSentence: String = ""    // 완전한 아랍어 예문
    var sentenceKorean: String = ""     // 예문의 한국어 해석
    var sentenceWithBlank: String = ""  // 빈칸 처리된 예문
    var createdAt: Date = Date()
    
    // Relationship - 소속 챕터
    var chapter: Chapter?
    
    // Relationship - 퀴즈 기록
    @Relationship(deleteRule: .cascade, inverse: \QuizHistory.word)
    var quizHistory: [QuizHistory] = []
    
    init(
        arabic: String,
        pronunciation: String,
        korean: String,
        exampleSentence: String,
        sentenceKorean: String,
        sentenceWithBlank: String? = nil,
        chapter: Chapter? = nil
    ) {
        self.id = UUID()
        self.arabic = arabic
        self.pronunciation = pronunciation
        self.korean = korean
        self.exampleSentence = exampleSentence
        self.sentenceKorean = sentenceKorean
        // 빈칸 자동 생성
        self.sentenceWithBlank = sentenceWithBlank ?? exampleSentence.replacingOccurrences(of: arabic, with: "(______)")
        self.createdAt = Date()
        self.chapter = chapter
    }
}
