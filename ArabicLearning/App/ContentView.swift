// ContentView - Main Navigation
// Unified Learning Hub Entry Point

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        MainTabView()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Word.self, StudyLevel.self, QuizHistory.self])
}
