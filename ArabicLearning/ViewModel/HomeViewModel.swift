// HomeViewModel.swift
// Level-Based ViewModel (Legacy Chapter removed)

import Foundation
import SwiftData
import SwiftUI

@Observable
class HomeViewModel {
    // Stats
    var totalWords: Int = 0
    var totalLevels: Int = 0
    var todayCorrect: Int = 0
    var todayTotal: Int = 0
    var streakDays: Int = 0
    var completedDays: Set<String> = []
    
    // UI State
    var showStudySession: Bool = false
    var selectedQuizMode: QuizMode = .general
    
    // Study Count Selection
    var selectedStudyCount: Int = 20
    static let studyCountOptions = [10, 20, 30, 50]
    
    // Level Filtering (replaced Chapter)
    var availableLevels: [StudyLevel] = []
    var selectedLevelIds: Set<Int> = []
    
    // Reader / Library
    var articles: [Article] = []
    var showReader: Bool = false
    var selectedArticle: Article?
    
    var selectedLevelsCount: Int {
        selectedLevelIds.isEmpty ? availableLevels.count : selectedLevelIds.count
    }
    
    var isAllSelected: Bool {
        selectedLevelIds.isEmpty || selectedLevelIds.count == availableLevels.count
    }
    
    // Dependencies
    private var modelContext: ModelContext?
    
    func setup(context: ModelContext) {
        self.modelContext = context
        refreshData()
        loadLevels()
        loadArticles()
    }
    
    func refreshData() {
        guard let context = modelContext else { return }
        
        // Words count
        let wordDescriptor = FetchDescriptor<Word>()
        totalWords = (try? context.fetchCount(wordDescriptor)) ?? 0
        
        // Levels count
        let levelDescriptor = FetchDescriptor<StudyLevel>()
        totalLevels = (try? context.fetchCount(levelDescriptor)) ?? 0
        
        // Today's stats (fetch all and filter in memory to avoid predicate issues)
        let historyDescriptor = FetchDescriptor<QuizHistory>()
        if let allHistory = try? context.fetch(historyDescriptor) {
            let today = Calendar.current.startOfDay(for: Date())
            let todayHistory = allHistory.filter { $0.answeredAt >= today }
            todayTotal = todayHistory.count
            todayCorrect = todayHistory.filter { $0.isCorrect }.count
        }
    }
    
    private func loadLevels() {
        guard let context = modelContext else { return }
        
        let descriptor = FetchDescriptor<StudyLevel>()
        availableLevels = ((try? context.fetch(descriptor)) ?? []).sorted { $0.levelID < $1.levelID }
    }
    
    private func loadArticles() {
        guard let context = modelContext else { return }
        
        let descriptor = FetchDescriptor<Article>()
        articles = (try? context.fetch(descriptor)) ?? []
    }
    
    func selectArticle(_ article: Article) {
        selectedArticle = article
        showReader = true
    }
    
    func toggleSelectAll() {
        if isAllSelected {
            selectedLevelIds = []
        } else {
            selectedLevelIds = Set(availableLevels.map { $0.levelID })
        }
    }
    
    // MARK: - Legacy Compatibility
    
    // These keep old code working until fully migrated
    var availableChapters: [StudyLevel] { availableLevels }
    var selectedChapterIds: Set<UUID> = []
    var showChapterFilter: Bool = false
}
