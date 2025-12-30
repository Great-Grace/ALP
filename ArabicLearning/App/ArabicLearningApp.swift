// ArabicLearningApp - Multiplatform Entry Point
// Swift 5.9+ / SwiftUI / SwiftData (iOS 17+ / macOS 14+)

import SwiftUI
import SwiftData

// MARK: - Global State for Data Warning

/// Observable class to track if app is running in in-memory (data loss) mode
@Observable
class AppState {
    static let shared = AppState()
    
    /// True if database failed and we're using in-memory fallback
    var isInMemoryMode: Bool = false
    
    /// Error message if database failed
    var dbErrorMessage: String?
    
    private init() {}
}

@main
struct ArabicLearningApp: App {
    @State private var isLoading = true
    
    // MARK: - Model Container (Graceful Error Handling)
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            VocabularyBook.self,
            Chapter.self,
            Word.self,
            QuizHistory.self,
            UserProgress.self,
            VerbForm.self,
            Article.self,
            StudyLevel.self,
            ReadingPassage.self
        ])
        
        // Primary: Persistent Storage
        let persistentConfig = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        
        do {
            let container = try ModelContainer(for: schema, configurations: [persistentConfig])
            AppState.shared.isInMemoryMode = false
            return container
        } catch {
            // ⚠️ Graceful Fallback: In-Memory Container
            print("⚠️ [CRITICAL] Failed to create persistent ModelContainer: \(error)")
            print("⚠️ Falling back to in-memory storage. Data will NOT be saved.")
            
            // Mark app as in-memory mode for warning UI
            AppState.shared.isInMemoryMode = true
            AppState.shared.dbErrorMessage = error.localizedDescription
            
            let memoryConfig = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true
            )
            
            do {
                return try ModelContainer(for: schema, configurations: [memoryConfig])
            } catch {
                print("❌ [FATAL] Even in-memory container failed: \(error)")
                let minimalSchema = Schema([Word.self])
                return try! ModelContainer(for: minimalSchema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
            }
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if isLoading {
                    IntroView(isLoading: $isLoading)
                        .transition(.opacity)
                } else {
                    ContentView()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.5), value: isLoading)
            .environment(AppState.shared)  // Pass AppState to all views
            .onAppear {
                // Data migration check (light operation)
                DataMigrationManager.performMigrationIfNeeded(context: sharedModelContainer.mainContext)
                // Note: Heavy loading is now handled by IntroView + DataLoaderService
            }
            #if os(macOS)
            .frame(minWidth: 900, minHeight: 600)
            #endif
        }
        .modelContainer(sharedModelContainer)
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1100, height: 750)
        #endif
    }
}
