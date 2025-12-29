// ArabicLearningApp - Multiplatform Entry Point
// Swift 5.9+ / SwiftUI / SwiftData (iOS 17+ / macOS 14+)

import SwiftUI
import SwiftData

@main
struct ArabicLearningApp: App {
    @State private var isLoading = true
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            VocabularyBook.self,
            Chapter.self,
            Word.self,
            QuizHistory.self,
            UserProgress.self,
            VerbForm.self
        ])
        // TODO: [CloudKit] Apple Developer Program 가입 후 활성화
        // CloudKit 설정: iCloud 자동 동기화 활성화
        // ⚠️ Xcode에서 iCloud Capability 설정 필요 (Target > Signing & Capabilities > iCloud > CloudKit)
        // let modelConfiguration = ModelConfiguration(
        //     schema: schema,
        //     isStoredInMemoryOnly: false,
        //     cloudKitDatabase: .private("iCloud.com.taewoo.ArabicLearning")
        // )
        
        // 현재: 로컬 전용 (FSRS 개인화 복습 정상 작동)
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
            .onAppear {
                // Perform data migration
                DataMigrationManager.performMigrationIfNeeded(context: sharedModelContainer.mainContext)
                
                // Simulate loading delay for smooth intro experience
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation {
                        isLoading = false
                    }
                }
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

