// HomeView - 홈 대시보드
// Premium Design & MVVM Architecture

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = HomeViewModel()
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                #if os(macOS)
                Color(hex: "2D2D2D")
                    .ignoresSafeArea()
                #else
                AnimatedGradientBackground()
                #endif
                
                ScrollView {
                    VStack(spacing: Design.spacingXL) {
                        // Header
                        headerSection
                        
                        // Mode Selection
                        modeSelection
                        
                        // Main Action
                        startStudyCard
                        
                        // Structure Drill (Dual-Column Quiz)
                        structureDrillCard
                        
                        // Chapter Filter Button
                        chapterFilterButton
                        
                        // Stats Grid
                        statsGrid
                        
                        // Library (Reader)
                        librarySection
                        
                        // Streak / Progress
                        streakSection
                    }
                    .padding(.horizontal, Design.spacingL)
                    .padding(.top, Design.spacingL)
                    .padding(.bottom, Design.spacingXXL)
                }
            }
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
            .onAppear {
                viewModel.setup(context: modelContext)
            }
            #if os(iOS)
            .fullScreenCover(isPresented: $viewModel.showStudySession) {
                StudySessionView(mode: viewModel.selectedQuizMode, selectedChapterIds: viewModel.selectedChapterIds, studyLimit: viewModel.selectedStudyCount)
            }
            #else
            .navigationDestination(isPresented: $viewModel.showStudySession) {
                StudySessionView(mode: viewModel.selectedQuizMode, selectedChapterIds: viewModel.selectedChapterIds, studyLimit: viewModel.selectedStudyCount)
            }
            #endif
            .onChange(of: viewModel.showStudySession) { _, isShowing in
                if !isShowing {
                    viewModel.refreshData()
                }
            }
            #if os(macOS)
            .popover(isPresented: $viewModel.showChapterFilter) {
                ChapterFilterSheet(
                    availableChapters: $viewModel.availableChapters,
                    selectedChapterIds: $viewModel.selectedChapterIds,
                    onToggleAll: viewModel.toggleSelectAll,
                    isAllSelected: viewModel.isAllSelected
                )
            }
            #else
            .sheet(isPresented: $viewModel.showChapterFilter) {
                ChapterFilterSheet(
                    availableChapters: $viewModel.availableChapters,
                    selectedChapterIds: $viewModel.selectedChapterIds,
                    onToggleAll: viewModel.toggleSelectAll,
                    isAllSelected: viewModel.isAllSelected
                )
            }
            #endif
            .navigationDestination(isPresented: $viewModel.showReader) {
                if let article = viewModel.selectedArticle {
                    InteractiveReadingView(article: article)
                }
            }
        }
    }
    
    // MARK: - Header
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: Design.spacingXS) {
                Text(viewModel.greetingText)
                    .appFont(AppFont.title2())
                    .foregroundStyle(Color.textPrimary)
                
                Text(Date(), format: .dateTime.weekday(.wide).month().day())
                    .appFont(AppFont.body())
                    .textCase(.uppercase)
                    .foregroundStyle(Color.textSecondary)
            }
            
            Spacer()
            
            // Profile / Settings Button Placeholder
            Button(action: {}) {
                Image(systemName: "gearshape")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.textPrimary)
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
        }
    }
    
    // MARK: - Mode Selection
    private var modeSelection: some View {
        Picker("Mode", selection: $viewModel.selectedQuizMode) {
            ForEach(QuizMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 4)
    }
    
    // MARK: - Main Action Card
    private var startStudyCard: some View {
        VStack(spacing: 16) {
            Button(action: { viewModel.showStudySession = true }) {
                HStack {
                    VStack(alignment: .leading, spacing: Design.spacingS) {
                        Text("Today's Session")
                            .appFont(AppFont.headline())
                            .foregroundStyle(.white.opacity(0.9))
                        
                        Text("Continue Learning")
                            .appFont(AppFont.title1())
                            .foregroundStyle(.white)
                        
                        Text("\(viewModel.selectedStudyCount) Words")
                            .appFont(AppFont.minicaps())
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.top, 4)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.white)
                        .shadow(radius: 10)
                }
                .padding(30)
                .background(
                    ZStack {
                        Design.primaryGradient
                        // Decorative Circles
                        Circle()
                            .fill(.white.opacity(0.1))
                            .frame(width: 150)
                            .offset(x: 100, y: -50)
                        Circle()
                            .fill(.white.opacity(0.1))
                            .frame(width: 100)
                            .offset(x: 120, y: 60)
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: Design.radiusLarge))
                .shadow(color: Design.shadowFloat.color, radius: Design.shadowFloat.radius, y: Design.shadowFloat.y)
            }
            .scaleOnPress()
            
            // Study Count Picker
            HStack(spacing: 12) {
                Text("학습 개수:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                ForEach(HomeViewModel.studyCountOptions, id: \.self) { count in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.selectedStudyCount = count
                        }
                    } label: {
                        Text("\(count)")
                            .font(.subheadline.bold())
                            .foregroundColor(viewModel.selectedStudyCount == count ? .white : .primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(viewModel.selectedStudyCount == count ? Color.primary : Color.gray.opacity(0.15))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Structure Drill Card (Dual-Column Quiz)
    @State private var showStructureDrill: Bool = false
    
    private var structureDrillCard: some View {
        NavigationLink {
            UnifiedStudySessionView(quizState: .bridge)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: Design.spacingS) {
                    HStack(spacing: 6) {
                        Image(systemName: "rectangle.split.2x1.fill")
                            .font(.caption)
                        Text("NEW")
                            .font(.caption2)
                            .fontWeight(.bold)
                    }
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.2))
                    .clipShape(Capsule())
                    
                    Text("구조 훈련")
                        .appFont(AppFont.title2())
                        .foregroundStyle(.white)
                    
                    Text("동사 파생형 • 패턴 인식")
                        .appFont(AppFont.minicaps())
                        .foregroundStyle(.white.opacity(0.8))
                }
                
                Spacer()
                
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.white)
            }
            .padding(24)
            .background(
                LinearGradient(
                    colors: [Color.purple, Color.purple.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: Design.radiusLarge))
            .shadow(color: .purple.opacity(0.3), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Chapter Filter Button
    private var chapterFilterButton: some View {
        Button(action: { viewModel.showChapterFilter = true }) {
            HStack(spacing: 12) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 16, weight: .semibold))
                
                Text("범위 설정")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(viewModel.selectedChaptersCount)개 챕터 선택됨")
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color.textTertiary)
            }
            .foregroundStyle(Color.textPrimary)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: Design.radiusMedium))
            .shadow(color: Design.shadowSofter.color, radius: Design.shadowSofter.radius, y: Design.shadowSofter.y)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Stats Grid
    private var statsGrid: some View {
        HStack(spacing: Design.spacingM) {
            StatCard(
                title: "Words",
                value: "\(viewModel.totalWords)",
                icon: "textformat.abc",
                color: .accent
            )
            
            StatCard(
                title: "Chapters",
                value: "\(viewModel.totalChapters)",
                icon: "folder.fill",
                color: .primaryLight
            )
            
            StatCard(
                title: "Accuracy",
                value: viewModel.accuracyText,
                icon: "chart.bar.fill",
                color: .warning
            )
        }
    }
    
    // MARK: - Library Section
    private var librarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Library")
                    .appFont(AppFont.title2())
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                Button("View All") {
                    // Navigate to full library
                }
                .font(.caption)
                .foregroundStyle(Color.accent)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(viewModel.articles) { article in
                        Button(action: { viewModel.openArticle(article) }) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(article.title)
                                    .appFont(AppFont.headline())
                                    .foregroundStyle(Color.textPrimary)
                                    .lineLimit(1)
                                
                                Text(article.content)
                                    .appFont(AppFont.body())
                                    .foregroundStyle(Color.textSecondary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                            }
                            .padding()
                            .frame(width: 200, height: 120)
                            .glassyCard(cornerRadius: Design.radiusMedium)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
    
    // MARK: - Streak Section
    private var streakSection: some View {
        GlassCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Daily Streak")
                        .appFont(AppFont.headline())
                        .foregroundStyle(Color.textPrimary)
                    
                    Text("\(viewModel.streakDays) Days on fire!")
                        .appFont(AppFont.body())
                        .foregroundStyle(Color.textSecondary)
                }
                
                Spacer()
                
                Image(systemName: "flame.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(Color.orange)
                    .shadow(color: .orange.opacity(0.4), radius: 8)
            }
        }
    }
}

// MARK: - Helper Views
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.system(size: 18, weight: .bold))
            }
            
            Text(value)
                .appFont(AppFont.title3())
                .foregroundStyle(Color.textPrimary)
            
            Text(title)
                .appFont(AppFont.minicaps())
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Design.spacingM)
        .glassyCard(cornerRadius: Design.radiusMedium)
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [VocabularyBook.self, Chapter.self, Word.self, QuizHistory.self])
}
