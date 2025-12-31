// PassageReadingView.swift
// Sentence-by-Sentence Reader with Conditional Highlighting and Add-to-Study

import SwiftUI
import SwiftData

struct PassageReadingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let level: StudyLevel
    
    // Sentence Navigation
    @State private var sentences: [SentenceData] = []
    @State private var currentIndex = 0
    
    // Word Lookup
    @State private var selectedWord: Word?
    @State private var showWordDetail = false
    @State private var knownWords: Set<String> = []  // Normalized words in DB
    @State private var wordMap: [String: Word] = [:] // For quick lookup
    
    // Add to Study feedback
    @State private var showAddedFeedback = false
    @State private var addedWordName = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if sentences.isEmpty {
                    emptyStateView
                } else {
                    sentenceView
                }
            }
            .background(groupedBackground)
            .navigationTitle("읽기 연습")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
                
                if !sentences.isEmpty {
                    ToolbarItem(placement: .principal) {
                        Text("\(currentIndex + 1) / \(sentences.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onAppear {
                loadKnownWords()
                loadSentences()
            }
            .sheet(isPresented: $showWordDetail) {
                if let word = selectedWord {
                    WordDetailSheet(
                        word: word,
                        onAddToStudy: { addWordToStudy(word) }
                    )
                }
            }
            .overlay(alignment: .top) {
                if showAddedFeedback {
                    addedFeedbackBanner
                }
            }
        }
    }
    
    // MARK: - Added Feedback Banner
    
    private var addedFeedbackBanner: some View {
        HStack {
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(.white)
            Text("\"\(addedWordName)\" 학습에 추가됨")
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.green)
        .cornerRadius(20)
        .shadow(radius: 5)
        .padding(.top, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    // MARK: - Sentence View
    
    private var sentenceView: some View {
        VStack(spacing: 0) {
            // Progress Bar
            ProgressView(value: Double(currentIndex + 1), total: Double(sentences.count))
                .tint(.green)
                .padding(.horizontal)
                .padding(.top, 8)
            
            Spacer()
            
            // Main Content
            if currentIndex < sentences.count {
                let sentence = sentences[currentIndex]
                
                VStack(spacing: 24) {
                    // Arabic Sentence with Tappable Words
                    FlowLayoutConditional(
                        words: sentence.arabicWords,
                        knownWords: knownWords,
                        onWordTap: { word in
                            lookupWord(word)
                        }
                    )
                    .padding()
                    .background(cardBackground)
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    // Translation (Parentheses removed)
                    Text(sentence.translation.removingParenthesesContent)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
            
            Spacer()
            
            // Hint
            hintView
            
            // Navigation Buttons
            navigationButtons
        }
    }
    
    // MARK: - Hint
    
    private var hintView: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.blue)
                .frame(width: 8, height: 8)
            Text("파란색 단어를 탭하면 의미 확인 및 학습 추가 가능")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Navigation Buttons
    
    private var navigationButtons: some View {
        HStack(spacing: 16) {
            // Previous
            Button(action: previousSentence) {
                HStack {
                    Image(systemName: "chevron.left")
                    Text("이전")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(currentIndex == 0 ? Color.gray.opacity(0.2) : Color.blue.opacity(0.1))
                .foregroundColor(currentIndex == 0 ? .secondary : Color.blue)
                .cornerRadius(12)
            }
            .disabled(currentIndex == 0)
            
            // Next
            Button(action: nextSentence) {
                HStack {
                    Text(currentIndex >= sentences.count - 1 ? "완료" : "다음")
                    Image(systemName: currentIndex >= sentences.count - 1 ? "checkmark" : "chevron.right")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundStyle(.white)
                .cornerRadius(12)
            }
        }
        .padding()
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("읽기 자료가 없습니다")
                .font(.headline)
            
            Text("레벨 테스트를 먼저 진행해보세요!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Button("닫기") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .padding(.top)
        }
        .padding()
    }
    
    // MARK: - Data Loading
    
    private func loadKnownWords() {
        // Load all words for this level and normalize them
        let levelID = level.levelID
        let descriptor = FetchDescriptor<Word>(
            predicate: #Predicate { $0.levelID == levelID }
        )
        
        if let words = try? modelContext.fetch(descriptor) {
            for word in words {
                let normalized = ArabicUtils.normalize(word.arabic)
                knownWords.insert(normalized)
                wordMap[normalized] = word
            }
        }
    }
    
    private func loadSentences() {
        // Try loading from JSON first
        if let url = Bundle.main.url(forResource: "reading_passages", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let passages = try? JSONDecoder().decode([ReadingPassageData].self, from: data) {
            
            let levelPassages = passages.filter { $0.level == level.levelID }
            
            for passage in levelPassages {
                let arabicSentences = passage.content.sentences
                let translationSentences = passage.translation.sentences
                
                for (i, arabic) in arabicSentences.enumerated() {
                    let translation = i < translationSentences.count ? translationSentences[i] : ""
                    sentences.append(SentenceData(
                        arabic: arabic,
                        translation: translation
                    ))
                }
            }
        }
        
        // If no passages, generate from example sentences
        if sentences.isEmpty {
            generateFromExamples()
        }
    }
    
    private func generateFromExamples() {
        let levelID = level.levelID
        var descriptor = FetchDescriptor<Word>(
            predicate: #Predicate { $0.levelID == levelID }
        )
        descriptor.fetchLimit = 30
        
        if let words = try? modelContext.fetch(descriptor) {
            for word in words where !word.exampleSentence.isEmpty {
                sentences.append(SentenceData(
                    arabic: word.exampleSentence,
                    translation: word.sentenceKorean
                ))
            }
        }
    }
    
    // MARK: - Word Lookup
    
    private func lookupWord(_ tappedWord: String) {
        let normalized = ArabicUtils.normalize(tappedWord)
        
        guard let word = wordMap[normalized] else { return }
        
        selectedWord = word
        showWordDetail = true
    }
    
    // MARK: - Add to Study
    
    private func addWordToStudy(_ word: Word) {
        // Mark as user-added
        word.isUserAdded = true
        word.addedFromLevelID = level.levelID
        
        // Change status to learning if still new
        if word.status == .new {
            word.status = .learning
        }
        
        try? modelContext.save()
        
        // Show feedback
        addedWordName = word.arabic
        withAnimation(.spring()) {
            showAddedFeedback = true
        }
        
        // Hide after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showAddedFeedback = false
            }
        }
        
        // Dismiss sheet
        showWordDetail = false
    }
    
    // MARK: - Navigation
    
    private func previousSentence() {
        guard currentIndex > 0 else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            currentIndex -= 1
        }
    }
    
    private func nextSentence() {
        if currentIndex >= sentences.count - 1 {
            dismiss()
        } else {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentIndex += 1
            }
        }
    }
    
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

// MARK: - Sentence Data Model

struct SentenceData: Identifiable {
    let id = UUID()
    let arabic: String
    let translation: String
    
    var arabicWords: [String] {
        arabic.arabicWords
    }
}

// MARK: - Conditional Highlighting Flow Layout

struct FlowLayoutConditional: View {
    let words: [String]
    let knownWords: Set<String>
    let onWordTap: (String) -> Void
    
    var body: some View {
        FlowLayout(alignment: .trailing, spacing: 8) {
            ForEach(Array(words.enumerated()), id: \.offset) { _, word in
                let normalized = ArabicUtils.normalize(word)
                let isKnown = knownWords.contains(normalized)
                
                Text(word)
                    .font(.system(size: 28, weight: isKnown ? .semibold : .regular))
                    .foregroundStyle(isKnown ? .blue : .primary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(isKnown ? Color.blue.opacity(0.1) : Color.clear)
                    .cornerRadius(6)
                    .onTapGesture {
                        if isKnown {
                            onWordTap(word)
                        }
                    }
                    .allowsHitTesting(isKnown)
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
}

// MARK: - Word Detail Sheet with Add Button

struct WordDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let word: Word
    let onAddToStudy: () -> Void
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Arabic Word
                    Text(word.arabic)
                        .font(.system(size: 48))
                        .frame(maxWidth: .infinity)
                        .padding()
                    
                    // Meaning
                    DetailCard(
                        label: "의미",
                        icon: "text.book.closed",
                        content: word.korean,
                        color: .blue
                    )
                    
                    // Root
                    if let root = word.root, !root.isEmpty {
                        DetailCard(
                            label: "어근",
                            icon: "tree",
                            content: root,
                            color: .green
                        )
                    }
                    
                    // Verb Form
                    if let verbForm = word.verbForm, verbForm > 0 {
                        DetailCard(
                            label: "동사형",
                            icon: "textformat",
                            content: "\(verbForm)형",
                            color: .orange
                        )
                    }
                    
                    // Example
                    if !word.exampleSentence.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("예문", systemImage: "quote.bubble")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Text(word.exampleSentence)
                                .font(.body)
                                .environment(\.layoutDirection, .rightToLeft)
                            
                            if !word.sentenceKorean.isEmpty {
                                Text(word.sentenceKorean.removingParenthesesContent)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    Spacer(minLength: 20)
                    
                    // Add to Study Button
                    if !word.isUserAdded {
                        addToStudyButton
                    } else {
                        alreadyAddedBadge
                    }
                }
                .padding()
            }
            .navigationTitle("단어 상세")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }
    
    private var addToStudyButton: some View {
        Button(action: onAddToStudy) {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("학습에 추가")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.orange)
            .foregroundStyle(.white)
            .cornerRadius(12)
        }
    }
    
    private var alreadyAddedBadge: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
            Text("이미 학습에 추가됨")
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.green.opacity(0.2))
        .foregroundStyle(.green)
        .cornerRadius(12)
    }
}

// MARK: - Detail Card

struct DetailCard: View {
    let label: String
    let icon: String
    let content: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(label, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text(content)
                .font(.title3)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Reading Passage Data

struct ReadingPassageData: Codable, Identifiable {
    var id: String { title }
    let title: String
    let content: String
    let translation: String
    let level: Int
}

#Preview {
    PassageReadingView(level: StudyLevel(levelID: 1, title: "기초"))
        .modelContainer(for: Word.self)
}
