import Foundation
import SwiftData
import SwiftUI

@Observable
class HomeViewModel {
    // Stats
    var totalWords: Int = 0
    var totalChapters: Int = 0
    var todayCorrect: Int = 0
    var todayTotal: Int = 0
    var streakDays: Int = 0
    var completedDays: Set<String> = []
    
    // UI State
    var showStudySession: Bool = false
    var showChapterFilter: Bool = false
    var selectedQuizMode: QuizMode = .general
    
    // Study Count Selection
    var selectedStudyCount: Int = 20
    static let studyCountOptions = [10, 20, 30, 50]
    
    // Chapter Filtering
    var availableChapters: [Chapter] = []
    var selectedChapterIds: Set<UUID> = []
    
    var selectedChaptersCount: Int {
        selectedChapterIds.isEmpty ? availableChapters.count : selectedChapterIds.count
    }
    
    var isAllSelected: Bool {
        selectedChapterIds.isEmpty || selectedChapterIds.count == availableChapters.count
    }
    
    // Dependencies
    private var modelContext: ModelContext?
    
    func setup(context: ModelContext) {
        self.modelContext = context
        refreshData()
        loadChapters()
    }
    
    func refreshData() {
        guard let context = modelContext else { return }
        
        // 1. Fetch Totals
        let chapterDescriptor = FetchDescriptor<Chapter>()
        let wordDescriptor = FetchDescriptor<Word>()
        
        totalChapters = (try? context.fetchCount(chapterDescriptor)) ?? 0
        totalWords = (try? context.fetchCount(wordDescriptor)) ?? 0
        
        // 2. Fetch Today's Stats
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        
        let historyDescriptor = FetchDescriptor<QuizHistory>(
            predicate: #Predicate<QuizHistory> { history in
                history.answeredAt >= startOfDay
            }
        )
        
        if let todayHistory = try? context.fetch(historyDescriptor) {
            todayTotal = todayHistory.count
            todayCorrect = todayHistory.filter { $0.isCorrect }.count
            
            if todayTotal > 0 {
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "ko_KR")
                formatter.dateFormat = "E"
                let todayDay = formatter.string(from: Date())
                completedDays.insert(todayDay)
            }
        }
        
        // 3. Simple Streak Calculation
        streakDays = todayTotal > 0 ? 1 : 0
    }
    
    // MARK: - Chapter Filtering
    private func loadChapters() {
        guard let context = modelContext else { return }
        
        let descriptor = FetchDescriptor<Chapter>(sortBy: [SortDescriptor(\.orderIndex)])
        availableChapters = (try? context.fetch(descriptor)) ?? []
        
        // Default: all selected
        selectedChapterIds = Set(availableChapters.map { $0.id })
    }
    
    func toggleChapter(_ id: UUID) {
        if selectedChapterIds.contains(id) {
            selectedChapterIds.remove(id)
        } else {
            selectedChapterIds.insert(id)
        }
    }
    
    func selectAllChapters() {
        selectedChapterIds = Set(availableChapters.map { $0.id })
    }
    
    func deselectAllChapters() {
        selectedChapterIds.removeAll()
    }
    
    func toggleSelectAll() {
        if isAllSelected {
            deselectAllChapters()
        } else {
            selectAllChapters()
        }
    }
    
    // Greeting Logic
    var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good Morning! ☀️" }
        if hour < 18 { return "Good Afternoon! 🌤️" }
        return "Good Evening! 🌙"
    }
    
    var accuracyText: String {
        guard todayTotal > 0 else { return "-" }
        let accuracy = Double(todayCorrect) / Double(todayTotal) * 100
        return "\(Int(accuracy))%"
    }
}

