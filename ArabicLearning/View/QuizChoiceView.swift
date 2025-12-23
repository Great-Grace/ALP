// QuizChoiceView - 선택형 퀴즈 뷰 (Placeholder)
// 피그마 디자인 대기 중

import SwiftUI
import SwiftData

struct QuizChoiceView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = QuizViewModel()
    
    var body: some View {
        NavigationStack {
            VStack {
                // TODO: 피그마 디자인 적용 예정
                Text("📝 퀴즈 모드")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("피그마 디자인 대기 중...")
                    .foregroundStyle(.secondary)
                
                Spacer()
            }
            .padding()
            .navigationTitle("퀴즈")
        }
        .onAppear {
            viewModel.setup(context: modelContext)
        }
    }
}

#Preview {
    QuizChoiceView()
        .modelContainer(for: [Word.self, QuizHistory.self])
}
