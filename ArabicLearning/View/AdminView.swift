// AdminView - 관리자 화면
// Level-Based Data Management (Legacy VocabularyBook/Chapter removed)

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct AdminView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \StudyLevel.levelID) private var levels: [StudyLevel]
    @Query private var allWords: [Word]
    
    @State private var showImportSheet = false
    @State private var alertMessage = ""
    @State private var showAlert = false
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    // 데이터 현황
                    statsSection
                    
                    // 레벨별 데이터
                    levelDataSection
                    
                    // 데이터 관리
                    dataManagementSection
                    
                    // 위험 영역 (DEBUG 빌드만)
                    #if DEBUG
                    dangerSection
                        .padding(.top, 16)
                    #endif
                }
                .padding()
            }
            .background(groupedBackground)
            .navigationTitle("관리")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(action: reloadData) {
                            Label("데이터 새로고침", systemImage: "arrow.clockwise")
                        }
                        
                        Button(action: { showImportSheet = true }) {
                            Label("CSV 가져오기", systemImage: "doc.badge.plus")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .fileImporter(
                isPresented: $showImportSheet,
                allowedContentTypes: [.commaSeparatedText],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            .alert("알림", isPresented: $showAlert) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
            .overlay {
                if isLoading {
                    ProgressView("처리 중...")
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                }
            }
        }
    }
    
    // MARK: - Stats Section
    
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("데이터 현황")
                .font(.headline)
            
            HStack(spacing: 12) {
                statCard(
                    title: "레벨",
                    value: "\(levels.count)",
                    icon: "flag.fill",
                    color: .purple
                )
                
                statCard(
                    title: "단어",
                    value: "\(allWords.count)",
                    icon: "textformat.abc",
                    color: .blue
                )
                
                statCard(
                    title: "마스터",
                    value: "\(masteredCount)",
                    icon: "star.fill",
                    color: .green
                )
            }
        }
    }
    
    private var masteredCount: Int {
        allWords.filter { $0.status == .mastered }.count
    }
    
    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(cardBackground)
        .cornerRadius(12)
    }
    
    // MARK: - Level Data Section
    
    private var levelDataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("레벨별 데이터")
                .font(.headline)
            
            ForEach(levels) { level in
                levelRow(level)
            }
        }
    }
    
    private func levelRow(_ level: StudyLevel) -> some View {
        HStack {
            // Level indicator
            Circle()
                .fill(level.isPassed ? Color.green : level.isLocked ? Color.gray : Color.orange)
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(level.displayTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(level.wordCount) 단어")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Progress
            if level.bestScore > 0 {
                Text("\(Int(level.bestScore * 100))%")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
            
            // Status icon
            Image(systemName: level.statusIcon)
                .foregroundStyle(level.isPassed ? .green : .secondary)
        }
        .padding()
        .background(cardBackground)
        .cornerRadius(12)
    }
    
    // MARK: - Data Management Section
    
    private var dataManagementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("데이터 관리")
                .font(.headline)
            
            // Reload Data
            Button(action: reloadData) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(.blue)
                    Text("데이터 새로고침")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(cardBackground)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
            
            // Export (simple version)
            Button(action: exportData) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(.green)
                    Text("데이터 내보내기")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(cardBackground)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Danger Section (DEBUG only)
    
    #if DEBUG
    private var dangerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("위험 영역 (DEBUG)")
                .font(.headline)
                .foregroundStyle(.red)
            
            Button(action: deleteAllData) {
                HStack {
                    Image(systemName: "trash.fill")
                        .foregroundStyle(.red)
                    Text("모든 데이터 삭제")
                        .foregroundStyle(.red)
                    Spacer()
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }
    #endif
    
    // MARK: - Actions
    
    private func reloadData() {
        isLoading = true
        
        Task {
            let stream = await DataLoaderService.shared.stateStream()
            
            // Start loading
            Task {
                await DataLoaderService.shared.loadCurriculumIfNeeded(context: modelContext)
            }
            
            // Monitor state
            for await state in stream {
                await MainActor.run {
                    switch state {
                    case .completed(let count):
                        alertMessage = "데이터 로드 완료: \(count)개 단어"
                        showAlert = true
                        isLoading = false
                        return
                    case .failed(let error):
                        alertMessage = "로드 실패: \(error)"
                        showAlert = true
                        isLoading = false
                        return
                    case .skipped(let reason):
                        alertMessage = "스킵됨: \(reason)"
                        showAlert = true
                        isLoading = false
                        return
                    default:
                        break
                    }
                }
            }
        }
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            if url.startAccessingSecurityScopedResource() {
                defer { url.stopAccessingSecurityScopedResource() }
                
                // Simple import - just show file info
                alertMessage = "파일 선택됨: \(url.lastPathComponent)\n\n참고: 현재 DataLoaderService를 통한 로드를 권장합니다."
                showAlert = true
            }
            
        case .failure(let error):
            alertMessage = "파일 선택 실패: \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    private func exportData() {
        // Simple CSV export
        var csv = "arabic,korean,levelID,status,stability\n"
        
        for word in allWords {
            let arabic = word.arabic.replacingOccurrences(of: ",", with: ";")
            let korean = word.korean.replacingOccurrences(of: ",", with: ";")
            csv += "\(arabic),\(korean),\(word.levelID),\(word.statusRaw),\(word.stability)\n"
        }
        
        let fileName = "arabic_words_export.csv"
        let tempUrl = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try csv.write(to: tempUrl, atomically: true, encoding: .utf8)
            alertMessage = "내보내기 완료: \(tempUrl.path)"
            showAlert = true
        } catch {
            alertMessage = "내보내기 실패: \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    #if DEBUG
    private func deleteAllData() {
        for word in allWords {
            modelContext.delete(word)
        }
        for level in levels {
            modelContext.delete(level)
        }
        try? modelContext.save()
        alertMessage = "모든 데이터가 삭제되었습니다"
        showAlert = true
    }
    #endif
    
    // MARK: - Platform Colors
    
    private var groupedBackground: Color {
        #if os(iOS)
        return Color(uiColor: .systemGroupedBackground)
        #else
        return Color(nsColor: .windowBackgroundColor)
        #endif
    }
    
    private var cardBackground: Color {
        #if os(iOS)
        return Color(uiColor: .systemBackground)
        #else
        return Color(nsColor: .controlBackgroundColor)
        #endif
    }
}

#Preview {
    AdminView()
        .modelContainer(for: [Word.self, StudyLevel.self])
}
