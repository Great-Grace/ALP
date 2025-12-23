// QuizHistory Model - SwiftData
// 퀴즈 결과 기록

import Foundation
import SwiftData

@Model
final class QuizHistory {
    var id: UUID = UUID()
    var quizType: String = ""           // "choice" / "typing"
    var isCorrect: Bool = false
    var userAnswer: String = ""
    var answeredAt: Date = Date()
    
    // Relationship - 단방향
    var word: Word?
    
    init(quizType: String, isCorrect: Bool, userAnswer: String, word: Word? = nil) {
        self.id = UUID()
        self.quizType = quizType
        self.isCorrect = isCorrect
        self.userAnswer = userAnswer
        self.answeredAt = Date()
        self.word = word
    }
}
