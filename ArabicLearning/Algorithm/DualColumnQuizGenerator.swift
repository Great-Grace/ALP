// DualColumnQuizGenerator.swift
// Dual-Column Selection Quiz for Arabic Morphology
// 언어 정책: 아랍어(어근/패턴/단어) + 한국어(형태/뉘앙스)

import Foundation
import SwiftData

// MARK: - Quiz Types
enum DualColumnQuizType: String, Codable {
    case patternRecognition = "TYPE_1_PATTERN"      // 패턴 → 형태 + 뉘앙스
    case wordDeconstruction = "TYPE_2_DECONSTRUCTION" // 단어 → 형태 + 어근
    case constructiveSynthesis = "TYPE_3_SYNTHESIS"   // 어근+뉘앙스 → 형태 + 결과단어
}

// MARK: - Quiz Option
struct QuizOption: Codable, Identifiable {
    let id: String
    let text: String
}

// MARK: - Column Selector
struct ColumnSelector: Codable {
    let label: String          // "형태(Form)", "어근(Root)"
    let options: [QuizOption]
}

// MARK: - Display Card
struct DisplayCard: Codable {
    let mainText: String      // 아랍어 단어/패턴
    let subText: String?      // 힌트 (Type 3에서 한국어 뉘앙스)
}

// MARK: - Dual Column Quiz Item
struct DualColumnQuizItem: Codable, Identifiable {
    let id: String
    let type: DualColumnQuizType
    let displayCard: DisplayCard
    let leftColumn: ColumnSelector    // Column A
    let rightColumn: ColumnSelector   // Column B
    let correctPair: (String, String) // (left answer id, right answer id)
    
    var quizId: String { id }
    
    // Codable for tuple
    enum CodingKeys: String, CodingKey {
        case id, type, displayCard, leftColumn, rightColumn, correctLeftId, correctRightId
    }
    
    init(id: String, type: DualColumnQuizType, displayCard: DisplayCard, 
         leftColumn: ColumnSelector, rightColumn: ColumnSelector, correctPair: (String, String)) {
        self.id = id
        self.type = type
        self.displayCard = displayCard
        self.leftColumn = leftColumn
        self.rightColumn = rightColumn
        self.correctPair = correctPair
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        type = try container.decode(DualColumnQuizType.self, forKey: .type)
        displayCard = try container.decode(DisplayCard.self, forKey: .displayCard)
        leftColumn = try container.decode(ColumnSelector.self, forKey: .leftColumn)
        rightColumn = try container.decode(ColumnSelector.self, forKey: .rightColumn)
        let leftId = try container.decode(String.self, forKey: .correctLeftId)
        let rightId = try container.decode(String.self, forKey: .correctRightId)
        correctPair = (leftId, rightId)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(displayCard, forKey: .displayCard)
        try container.encode(leftColumn, forKey: .leftColumn)
        try container.encode(rightColumn, forKey: .rightColumn)
        try container.encode(correctPair.0, forKey: .correctLeftId)
        try container.encode(correctPair.1, forKey: .correctRightId)
    }
}

// MARK: - Verb Form Nuances (Korean)
struct VerbFormData {
    static let nuances: [Int: String] = [
        1: "기본형",
        2: "사동/강조",
        3: "상호동작",
        4: "사역형",
        5: "재귀(2형)",
        6: "상호재귀",
        7: "수동형",
        8: "재귀/중간태",
        9: "색상/결함",
        10: "신청/요구"
    ]
    
    static let patterns: [Int: String] = [
        1: "فَعَلَ",
        2: "فَعَّلَ",
        3: "فَاعَلَ",
        4: "أَفْعَلَ",
        5: "تَفَعَّلَ",
        6: "تَفَاعَلَ",
        7: "اِنْفَعَلَ",
        8: "اِفْتَعَلَ",
        9: "اِفْعَلَّ",
        10: "اِسْتَفْعَلَ"
    ]
}

// MARK: - Dual Column Quiz Generator
final class DualColumnQuizGenerator {
    static let shared = DualColumnQuizGenerator()
    private init() {}
    
    // MARK: - Generate Type 1: Pattern Recognition
    /// 입력: 패턴 (فَعَّلَ) → 형태 선택 + 뉘앙스 선택
    func generatePatternRecognition(targetForm: Int, allForms: [Int] = Array(1...10)) -> DualColumnQuizItem {
        let pattern = VerbFormData.patterns[targetForm] ?? "فَعَلَ"
        let nuance = VerbFormData.nuances[targetForm] ?? "기본형"
        
        // Left Column: 형태 선택
        var formOptions = allForms.filter { $0 != targetForm }.shuffled().prefix(3).map { $0 }
        formOptions.append(targetForm)
        formOptions.shuffle()
        
        let leftOptions = formOptions.map { form in
            QuizOption(id: "f\(form)", text: "\(form)형")
        }
        
        // Right Column: 뉘앙스 선택
        var nuanceOptions = VerbFormData.nuances.filter { $0.key != targetForm }
            .shuffled().prefix(3).map { ($0.key, $0.value) }
        nuanceOptions.append((targetForm, nuance))
        nuanceOptions.shuffle()
        
        let rightOptions = nuanceOptions.map { (form, nuanceText) in
            QuizOption(id: "n\(form)", text: nuanceText)
        }
        
        return DualColumnQuizItem(
            id: "q_\(UUID().uuidString.prefix(8))",
            type: .patternRecognition,
            displayCard: DisplayCard(mainText: pattern, subText: nil),
            leftColumn: ColumnSelector(label: "형태", options: leftOptions),
            rightColumn: ColumnSelector(label: "뉘앙스", options: rightOptions),
            correctPair: ("f\(targetForm)", "n\(targetForm)")
        )
    }
    
    // MARK: - Generate Type 2: Word Deconstruction
    /// 입력: 동사 (تَأَكَّلَ) → 형태 선택 + 어근 선택
    func generateWordDeconstruction(word: Word, allWords: [Word]) -> DualColumnQuizItem? {
        guard let verbForm = word.verbForm, let root = word.root else { return nil }
        
        // Left Column: 형태 선택
        var formOptions = [2, 4, 5, 6].filter { $0 != verbForm }.shuffled().prefix(3).map { $0 }
        formOptions.append(verbForm)
        formOptions.shuffle()
        
        let leftOptions = formOptions.map { form in
            QuizOption(id: "f\(form)", text: "\(form)형")
        }
        
        // Right Column: 어근 선택 (다른 단어들의 어근으로 distractors)
        var rootOptions = allWords
            .compactMap { $0.root }
            .filter { $0 != root }
            .shuffled()
            .prefix(3)
            .map { $0 }
        rootOptions.append(root)
        rootOptions.shuffle()
        
        let rightOptions = rootOptions.enumerated().map { (index, rootText) in
            QuizOption(id: "r\(index)", text: rootText)
        }
        
        let correctRootIndex = rootOptions.firstIndex(of: root) ?? 0
        
        return DualColumnQuizItem(
            id: "q_\(UUID().uuidString.prefix(8))",
            type: .wordDeconstruction,
            displayCard: DisplayCard(mainText: word.arabic, subText: nil),
            leftColumn: ColumnSelector(label: "형태", options: leftOptions),
            rightColumn: ColumnSelector(label: "어근", options: rightOptions),
            correctPair: ("f\(verbForm)", "r\(correctRootIndex)")
        )
    }
    
    // MARK: - Generate Type 3: Constructive Synthesis
    /// 입력: 어근 + 뉘앙스 → 형태 선택 + 결과 단어 선택
    func generateConstructiveSynthesis(targetWord: Word, relatedWords: [Word]) -> DualColumnQuizItem? {
        guard let verbForm = targetWord.verbForm,
              let root = targetWord.root else { return nil }
        
        let nuance = VerbFormData.nuances[verbForm] ?? "기본형"
        
        // Left Column: 형태 선택
        var formOptions = [1, 3, 6, 8].filter { $0 != verbForm }.shuffled().prefix(3).map { $0 }
        formOptions.append(verbForm)
        formOptions.shuffle()
        
        let leftOptions = formOptions.map { form in
            QuizOption(id: "f\(form)", text: "\(form)형")
        }
        
        // Right Column: 결과 단어 선택
        var wordOptions = relatedWords
            .filter { $0.id != targetWord.id }
            .shuffled()
            .prefix(3)
            .map { $0.arabic }
        wordOptions.append(targetWord.arabic)
        wordOptions.shuffle()
        
        let rightOptions = wordOptions.enumerated().map { (index, arabicWord) in
            QuizOption(id: "w\(index)", text: arabicWord)
        }
        
        let correctWordIndex = wordOptions.firstIndex(of: targetWord.arabic) ?? 0
        
        return DualColumnQuizItem(
            id: "q_\(UUID().uuidString.prefix(8))",
            type: .constructiveSynthesis,
            displayCard: DisplayCard(mainText: root, subText: nuance),
            leftColumn: ColumnSelector(label: "형태", options: leftOptions),
            rightColumn: ColumnSelector(label: "결과", options: rightOptions),
            correctPair: ("f\(verbForm)", "w\(correctWordIndex)")
        )
    }
    
    // MARK: - Validate Answer
    func validateAnswer(quiz: DualColumnQuizItem, leftSelection: String, rightSelection: String) -> Bool {
        return leftSelection == quiz.correctPair.0 && rightSelection == quiz.correctPair.1
    }
    
    // MARK: - Generate Mixed Session
    func generateMixedSession(words: [Word], count: Int = 10) -> [DualColumnQuizItem] {
        var quizzes: [DualColumnQuizItem] = []
        
        // Filter words with verbForm and root
        let eligibleWords = words.filter { $0.verbForm != nil && $0.root != nil }
        
        for _ in 0..<count {
            let quizType = Int.random(in: 1...3)
            
            switch quizType {
            case 1:
                // Type 1: Pattern Recognition
                let randomForm = Int.random(in: 1...10)
                quizzes.append(generatePatternRecognition(targetForm: randomForm))
                
            case 2:
                // Type 2: Word Deconstruction
                if let word = eligibleWords.randomElement(),
                   let quiz = generateWordDeconstruction(word: word, allWords: eligibleWords) {
                    quizzes.append(quiz)
                }
                
            case 3:
                // Type 3: Constructive Synthesis
                if let word = eligibleWords.randomElement(),
                   let quiz = generateConstructiveSynthesis(targetWord: word, relatedWords: eligibleWords) {
                    quizzes.append(quiz)
                }
                
            default:
                break
            }
        }
        
        return quizzes
    }
}
