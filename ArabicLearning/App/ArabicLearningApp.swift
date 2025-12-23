// ArabicLearningApp - iOS Entry Point
// Swift 5.9+ / SwiftUI / SwiftData (iOS 17+)

import SwiftUI
import SwiftData

@main
struct ArabicLearningApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            VocabularyBook.self,
            Chapter.self,
            Word.self,
            QuizHistory.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
