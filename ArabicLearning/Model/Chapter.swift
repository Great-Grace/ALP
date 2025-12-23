// Chapter Model - SwiftData
// 챕터/단원 정보 (VocabularyBook에 소속)

import Foundation
import SwiftData

@Model
final class Chapter {
    var id: UUID = UUID()
    var name: String = ""                    // 챕터 이름 (예: "1장", "2장")
    var descriptionText: String = ""         // 설명
    var orderIndex: Int = 0                  // 정렬 순서 (1, 2, 3...)
    var createdAt: Date = Date()
    
    // Relationship - 소속 단어장
    var book: VocabularyBook?
    
    // Relationship - 하위 단어들
    @Relationship(deleteRule: .cascade, inverse: \Word.chapter)
    var words: [Word] = []
    
    init(
        name: String,
        descriptionText: String = "",
        orderIndex: Int = 0,
        book: VocabularyBook? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.descriptionText = descriptionText
        self.orderIndex = orderIndex
        self.createdAt = Date()
        self.book = book
    }
    
    // MARK: - Computed Properties
    
    /// 정렬된 단어 목록
    var sortedWords: [Word] {
        words.sorted { $0.createdAt < $1.createdAt }
    }
}
