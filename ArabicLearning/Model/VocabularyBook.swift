// VocabularyBook Model - SwiftData
// 단어장 (Vocabulary Book) - 최상위 계층 모델

import Foundation
import SwiftData

@Model
final class VocabularyBook {
    var id: UUID = UUID()
    var name: String = ""                    // 단어장 이름 (예: "실용 아랍어 문법")
    var descriptionText: String = ""         // 설명
    var isDefault: Bool = false              // 기본 단어장 여부
    var createdAt: Date = Date()
    
    // Relationship - 하위 챕터들
    @Relationship(deleteRule: .cascade, inverse: \Chapter.book)
    var chapters: [Chapter] = []
    
    init(
        name: String,
        descriptionText: String = "",
        isDefault: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.descriptionText = descriptionText
        self.isDefault = isDefault
        self.createdAt = Date()
    }
    
    // MARK: - Computed Properties
    
    /// 총 단어 수
    var wordCount: Int {
        chapters.reduce(0) { $0 + $1.words.count }
    }
    
    /// 정렬된 챕터 목록
    var sortedChapters: [Chapter] {
        chapters.sorted { $0.orderIndex < $1.orderIndex }
    }
}
