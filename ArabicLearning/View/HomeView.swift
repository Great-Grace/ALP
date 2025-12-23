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
                AnimatedGradientBackground()
                
                ScrollView {
                    VStack(spacing: Design.spacingXL) {
                        // Header
                        headerSection
                        
                        // Main Action
                        startStudyCard
                        
                        // Stats Grid
                        statsGrid
                        
                        // Streak / Progress
                        streakSection
                    }
                    .padding(.horizontal, Design.spacingL)
                    .padding(.top, Design.spacingL)
                    .padding(.bottom, Design.spacingXXL)
                }
            }
            .navigationBarTitleDisplayMode(.hidden)
            .onAppear {
                viewModel.setup(context: modelContext)
            }
            .fullScreenCover(isPresented: $viewModel.showStudySession) {
                StudySessionView()
            }
            .onChange(of: viewModel.showStudySession) { _, isShowing in
                if !isShowing {
                    viewModel.refreshData()
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
    
    // MARK: - Main Action Card
    private var startStudyCard: some View {
        Button(action: { viewModel.showStudySession = true }) {
            HStack {
                VStack(alignment: .leading, spacing: Design.spacingS) {
                    Text("Today's Session")
                        .appFont(AppFont.headline())
                        .foregroundStyle(.white.opacity(0.9))
                    
                    Text("Continue Learning")
                        .appFont(AppFont.title1())
                        .foregroundStyle(.white)
                    
                    Text("20 Words • 5 Min")
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
