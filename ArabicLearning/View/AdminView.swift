// AdminView - 관리자 화면
// Accordion UI with VocabularyBook Management

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct AdminView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \VocabularyBook.createdAt, order: .reverse) private var books: [VocabularyBook]
    @Query private var allWords: [Word]
    
    @State private var expandedBookId: UUID?
    @State private var showCreateBookSheet = false
    @State private var showImportSheet = false
    @State private var showDeleteConfirm = false
    @State private var bookToDelete: VocabularyBook?
    @State private var alertMessage = ""
    @State private var showAlert = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: Design.spacingM) {
                    // 데이터 현황
                    statsSection
                        .padding(.bottom, Design.spacingS)
                    
                    // 단어장 목록 (Accordion)
                    if books.isEmpty {
                        emptyBooksView
                    } else {
                        vocabularyBooksSection
                    }
                    
                    // 위험 영역 (DEBUG 빌드만)
                    #if DEBUG
                    dangerSection
                        .padding(.top, Design.spacingL)
                    #endif
                }
                .padding(Design.spacingL)
            }
            .background(Color.backgroundPrimary)
            .navigationTitle("관리")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(action: { showCreateBookSheet = true }) {
                            Label("직접 단어장 만들기", systemImage: "plus.circle")
                        }
                        Button(action: { showImportSheet = true }) {
                            Label("파일 가져오기", systemImage: "doc.badge.plus")
                        }
                        Divider()
                        Button(action: loadDefaultData) {
                            Label("샘플 데이터 로드", systemImage: "tray.and.arrow.down")
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.primary)
                    }
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    if !allWords.isEmpty {
                        ShareLink(item: generateExportFile(), preview: SharePreview("Database Export", image: Image(systemName: "tablecells"))) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.body)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.accent)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showCreateBookSheet) {
            CreateBookView()
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
        .alert("단어장 삭제", isPresented: $showDeleteConfirm) {
            Button("취소", role: .cancel) { bookToDelete = nil }
            Button("삭제", role: .destructive) {
                if let book = bookToDelete {
                    deleteBook(book)
                }
            }
        } message: {
            Text("'\(bookToDelete?.name ?? "")'을(를) 삭제하시겠습니까?\n모든 챕터와 단어가 함께 삭제됩니다.")
        }
    }
    
    // MARK: - Stats Section
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: Design.spacingM) {
            Text("데이터 현황")
                .font(.headline)
                .foregroundStyle(Color.textPrimary)
            
            HStack(spacing: Design.spacingM) {
                modernStatCard(
                    title: "단어장",
                    value: "\(books.count)",
                    icon: "books.vertical.fill",
                    color: .primary
                )
                
                modernStatCard(
                    title: "단어",
                    value: "\(allWords.count)",
                    icon: "textformat.abc",
                    color: .accent
                )
            }
        }
    }
    
    private func modernStatCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: Design.spacingS) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
            }
            
            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(Color.textPrimary)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
    }
    
    // MARK: - Empty Books View
    private var emptyBooksView: some View {
        VStack(spacing: Design.spacingM) {
            ZStack {
                Circle()
                    .fill(Color.textTertiary.opacity(0.15))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "books.vertical")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.textSecondary)
            }
            
            Text("단어장이 없습니다")
                .font(.headline)
                .foregroundStyle(Color.textPrimary)
            
            Text("우측 상단 + 버튼을 눌러\n단어장을 추가해보세요")
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Design.spacingXL)
        .cardStyle()
    }
    
    // MARK: - Vocabulary Books Section (Accordion)
    private var vocabularyBooksSection: some View {
        VStack(alignment: .leading, spacing: Design.spacingM) {
            Text("단어장")
                .font(.headline)
                .foregroundStyle(Color.textPrimary)
            
            ForEach(books) { book in
                VStack(spacing: 0) {
                    // Book Header (Collapsible)
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            if expandedBookId == book.id {
                                expandedBookId = nil
                            } else {
                                expandedBookId = book.id
                            }
                        }
                    }) {
                        bookHeaderRow(book: book)
                    }
                    .buttonStyle(.plain)
                    
                    // Expanded Chapters
                    if expandedBookId == book.id {
                        VStack(spacing: 0) {
                            Divider()
                                .padding(.horizontal, Design.spacingM)
                            
                            if book.chapters.isEmpty {
                                emptyChaptersRow
                            } else {
                                ForEach(book.sortedChapters) { chapter in
                                    NavigationLink(destination: ChapterDetailView(chapter: chapter)) {
                                        chapterRow(chapter: chapter)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .cardStyle(padding: 0)
            }
        }
    }
    
    private func bookHeaderRow(book: VocabularyBook) -> some View {
        HStack(spacing: Design.spacingM) {
            ZStack {
                RoundedRectangle(cornerRadius: Design.radiusSmall)
                    .fill(Color.primary.opacity(0.12))
                    .frame(width: 48, height: 48)
                
                Image(systemName: book.isDefault ? "book.closed.fill" : "books.vertical.fill")
                    .font(.title3)
                    .foregroundStyle(Color.primary)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(book.name)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.textPrimary)
                    
                    if book.isDefault {
                        Text("기본")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.primary)
                            .clipShape(Capsule())
                    }
                }
                
                Text("\(book.chapters.count)개 챕터 · \(book.wordCount)개 단어")
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
            }
            
            Spacer()
            
            // Delete button (non-default only)
            if !book.isDefault {
                Button(action: {
                    bookToDelete = book
                    showDeleteConfirm = true
                }) {
                    Image(systemName: "trash")
                        .font(.body)
                        .foregroundStyle(Color.error.opacity(0.7))
                }
                .padding(.trailing, 4)
            }
            
            Image(systemName: expandedBookId == book.id ? "chevron.up" : "chevron.down")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.textTertiary)
        }
        .padding(Design.spacingM)
    }
    
    private var emptyChaptersRow: some View {
        HStack {
            Spacer()
            Text("챕터가 없습니다")
                .font(.subheadline)
                .foregroundStyle(Color.textTertiary)
            Spacer()
        }
        .padding(Design.spacingM)
    }
    
    private func chapterRow(chapter: Chapter) -> some View {
        HStack(spacing: Design.spacingM) {
            ZStack {
                Circle()
                    .fill(Color.accent.opacity(0.12))
                    .frame(width: 36, height: 36)
                
                Text("\(chapter.orderIndex)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.accent)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(chapter.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.textPrimary)
                
                Text("\(chapter.words.count)개 단어")
                    .font(.caption)
                    .foregroundStyle(Color.textTertiary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Color.textTertiary)
        }
        .padding(.horizontal, Design.spacingM)
        .padding(.vertical, Design.spacingS)
        .background(Color.backgroundSecondary.opacity(0.5))
    }
    
    // MARK: - Danger Section (DEBUG only)
    #if DEBUG
    private var dangerSection: some View {
        VStack(alignment: .leading, spacing: Design.spacingM) {
            Text("위험 영역 (DEBUG)")
                .font(.headline)
                .foregroundStyle(Color.error)
            
            Button(action: { showDeleteAllConfirm() }) {
                HStack(spacing: Design.spacingM) {
                    ZStack {
                        RoundedRectangle(cornerRadius: Design.radiusSmall)
                            .fill(Color.error.opacity(0.12))
                            .frame(width: 48, height: 48)
                        
                        Image(systemName: "trash.fill")
                            .font(.title3)
                            .foregroundStyle(Color.error)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("모든 데이터 삭제")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.error)
                        
                        Text("단어장, 단어, 퀴즈 기록 초기화")
                            .font(.caption)
                            .foregroundStyle(Color.textSecondary)
                    }
                    
                    Spacer()
                }
                .padding(Design.spacingM)
            }
            .buttonStyle(.plain)
            .cardStyle(padding: 0)
            .overlay(
                RoundedRectangle(cornerRadius: Design.radiusLarge)
                    .stroke(Color.error.opacity(0.25), lineWidth: 1)
            )
            .scaleOnPress()
        }
    }
    #endif
    
    // MARK: - Actions
    private func loadDefaultData() {
        do {
            let count = try CSVDataLoader.loadSampleData(context: modelContext)
            alertMessage = "샘플 데이터 로드 완료: \(count)개 단어"
            showAlert = true
        } catch {
            alertMessage = "데이터 로드 실패: \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            if url.startAccessingSecurityScopedResource() {
                defer { url.stopAccessingSecurityScopedResource() }
                
                do {
                    let csvString = try String(contentsOf: url, encoding: .utf8)
                    let bookName = url.deletingPathExtension().lastPathComponent
                    let count = try CSVDataLoader.importCSVAsBook(csvString, bookName: bookName, context: modelContext)
                    alertMessage = "'\(bookName)' 단어장에 \(count)개의 단어를 가져왔습니다!"
                } catch {
                    alertMessage = "CSV 로드 실패: \(error.localizedDescription)"
                }
                showAlert = true
            }
            
        case .failure(let error):
            alertMessage = "파일 선택 실패: \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    private func deleteBook(_ book: VocabularyBook) {
        modelContext.delete(book)
        try? modelContext.save()
        bookToDelete = nil
    }
    
    private func showDeleteAllConfirm() {
        alertMessage = "정말 모든 데이터를 삭제하시겠습니까?"
        // TODO: Implement full delete with separate confirmation
    }
    
    // MARK: - Export Helper
    private func generateExportFile() -> URL {
        let csvString = CSVDataExporter.generateFullCSV(from: allWords)
        let fileName = "ArabicWords_FullDump_\(Date().formatted(date: .numeric, time: .omitted)).csv"
        let tempUrl = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        try? csvString.write(to: tempUrl, atomically: true, encoding: .utf8)
        return tempUrl
    }
}

// MARK: - Chapter Detail View
struct ChapterDetailView: View {
    let chapter: Chapter
    
    var body: some View {
        List {
            ForEach(chapter.sortedWords) { word in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(word.arabic)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .environment(\.layoutDirection, .rightToLeft)
                        
                        // [Debug] Show Clean Version
                        Text("[\(word.arabicClean)]")
                            .font(.caption2)
                            .foregroundStyle(Color.textTertiary)
                            .padding(.leading, 4)
                        
                        Spacer()
                    }
                    
                    Text(word.korean)
                        .font(.body)
                        .foregroundStyle(Color.textPrimary)
                    
                    Text(word.exampleSentence)
                        .font(.caption)
                        .foregroundStyle(Color.textTertiary)
                        .environment(\.layoutDirection, .rightToLeft)
                    
                    Text("Clean: \(word.sentenceClean)")
                        .font(.caption2)
                        .foregroundStyle(Color.textTertiary.opacity(0.5))
                        .environment(\.layoutDirection, .rightToLeft)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle(chapter.name)
    }
}

// MARK: - Preview
#Preview {
    AdminView()
        .modelContainer(for: [VocabularyBook.self, Chapter.self, Word.self, QuizHistory.self])
}
