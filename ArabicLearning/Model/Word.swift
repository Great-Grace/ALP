// Word Model - SwiftData
// 아랍어 단어 정보 (Cloze Test 지원)

import Foundation
import SwiftData

@Model
final class Word {
    var id: UUID = UUID()
    var arabic: String = ""             // 아랍어 단어 (정답)
    var korean: String = ""             // 한국어 뜻
    var exampleSentence: String = ""    // 완전한 아랍어 예문
    var sentenceKorean: String = ""     // 예문의 한국어 해석
    var sentenceWithBlank: String = ""  // 빈칸 처리된 예문

    
    // [New] Dual Storage - 최적화를 위한 모음 제거 버전 (검색/정답판별/숙련자모드용)
    var arabicClean: String = ""        // 모음 없는 단어 (예: بيت)
    var sentenceClean: String = ""      // 모음 없는 예문 (예: هذا بيت جميل)
    
    var createdAt: Date = Date()
    
    // Relationship - 소속 챕터
    var chapter: Chapter?
    
    // Relationship - 퀴즈 기록
    @Relationship(deleteRule: .cascade, inverse: \QuizHistory.word)
    var quizHistory: [QuizHistory] = []
    
    init(
        arabic: String,
        // pronunciation: String, // [Deleted]
        korean: String,
        exampleSentence: String,
        sentenceKorean: String,
        sentenceWithBlank: String? = nil,
        chapter: Chapter? = nil
    ) {
        self.id = UUID()
        self.arabic = arabic
        // self.pronunciation = pronunciation // [Deleted]
        self.korean = korean
        self.exampleSentence = exampleSentence
        self.sentenceKorean = sentenceKorean
        
        // [New] 모음 제거 버전 자동 생성
        self.arabicClean = arabic.withoutDiacritics
        self.sentenceClean = exampleSentence.withoutDiacritics
        
        // 빈칸 자동 생성 (참고: 빈칸 생성 시에도 원본(모음포함)을 사용하거나 필요시 clean 사용 고려 가능. 현재는 원본 유지)
        self.sentenceWithBlank = sentenceWithBlank ?? exampleSentence.replacingOccurrences(of: arabic, with: "(______)")
        self.createdAt = Date()
        self.chapter = chapter
    }
}
