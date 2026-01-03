// LearningHubViewModel.swift
// Central State Management for the Learning Hub
// Uses strict typing - NO magic numbers based on level ID

import Foundation
import SwiftData
import SwiftUI

@Observable
final class LearningHubViewModel {
    
    // MARK: - Selected Level State
    
    /// Currently selected level ID (persisted in UserDefaults)
    var selectedLevelID: Int {
        didSet {
            UserDefaults.standard.set(selectedLevelID, forKey: "selectedLevelID")
            refreshCurrentLevel()
        }
    }
    
    /// Current level object
    var currentLevel: StudyLevel?
    
    /// All available levels
    var levels: [StudyLevel] = []
    
    /// Reading passages for current level
    var passages: [ReadingPassage] = []
    
    // MARK: - New 50 Sub-level System
    
    /// All curriculum blocks (12 blocks)
    var blocks: [CurriculumBlock] = []
    
    /// Currently selected block
    var currentBlock: CurriculumBlock?
    
    /// Sub-levels in current block
    var currentSubLevels: [SubLevel] = []
    
    /// Selected sub-level ID
    var selectedSubLevelID: String = "1-5" {
        didSet {
            UserDefaults.standard.set(selectedSubLevelID, forKey: "selectedSubLevelID")
            refreshCurrentSubLevel()
        }
    }
    
    /// Current sub-level object
    var currentSubLevel: SubLevel?
    
    // MARK: - UI State
    
    var showingDailySession = false
    var showingStructureQuiz = false
    var showingPassageReading = false
    var selectedPassage: ReadingPassage?
    
    // MARK: - Stats
    
    var todayStudiedCount: Int = 0
    var todayReviewCount: Int = 0
    var currentMastery: Double = 0.0
    
    // MARK: - Dependencies
    
    private var modelContext: ModelContext?
    
    // MARK: - Init
    
    init() {
        self.selectedLevelID = UserDefaults.standard.integer(forKey: "selectedLevelID")
        if selectedLevelID == 0 {
            selectedLevelID = 1 // Default to Level 1
        }
    }
    
    // MARK: - Setup
    
    func setup(context: ModelContext) {
        self.modelContext = context
        loadLevels()
        refreshCurrentLevel()
        loadPassages()
        refreshStats()
    }
    
    // MARK: - Data Loading
    
    private func loadLevels() {
        guard let context = modelContext else { return }
        
        let descriptor = FetchDescriptor<StudyLevel>()
        levels = ((try? context.fetch(descriptor)) ?? []).sorted { $0.levelID < $1.levelID }
    }
    
    func refreshCurrentLevel() {
        currentLevel = levels.first { $0.levelID == selectedLevelID }
        loadPassages()
        refreshStats()
    }
    
    private func loadPassages() {
        guard let context = modelContext else { return }
        
        let levelID = selectedLevelID
        let descriptor = FetchDescriptor<ReadingPassage>(
            predicate: #Predicate { $0.levelID == levelID }
        )
        passages = (try? context.fetch(descriptor)) ?? []
    }
    
    private func refreshStats() {
        guard let context = modelContext, let level = currentLevel else { return }
        
        // Calculate mastery for current level
        let levelID = level.levelID
        let wordDescriptor = FetchDescriptor<Word>(
            predicate: #Predicate { $0.levelID == levelID }
        )
        
        if let words = try? context.fetch(wordDescriptor) {
            let matureCount = words.filter { $0.stability > 21 }.count
            currentMastery = words.isEmpty ? 0 : Double(matureCount) / Double(words.count)
        }
    }
    
    // MARK: - Block/SubLevel Loading (50 Sub-level System)
    
    func loadBlocks() {
        guard let context = modelContext else { return }
        
        let descriptor = FetchDescriptor<CurriculumBlock>(sortBy: [SortDescriptor(\.blockID)])
        blocks = (try? context.fetch(descriptor)) ?? []
        
        // Restore selected sub-level from UserDefaults
        if let savedSubLevel = UserDefaults.standard.string(forKey: "selectedSubLevelID") {
            selectedSubLevelID = savedSubLevel
        }
        
        refreshCurrentSubLevel()
    }
    
    func refreshCurrentSubLevel() {
        guard let context = modelContext else { return }
        
        // Find the sub-level matching the selected ID
        let subLevelID = selectedSubLevelID
        let descriptor = FetchDescriptor<SubLevel>(
            predicate: #Predicate { $0.subLevelID == subLevelID }
        )
        
        if let subLevels = try? context.fetch(descriptor), let subLevel = subLevels.first {
            currentSubLevel = subLevel
            currentBlock = subLevel.block
            
            // Load all sub-levels in this block
            if let blockID = currentBlock?.blockID {
                let blockSubLevelDescriptor = FetchDescriptor<SubLevel>(
                    predicate: #Predicate { $0.blockID == blockID },
                    sortBy: [SortDescriptor(\.orderInBlock)]
                )
                currentSubLevels = (try? context.fetch(blockSubLevelDescriptor)) ?? []
            }
        }
    }
    
    func selectBlock(_ block: CurriculumBlock) {
        guard !block.isLocked else { return }
        currentBlock = block
        
        // Load sub-levels for this block
        guard let context = modelContext else { return }
        let blockID = block.blockID
        let descriptor = FetchDescriptor<SubLevel>(
            predicate: #Predicate { $0.blockID == blockID },
            sortBy: [SortDescriptor(\.orderInBlock)]
        )
        currentSubLevels = (try? context.fetch(descriptor)) ?? []
        
        // Select first unlocked sub-level
        if let firstUnlocked = currentSubLevels.first(where: { !$0.isLocked }) {
            selectedSubLevelID = firstUnlocked.subLevelID
        }
    }
    
    func selectSubLevel(_ subLevel: SubLevel) {
        guard !subLevel.isLocked else { return }
        selectedSubLevelID = subLevel.subLevelID
    }
    
    /// Color for current block
    var currentBlockColor: Color {
        guard let block = currentBlock else { return .blue }
        switch block.blockID {
        case 0: return .gray
        case 1, 2: return .blue
        case 3, 4, 5: return .green
        case 6: return .orange
        case 7, 8, 9, 10: return .purple
        case 11, 12: return .red
        default: return .blue
        }
    }
    
    // MARK: - Level Selection
    
    func selectLevel(_ level: StudyLevel) {
        guard !level.isLocked else { return }
        selectedLevelID = level.levelID
    }
    
    // MARK: - Computed Properties (Based on currentLevel.levelType - NO magic numbers!)
    
    /// Current level type - uses enum, NOT level ID comparison
    var currentLevelType: LevelType {
        currentLevel?.levelType ?? .vocabulary
    }
    
    /// Action button title based on level type
    var currentActionTitle: String {
        currentLevelType.actionTitle
    }
    
    /// Action button subtitle
    var currentActionSubtitle: String {
        currentLevelType.actionSubtitle
    }
    
    /// Action button icon
    var currentActionIcon: String {
        currentLevelType.icon
    }
    
    /// Action button color
    var currentActionColor: Color {
        switch currentLevelType {
        case .vocabulary: return .orange
        case .grammar: return .purple
        }
    }
    
    /// Whether daily session is available
    var isDailySessionAvailable: Bool {
        guard let level = currentLevel else { return false }
        return !level.isLocked
    }
    
    // MARK: - Actions (Clean Responsibility Pattern)
    
    /// Starts the appropriate session based on level type
    func startSession() {
        guard isDailySessionAvailable else { return }
        
        switch currentLevelType {
        case .vocabulary:
            // Triggers QuizSessionGenerator with 20/10 logic
            showingDailySession = true
            
        case .grammar:
            // Triggers StructureTestGenerator
            showingStructureQuiz = true
        }
    }
    
    func openPassage(_ passage: ReadingPassage) {
        selectedPassage = passage
        showingPassageReading = true
    }
}
