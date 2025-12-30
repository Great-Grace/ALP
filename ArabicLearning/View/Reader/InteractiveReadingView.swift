// InteractiveReadingView.swift
// Main Container for the Reading Experience
// Features: X-Ray Highlighting, Flow Layout, Bottom Sheet with VerbForm Lookup

import SwiftUI
import SwiftData

struct InteractiveReadingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let article: Article
    
    // State
    @State private var selectedToken: ArticleToken?
    @State private var selectedTokenIndex: Int = 0
    @State private var activeRootID: UUID?
    @State private var showMorphologySheet: Bool = false
    @State private var fetchedVerbForm: VerbForm?
    @State private var wordAddedStatus: WordAddedStatus = .notAdded
    
    enum WordAddedStatus {
        case notAdded
        case added
        case alreadyExists
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(article.title)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        if let source = article.source {
                            Text(source)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.bottom, 10)
                    
                    // Reader Content
                    FlowLayout(alignment: .leading, spacing: 6) {
                        ForEach(Array(article.tokens.enumerated()), id: \.element.id) { index, token in
                            TokenView(
                                token: token,
                                state: visualState(for: token),
                                onTap: { handleTap(token, at: index) }
                            )
                        }
                    }
                    .environment(\.layoutDirection, .rightToLeft) // Arabic RTL
                }
                .padding()
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showMorphologySheet, onDismiss: {
                // Reset status when sheet closes
                wordAddedStatus = .notAdded
            }) {
                if let token = selectedToken {
                    MorphologyCard(
                        token: token,
                        verbForm: fetchedVerbForm,
                        addedStatus: wordAddedStatus,
                        onAdd: { addToVocabulary() }
                    )
                    .presentationDetents([.fraction(0.5)])
                }
            }
        }
    }
    
    // MARK: - Logic
    
    private func handleTap(_ token: ArticleToken, at index: Int) {
        // Toggle if tapping same token
        if selectedToken?.id == token.id {
            resetSelection()
            return
        }
        
        selectedToken = token
        selectedTokenIndex = index
        wordAddedStatus = .notAdded
        
        // Check if word already exists in vocabulary
        checkIfWordExists(cleanText: token.cleanText)
        
        // Activate "X-Ray" if root exists
        if let rootId = token.rootId {
            activeRootID = rootId
            fetchVerbForm(by: rootId)
        } else {
            activeRootID = nil
            lookupVerbFormByText(cleanText: token.cleanText)
        }
        
        showMorphologySheet = true
    }
    
    /// Check if word already exists in vocabulary
    private func checkIfWordExists(cleanText: String) {
        let text = cleanText
        let descriptor = FetchDescriptor<Word>(
            predicate: #Predicate { $0.arabicClean == text }
        )
        if let _ = try? modelContext.fetch(descriptor).first {
            wordAddedStatus = .alreadyExists
        }
    }
    
    /// Fetch VerbForm by UUID (if token has rootId)
    private func fetchVerbForm(by id: UUID) {
        let descriptor = FetchDescriptor<VerbForm>(
            predicate: #Predicate { $0.id == id }
        )
        fetchedVerbForm = try? modelContext.fetch(descriptor).first
    }
    
    /// Fallback: Lookup VerbForm by matching arabicWordClean to token text
    private func lookupVerbFormByText(cleanText: String) {
        let text = cleanText
        let descriptor = FetchDescriptor<VerbForm>(
            predicate: #Predicate { $0.arabicWordClean == text }
        )
        fetchedVerbForm = try? modelContext.fetch(descriptor).first
    }
    
    /// Add word to vocabulary
    private func addToVocabulary() {
        guard let token = selectedToken else { return }
        
        let result = VocabularyService.addToVocabulary(
            token: token,
            verbForm: fetchedVerbForm,
            article: article,
            tokenIndex: selectedTokenIndex,
            context: modelContext
        )
        
        switch result {
        case .added:
            wordAddedStatus = .added
            triggerHapticFeedback()
        case .alreadyExists:
            wordAddedStatus = .alreadyExists
        case .failed(let error):
            print("Failed to add word: \(error)")
        }
    }
    
    private func triggerHapticFeedback() {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
    }
    
    private func resetSelection() {
        selectedToken = nil
        activeRootID = nil
        fetchedVerbForm = nil
        showMorphologySheet = false
        wordAddedStatus = .notAdded
    }
    
    private func visualState(for token: ArticleToken) -> TokenVisualState {
        guard let selected = selectedToken else {
            return token.isTargetWord ? .target : .normal
        }
        
        if token.id == selected.id {
            return .highlighted
        }
        
        if let activeRoot = activeRootID, token.rootId == activeRoot {
            return .highlighted
        }
        
        return .dimmed
    }
}
