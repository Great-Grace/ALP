// ContentView - Main Navigation
// 2탭 구조: 홈, 관리

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("홈", systemImage: "house.fill")
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
        .modelContainer(for: [VocabularyBook.self, Chapter.self, Word.self, QuizHistory.self])
}
