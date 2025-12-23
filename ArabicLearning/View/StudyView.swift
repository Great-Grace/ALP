// StudyView - 학습 모드 뷰 (Placeholder)
// 피그마 디자인 대기 중

import SwiftUI
import SwiftData

struct StudyView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = StudyViewModel()
    
    var body: some View {
        NavigationStack {
            VStack {
                // TODO: 피그마 디자인 적용 예정
                Text("📚 학습 모드")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("피그마 디자인 대기 중...")
                    .foregroundStyle(.secondary)
                
                Spacer()
            }
            .padding()
            .navigationTitle("학습")
        }
        .onAppear {
            viewModel.setup(context: modelContext)
        }
    }
}

#Preview {
    StudyView()
        .modelContainer(for: [Chapter.self, Word.self])
}
