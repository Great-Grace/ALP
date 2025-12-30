// ContentView - Main Navigation
// 3탭 구조: 커리큘럼, 복습, 관리

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            CurriculumView()
                .tabItem {
                    Label("커리큘럼", systemImage: "books.vertical.fill")
                }
            
            HomeView()
                .tabItem {
                    Label("복습", systemImage: "arrow.clockwise.circle.fill")
                }
            
            AdminView()
                .tabItem {
                    Label("관리", systemImage: "gearshape.fill")
                }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [VocabularyBook.self, Chapter.self, Word.self, QuizHistory.self, StudyLevel.self])
}

