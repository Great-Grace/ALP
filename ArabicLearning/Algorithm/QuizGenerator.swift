// QuizGenerator.swift
// Spiral Curriculum State Machine for Morphology-Based Learning

import Foundation
import SwiftData

// MARK: - Quiz State (Spiral Curriculum)
enum QuizState: String, Codable {
    case novice = "novice"           // State A: 암묵적 root 그룹핑
    case bridge = "bridge"           // State B: Pattern Matching Quiz
    case intermediate = "intermediate" // State C: 명시적 힌트, 확장
}

// MARK: - Quiz Type
enum QuizType {
    case cloze           // 기존 빈칸 채우기
    case patternMatch    // Bridge: root + meaning → 정답 선택
    case rootFamily      // 같은 어근 단어들 연결
}

// MARK: - Bridge Quiz Item
struct BridgeQuizItem {
    let root: String           // 예: "ك-ت-ب"
    let meaningHint: String    // 예: "Doer of writing"
    let choices: [String]      // 예: ["كَاتِب", "مَكْتُوب", "كِتَاب"]
    let correctIndex: Int
    let correctPattern: String // 예: "فَاعِل"
}

// MARK: - User Progress
@Model
final class UserProgress {
    var id: UUID = UUID()
    
    // 현재 상태
    var currentStateRaw: String = QuizState.novice.rawValue
    var currentState: QuizState {
        get { QuizState(rawValue: currentStateRaw) ?? .novice }
        set { currentStateRaw = newValue.rawValue }
    }
    
    // 통계
    var totalAttempts: Int = 0
    var correctAttempts: Int = 0
    var stateACorrectRate: Double = 0.0
    
    // 마스터한 어근들
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
        self.masteredRoots = []
    }
}

// MARK: - Quiz Generator Service
final class QuizGenerator {
    static let shared = QuizGenerator()
    private init() {}
    
    // MARK: - State Transition Logic
    
    /// State A → B 전환 조건: 80% 정답률 + 최소 20문제
    private let bridgeThreshold: Double = 0.8
    private let minAttemptsForBridge: Int = 20
    
    /// State B → C 전환 조건: Bridge Quiz 5회 연속 정답
    private let bridgeConsecutiveRequired: Int = 5
    
    // MARK: - Get Current State
    func getCurrentState(progress: UserProgress) -> QuizState {
        // 자동 상태 전환 체크
        if progress.currentState == .novice {
            if progress.totalAttempts >= minAttemptsForBridge &&
               progress.stateACorrectRate >= bridgeThreshold {
                return .bridge
            }
        }
        return progress.currentState
    }
    
    // MARK: - Generate Session (State-Based)
    func generateSession(
        state: QuizState,
        allWords: [Word],
        limit: Int = 30
    ) -> [Word] {
        switch state {
        case .novice:
            return generateNoviceSession(words: allWords, limit: limit)
        case .bridge:
            return generateBridgeSession(words: allWords, limit: limit)
        case .intermediate:
            return generateIntermediateSession(words: allWords, limit: limit)
        }
    }
    
    // MARK: - State A: Novice (Implicit Root Grouping)
    private func generateNoviceSession(words: [Word], limit: Int) -> [Word] {
        // Filter: complexity = 1, Sound verbs only
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
                // root 없는 단어는 개별 그룹
                grouped.append([word])
            }
        }
        
        // root 그룹들을 세션에 추가 (연속 배치)
        for (_, rootWords) in rootMap {
            if rootWords.count >= 2 {
                grouped.append(rootWords.shuffled())
            } else {
                grouped.append(rootWords)
            }
        }
        
        // 그룹 순서 섞고 limit까지 자르기
        return grouped.shuffled().flatMap { $0 }.prefix(limit).map { $0 }
    }
    
    // MARK: - State B: Bridge (Pattern Matching)
    private func generateBridgeSession(words: [Word], limit: Int) -> [Word] {
        // Bridge용 단어: root와 pattern이 있는 단어
        let bridgeReady = words.filter { word in
            word.root != nil && word.pattern != nil
        }
        
        return Array(bridgeReady.shuffled().prefix(limit))
    }
    
    // MARK: - State C: Intermediate (Expansion)
    private func generateIntermediateSession(words: [Word], limit: Int) -> [Word] {
        // complexity 2 또는 verb_form 2-10
        // Hollow/Defective는 초반 제외 → 점진적 포함
        let filtered = words.filter { word in
            word.complexityLevel == 2 ||
            (word.verbForm ?? 1) >= 2
        }
        
        return Array(filtered.shuffled().prefix(limit))
    }
    
    // MARK: - Create Bridge Quiz
    func createBridgeQuiz(
        targetWord: Word,
        allWords: [Word]
    ) -> BridgeQuizItem? {
        guard let root = targetWord.root,
              let pattern = targetWord.pattern else {
            return nil
        }
        
        // 같은 root의 다른 단어들 (오답 선택지)
        let sameRoot = allWords.filter { word in
            word.root == root && word.id != targetWord.id
        }
        
        // 최소 2개 선택지 필요
        guard sameRoot.count >= 2 else { return nil }
        
        // 선택지 구성: 정답 + 오답 3개
        var choices = [targetWord.arabic]
        choices.append(contentsOf: sameRoot.prefix(3).map { $0.arabic })
        
        let shuffled = choices.shuffled()
        let correctIndex = shuffled.firstIndex(of: targetWord.arabic) ?? 0
        
        return BridgeQuizItem(
            root: root,
            meaningHint: targetWord.korean,
            choices: shuffled,
            correctIndex: correctIndex,
            correctPattern: pattern
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
        
        // State A 정답률 갱신
        if state == .novice {
            progress.stateACorrectRate = progress.accuracy
        }
        
        // State 전환 체크
        let newState = getCurrentState(progress: progress)
        if newState != progress.currentState {
            progress.currentState = newState
        }
    }
}
