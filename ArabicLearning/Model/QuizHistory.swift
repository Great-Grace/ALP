// QuizHistory Model - SwiftData
// 퀴즈 결과 기록

import Foundation
import SwiftData

@Model
final class QuizHistory {
    var id: UUID = UUID()
    var quizType: String = ""           // "choice" / "typing"
    var quizMode: String = "general"    // "general" (범용) / "expert" (숙련자) [New]
    var isCorrect: Bool = false
    var userAnswer: String = ""
    var answeredAt: Date = Date()
    
    // Relationship - 단방향
    var word: Word?
    
    init(quizType: String, quizMode: String = "general", isCorrect: Bool, userAnswer: String, word: Word? = nil) {
        self.id = UUID()
        self.quizType = quizType
        self.quizMode = quizMode
        self.isCorrect = isCorrect
        self.userAnswer = userAnswer
        self.answeredAt = Date()
        self.word = word
    }
}

enum QuizMode: String, CaseIterable, Identifiable {
    case general = "general" // 범용 (모음 표시)
    case expert = "expert"   // 숙련자 (모음 없음)
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .general: return "General"
        case .expert: return "Expert"
        }
    }
}
