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
    
    // Dependencies
    private var modelContext: ModelContext?
    
    func setup(context: ModelContext) {
        self.modelContext = context
        refreshData()
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
        
        // 3. Simple Streak Calculation (Example Logic)
        // In a real app, this would query past days. For now, we just track if today is active.
        streakDays = todayTotal > 0 ? 1 : 0
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
