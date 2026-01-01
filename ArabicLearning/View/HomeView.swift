// HomeView.swift
// Simplified Review Dashboard (Legacy Chapter code removed)

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = HomeViewModel()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Stats Summary
                    statsSection
                    
                    // Quick Actions
                    actionSection
                    
                    // Articles / Library
                    if !viewModel.articles.isEmpty {
                        librarySection
                    }
                }
                .padding()
            }
            .background(groupedBackground)
            .navigationTitle("복습")
            .onAppear {
                viewModel.setup(context: modelContext)
            }
            .navigationDestination(isPresented: $viewModel.showReader) {
                if let article = viewModel.selectedArticle {
                    InteractiveReadingView(article: article)
                }
            }
        }
    }
    
    // MARK: - Stats Section
    
    private var statsSection: some View {
        VStack(spacing: 16) {
            // Main Stats Row
            HStack(spacing: 12) {
                statCard(
                    title: "총 단어",
                    value: "\(viewModel.totalWords)",
                    icon: "textformat.abc",
                    color: .blue
                )
                
                statCard(
                    title: "레벨",
                    value: "\(viewModel.totalLevels)",
                    icon: "flag.fill",
                    color: .purple
                )
            }
            
            // Today's Progress
            HStack(spacing: 12) {
                statCard(
                    title: "오늘 학습",
                    value: "\(viewModel.todayTotal)",
                    icon: "calendar",
                    color: .orange
                )
                
                statCard(
                    title: "정답률",
                    value: viewModel.todayTotal > 0 
                        ? "\(Int(Double(viewModel.todayCorrect) / Double(viewModel.todayTotal) * 100))%" 
                        : "-",
                    icon: "checkmark.circle",
                    color: .green
                )
            }
        }
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
    
    // MARK: - Action Section
    
    private var actionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("빠른 학습")
                .font(.headline)
            
            // Navigate to LearningHub for study
            NavigationLink {
                LearningHubView()
            } label: {
                HStack {
                    Image(systemName: "graduationcap.fill")
                        .foregroundStyle(.orange)
                    
                    VStack(alignment: .leading) {
                        Text("학습 허브로 이동")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("레벨 선택 및 일일 학습")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
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
    
    // MARK: - Library Section
    
    private var librarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("📚 읽기 자료")
                    .font(.headline)
                
                Spacer()
                
                Text("\(viewModel.articles.count)개")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            ForEach(viewModel.articles.prefix(3)) { article in
                articleRow(article)
            }
        }
    }
    
    private func articleRow(_ article: Article) -> some View {
        Button(action: { viewModel.selectArticle(article) }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(article.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    
                    Text("\(article.tokens.count) words")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
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
    HomeView()
        .modelContainer(for: [Word.self, StudyLevel.self, QuizHistory.self])
}
