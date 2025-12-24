// CreateBookView - 단어장 직접 생성
// SayVoca 스타일 단어장 만들기 플로우

import SwiftUI
import SwiftData

struct CreateBookView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allWords: [Word]
    
    @State private var bookName = ""
    @State private var selectedWordIds: Set<UUID> = []
    @State private var step: CreateStep = .naming
    @State private var searchText = ""
    
    enum CreateStep {
        case naming
        case selectingWords
    }
    
    var filteredWords: [Word] {
        if searchText.isEmpty {
            return allWords
        }
        return allWords.filter {
            $0.korean.localizedCaseInsensitiveContains(searchText) ||
            $0.arabic.contains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .naming:
                    nameInputView
                case .selectingWords:
                    wordSelectionView
                }
            }
            .navigationTitle(step == .naming ? "단어장 만들기" : "단어 선택")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        dismiss()
                    }
                    .foregroundStyle(Color.textSecondary)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    if step == .selectingWords {
                        Button("완료 (\(selectedWordIds.count))") {
                            createBook()
                        }
                        .fontWeight(.semibold)
                        .disabled(selectedWordIds.isEmpty)
                    }
                }
            }
        }
    }
    
    // MARK: - Step 1: Name Input
    private var nameInputView: some View {
        VStack(spacing: Design.spacingXL) {
            Spacer()
            
            // Icon
            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.primary)
            }
            
            // Title
            Text("단어장 이름을 입력하세요")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(Color.textPrimary)
            
            // Input Field
            TextField("예: 나만의 단어장", text: $bookName)
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding()
                .background(Color.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: Design.radiusMedium))
                .overlay(
                    RoundedRectangle(cornerRadius: Design.radiusMedium)
                        .stroke(Color.textTertiary.opacity(0.3), lineWidth: 1)
                )
                .padding(.horizontal, Design.spacingXL)
            
            Spacer()
            
            // Next Button
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    step = .selectingWords
                }
            }) {
                Text("다음")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(bookName.isEmpty ? Color.textTertiary : Color.primary)
                    .clipShape(RoundedRectangle(cornerRadius: Design.radiusMedium))
            }
            .disabled(bookName.isEmpty)
            .padding(.horizontal, Design.spacingL)
            .padding(.bottom, Design.spacingL)
        }
        .background(Color.backgroundPrimary)
    }
    
    // MARK: - Step 2: Word Selection
    private var wordSelectionView: some View {
        VStack(spacing: 0) {
            // Search Bar
            HStack(spacing: Design.spacingS) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.textTertiary)
                
                TextField("단어 검색", text: $searchText)
                    .font(.body)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.textTertiary)
                    }
                }
            }
            .padding(Design.spacingM)
            .background(Color.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: Design.radiusMedium))
            .padding(.horizontal, Design.spacingL)
            .padding(.vertical, Design.spacingM)
            
            // Selection Info
            HStack {
                Text("\(selectedWordIds.count)개 선택됨")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.accent)
                
                Spacer()
                
                if !selectedWordIds.isEmpty {
                    Button("선택 해제") {
                        selectedWordIds.removeAll()
                    }
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
                }
            }
            .padding(.horizontal, Design.spacingL)
            .padding(.bottom, Design.spacingS)
            
            Divider()
            
            // Word List
            if filteredWords.isEmpty {
                emptyWordsView
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredWords) { word in
                            wordSelectionRow(word: word)
                            Divider()
                                .padding(.leading, 60)
                        }
                    }
                }
            }
        }
        .background(Color.backgroundPrimary)
    }
    
    private var emptyWordsView: some View {
        VStack(spacing: Design.spacingM) {
            Spacer()
            
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(Color.textTertiary)
            
            Text("선택할 수 있는 단어가 없습니다")
                .font(.headline)
                .foregroundStyle(Color.textSecondary)
            
            Text("먼저 CSV 파일을 가져오거나\n샘플 데이터를 로드해주세요")
                .font(.subheadline)
                .foregroundStyle(Color.textTertiary)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
    }
    
    private func wordSelectionRow(word: Word) -> some View {
        Button(action: {
            toggleSelection(word.id)
        }) {
            HStack(spacing: Design.spacingM) {
                // Selection Indicator
                ZStack {
                    Circle()
                        .stroke(selectedWordIds.contains(word.id) ? Color.accent : Color.textTertiary.opacity(0.5), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if selectedWordIds.contains(word.id) {
                        Circle()
                            .fill(Color.accent)
                            .frame(width: 16, height: 16)
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(word.arabic)
                            .font(.body)
                            .fontWeight(.medium)
                            .environment(\.layoutDirection, .rightToLeft)
                        
                        Spacer()
                    }
                    
                    Text(word.korean)
                        .font(.subheadline)
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .padding(.horizontal, Design.spacingL)
            .padding(.vertical, Design.spacingM)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(selectedWordIds.contains(word.id) ? Color.accent.opacity(0.08) : Color.clear)
    }
    
    // MARK: - Actions
    private func toggleSelection(_ id: UUID) {
        withAnimation(.easeInOut(duration: 0.15)) {
            if selectedWordIds.contains(id) {
                selectedWordIds.remove(id)
            } else {
                selectedWordIds.insert(id)
            }
        }
    }
    
    private func createBook() {
        // Create new vocabulary book
        let newBook = VocabularyBook(name: bookName)
        modelContext.insert(newBook)
        
        // Create a single chapter for the custom book
        let chapter = Chapter(
            name: "커스텀 단어",
            orderIndex: 1,
            book: newBook
        )
        modelContext.insert(chapter)
        
        // Add selected words to the chapter (copy references)
        for word in allWords where selectedWordIds.contains(word.id) {
            // Create new word instance linked to the new chapter
            let newWord = Word(
                arabic: word.arabic,
                korean: word.korean,
                exampleSentence: word.exampleSentence,
                sentenceKorean: word.sentenceKorean,
                chapter: chapter
            )
            modelContext.insert(newWord)
        }
        
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Preview
#Preview {
    CreateBookView()
        .modelContainer(for: [VocabularyBook.self, Chapter.self, Word.self])
}
