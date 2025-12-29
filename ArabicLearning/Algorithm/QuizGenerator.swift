// QuizGenerator.swift
// Spiral Curriculum State Machine - Unified Quiz Dispatcher
// Word (Cloze) + VerbForm (Dual-Column) 통합 관리

import Foundation
import SwiftData

// MARK: - Quiz State (Spiral Curriculum)
enum QuizState: String, Codable {
    case novice = "novice"           // State A: Word 기반 Cloze Quiz
    case bridge = "bridge"           // State B: VerbForm 기반 Dual-Column Quiz
    case intermediate = "intermediate" // State C: 혼합 + 고급
}

// MARK: - Quiz Item Wrapper (Union Type)
/// Word 또는 VerbForm 퀴즈를 통합하는 래퍼
enum QuizItemWrapper: Identifiable {
    case cloze(Word)
    case dualColumn(DualColumnQuizItem)
    
    var id: String {
        switch self {
        case .cloze(let word):
            return word.id.uuidString
        case .dualColumn(let quiz):
            return quiz.id
        }
    }
}

// MARK: - Bridge Quiz Item (for Word-based fallback)
struct BridgeQuizItem {
    let root: String
    let meaningHint: String
    let choices: [String]
    let correctIndex: Int
    let correctPattern: String
}

// MARK: - User Progress
@Model
final class UserProgress {
    var id: UUID = UUID()
    
    var currentStateRaw: String = QuizState.novice.rawValue
    var currentState: QuizState {
        get { QuizState(rawValue: currentStateRaw) ?? .novice }
        set { currentStateRaw = newValue.rawValue }
    }
    
    var totalAttempts: Int = 0
    var correctAttempts: Int = 0
    var stateACorrectRate: Double = 0.0
    var bridgeConsecutiveCorrect: Int = 0
    var masteredRoots: [String] = []
    
    var accuracy: Double {
        guard totalAttempts > 0 else { return 0 }
        return Double(correctAttempts) / Double(totalAttempts)
    }
    
    init() {
        self.id = UUID()
        self.currentStateRaw = QuizState.novice.rawValue
        self.totalAttempts = 0
        self.correctAttempts = 0
        self.stateACorrectRate = 0.0
        self.bridgeConsecutiveCorrect = 0
        self.masteredRoots = []
    }
}

// MARK: - Quiz Generator Service (Unified Dispatcher)
final class QuizGenerator {
    static let shared = QuizGenerator()
    private init() {}
    
    // MARK: - Constants
    private let bridgeThreshold: Double = 0.8
    private let minAttemptsForBridge: Int = 20
    private let bridgeConsecutiveRequired: Int = 5
    private let dailyLimit: Int = 30
    
    // MARK: - Get Current State
    func getCurrentState(progress: UserProgress) -> QuizState {
        if progress.currentState == .novice {
            if progress.totalAttempts >= minAttemptsForBridge &&
               progress.stateACorrectRate >= bridgeThreshold {
                return .bridge
            }
        }
        if progress.currentState == .bridge {
            if progress.bridgeConsecutiveCorrect >= bridgeConsecutiveRequired {
                return .intermediate
            }
        }
        return progress.currentState
    }
    
    // MARK: - Legacy Compatibility (Word-only)
    /// 기존 StudySessionViewModel 호환용
    func generateSession(
        state: QuizState,
        allWords: [Word],
        limit: Int = 30
    ) -> [Word] {
        switch state {
        case .novice:
            return generateNoviceSessionLegacy(words: allWords, limit: limit)
        case .bridge, .intermediate:
            // Bridge/Intermediate는 VerbForm 기반이므로 Word로 fallback
            return generateNoviceSessionLegacy(words: allWords, limit: limit)
        }
    }
    
    private func generateNoviceSessionLegacy(words: [Word], limit: Int) -> [Word] {
        let filtered = words.filter { word in
            word.complexityLevel == 1 &&
            (word.morphologyType == .sound || word.morphologyType == nil)
        }
        
        var grouped: [[Word]] = []
        var rootMap: [String: [Word]] = [:]
        
        for word in filtered {
            if let root = word.root {
                rootMap[root, default: []].append(word)
            } else {
                grouped.append([word])
            }
        }
        
        for (_, rootWords) in rootMap {
            grouped.append(rootWords.shuffled())
        }
        
        return grouped.shuffled().flatMap { $0 }.prefix(limit).map { $0 }
    }
    
    // MARK: - Generate Unified Session ⭐
    /// 상태에 따라 Word 또는 VerbForm 기반 퀴즈 생성
    @MainActor
    func generateUnifiedSession(
        state: QuizState,
        context: ModelContext,
        limit: Int = 30
    ) -> [QuizItemWrapper] {
        switch state {
        case .novice:
            return generateNoviceSession(context: context, limit: limit)
        case .bridge:
            return generateBridgeSession(context: context, limit: limit)
        case .intermediate:
            return generateIntermediateSession(context: context, limit: limit)
        }
    }
    
    // MARK: - State A: Novice (Word-based Cloze)
    @MainActor
    private func generateNoviceSession(context: ModelContext, limit: Int) -> [QuizItemWrapper] {
        let descriptor = FetchDescriptor<Word>()
        guard let words = try? context.fetch(descriptor) else { return [] }
        
        // Filter: complexity = 1, Sound type
        let filtered = words.filter { word in
            word.complexityLevel == 1 &&
            (word.morphologyType == .sound || word.morphologyType == nil)
        }
        
        // 같은 root끼리 그룹핑 (암묵적 Priming)
        var grouped: [[Word]] = []
        var rootMap: [String: [Word]] = [:]
        
        for word in filtered {
            if let root = word.root {
                rootMap[root, default: []].append(word)
            } else {
                grouped.append([word])
            }
        }
        
        for (_, rootWords) in rootMap {
            grouped.append(rootWords.shuffled())
        }
        
        let sessionWords = grouped.shuffled().flatMap { $0 }.prefix(limit)
        return sessionWords.map { .cloze($0) }
    }
    
    // MARK: - State B: Bridge (VerbForm-based Dual-Column) ⭐
    @MainActor
    private func generateBridgeSession(context: ModelContext, limit: Int) -> [QuizItemWrapper] {
        let descriptor = FetchDescriptor<VerbForm>(
            predicate: #Predicate { $0.verified == true }
        )
        guard let verbForms = try? context.fetch(descriptor) else { return [] }
        
        // VerbForm → DualColumnQuizItem 변환
        var quizItems: [QuizItemWrapper] = []
        let shuffled = verbForms.shuffled().prefix(limit)
        
        for verbForm in shuffled {
            let quizType = Int.random(in: 1...3)
            
            switch quizType {
            case 1:
                // Type 1: Pattern Recognition
                let quiz = DualColumnQuizGenerator.shared.generatePatternRecognition(
                    targetForm: verbForm.formNumber
                )
                quizItems.append(.dualColumn(quiz))
                
            case 2:
                // Type 2: Word Deconstruction (VerbForm 기반)
                if let quiz = generateDeconstructionFromVerbForm(verbForm, allForms: Array(verbForms)) {
                    quizItems.append(.dualColumn(quiz))
                }
                
            case 3:
                // Type 3: Constructive Synthesis
                if let quiz = generateSynthesisFromVerbForm(verbForm, allForms: Array(verbForms)) {
                    quizItems.append(.dualColumn(quiz))
                }
                
            default:
                break
            }
        }
        
        return quizItems
    }
    
    // MARK: - State C: Intermediate (Mixed)
    @MainActor
    private func generateIntermediateSession(context: ModelContext, limit: Int) -> [QuizItemWrapper] {
        var items: [QuizItemWrapper] = []
        
        // 50% Word, 50% VerbForm
        let wordLimit = limit / 2
        let verbFormLimit = limit - wordLimit
        
        // Word items (complexity 2+)
        let wordDescriptor = FetchDescriptor<Word>()
        if let words = try? context.fetch(wordDescriptor) {
            let filtered = words.filter { $0.complexityLevel >= 2 || ($0.verbForm ?? 1) >= 2 }
            items.append(contentsOf: filtered.shuffled().prefix(wordLimit).map { .cloze($0) })
        }
        
        // VerbForm items
        let verbDescriptor = FetchDescriptor<VerbForm>(
            predicate: #Predicate { $0.verified == true }
        )
        if let verbForms = try? context.fetch(verbDescriptor) {
            for verbForm in verbForms.shuffled().prefix(verbFormLimit) {
                let quiz = DualColumnQuizGenerator.shared.generatePatternRecognition(
                    targetForm: verbForm.formNumber
                )
                items.append(.dualColumn(quiz))
            }
        }
        
        return items.shuffled()
    }
    
    // MARK: - VerbForm → DualColumnQuizItem Helpers
    
    private func generateDeconstructionFromVerbForm(
        _ verbForm: VerbForm,
        allForms: [VerbForm]
    ) -> DualColumnQuizItem? {
        // Left: 형태 선택
        var formOptions = [1, 2, 3, 4, 5, 6].filter { $0 != verbForm.formNumber }
            .shuffled().prefix(3).map { $0 }
        formOptions.append(verbForm.formNumber)
        formOptions.shuffle()
        
        let leftOptions = formOptions.map { form in
            QuizOption(id: "f\(form)", text: "\(form)형")
        }
        
        // Right: 어근 선택
        var rootOptions = allForms
            .filter { $0.root != verbForm.root }
            .map { $0.root }
            .shuffled()
            .prefix(3)
            .map { $0 }
        rootOptions.append(verbForm.root)
        rootOptions.shuffle()
        
        let rightOptions = rootOptions.enumerated().map { (index, root) in
            QuizOption(id: "r\(index)", text: root)
        }
        
        let correctRootIndex = rootOptions.firstIndex(of: verbForm.root) ?? 0
        
        return DualColumnQuizItem(
            id: "q_\(UUID().uuidString.prefix(8))",
            type: .wordDeconstruction,
            displayCard: DisplayCard(mainText: verbForm.arabicWord, subText: nil),
            leftColumn: ColumnSelector(label: "형태", options: leftOptions),
            rightColumn: ColumnSelector(label: "어근", options: rightOptions),
            correctPair: ("f\(verbForm.formNumber)", "r\(correctRootIndex)")
        )
    }
    
    private func generateSynthesisFromVerbForm(
        _ verbForm: VerbForm,
        allForms: [VerbForm]
    ) -> DualColumnQuizItem? {
        // Left: 형태 선택
        var formOptions = [1, 3, 6, 8, 10].filter { $0 != verbForm.formNumber }
            .shuffled().prefix(3).map { $0 }
        formOptions.append(verbForm.formNumber)
        formOptions.shuffle()
        
        let leftOptions = formOptions.map { form in
            QuizOption(id: "f\(form)", text: "\(form)형")
        }
        
        // Right: 결과 단어 선택
        var wordOptions = allForms
            .filter { $0.root == verbForm.root && $0.id != verbForm.id }
            .map { $0.arabicWord }
            .shuffled()
            .prefix(3)
            .map { $0 }
        wordOptions.append(verbForm.arabicWord)
        wordOptions.shuffle()
        
        let rightOptions = wordOptions.enumerated().map { (index, word) in
            QuizOption(id: "w\(index)", text: word)
        }
        
        let correctWordIndex = wordOptions.firstIndex(of: verbForm.arabicWord) ?? 0
        
        return DualColumnQuizItem(
            id: "q_\(UUID().uuidString.prefix(8))",
            type: .constructiveSynthesis,
            displayCard: DisplayCard(mainText: verbForm.root, subText: verbForm.nuanceKorean),
            leftColumn: ColumnSelector(label: "형태", options: leftOptions),
            rightColumn: ColumnSelector(label: "결과", options: rightOptions),
            correctPair: ("f\(verbForm.formNumber)", "w\(correctWordIndex)")
        )
    }
    
    // MARK: - Update Progress
    func updateProgress(
        progress: UserProgress,
        correct: Bool,
        state: QuizState
    ) {
        progress.totalAttempts += 1
        if correct {
            progress.correctAttempts += 1
        }
        
        switch state {
        case .novice:
            progress.stateACorrectRate = progress.accuracy
        case .bridge:
            if correct {
                progress.bridgeConsecutiveCorrect += 1
            } else {
                progress.bridgeConsecutiveCorrect = 0
            }
        case .intermediate:
            break
        }
        
        // State 전환 체크
        let newState = getCurrentState(progress: progress)
        if newState != progress.currentState {
            progress.currentState = newState
        }
    }
}
