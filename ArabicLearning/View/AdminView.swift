// AdminView - 관리자 뷰 (Placeholder)
// CSV 업로드 및 데이터 관리

import SwiftUI
import SwiftData

struct AdminView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var importResult: String = ""
    @State private var showingImporter = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // TODO: 피그마 디자인 적용 예정
                Text("⚙️ 관리자")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                // 샘플 데이터 로드 버튼
                Button {
                    loadSampleData()
                } label: {
                    Label("샘플 데이터 로드", systemImage: "doc.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                
                // CSV 파일 가져오기
                Button {
                    showingImporter = true
                } label: {
                    Label("CSV 파일 가져오기", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                
                if !importResult.isEmpty {
                    Text(importResult)
                        .foregroundStyle(importResult.contains("✅") ? .green : .red)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("관리")
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.commaSeparatedText]
        ) { result in
            handleFileImport(result)
        }
    }
    
    private func loadSampleData() {
        do {
            let count = try CSVDataLoader.loadSampleData(context: modelContext)
            importResult = "✅ \(count)개 단어 로드 완료"
        } catch {
            importResult = "❌ 오류: \(error.localizedDescription)"
        }
    }
    
    private func handleFileImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            do {
                guard url.startAccessingSecurityScopedResource() else { return }
                defer { url.stopAccessingSecurityScopedResource() }
                
                let csvString = try String(contentsOf: url, encoding: .utf8)
                let count = try CSVDataLoader.importCSV(csvString, context: modelContext)
                importResult = "✅ \(count)개 단어 가져오기 완료"
            } catch {
                importResult = "❌ 오류: \(error.localizedDescription)"
            }
        case .failure(let error):
            importResult = "❌ 파일 선택 오류: \(error.localizedDescription)"
        }
    }
}

#Preview {
    AdminView()
        .modelContainer(for: [Chapter.self, Word.self])
}
