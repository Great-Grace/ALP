// HomeView - 메인 홈 화면
// 피그마 디자인 기반 SwiftUI 구현

import SwiftUI

struct HomeView: View {
    // MARK: - Dummy Data
    @State private var streakDays: Int = 0
    @State private var todayProgress: Double = 0.0
    @State private var selectedTab: Int = 0
    @State private var completedDays: Set<String> = []
    
    private let weekdays = ["월", "화", "수", "목", "금", "토", "일"]
    
    var body: some View {
        VStack(spacing: 0) {
            // 메인 콘텐츠
            ScrollView {
                VStack(spacing: 20) {
                    // 상단 네비게이션 바
                    navigationBar
                    
                    // 연속 학습일 카드
                    streakCard
                    
                    // 오늘의 학습 카드
                    todayStudyCard
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
            }
            
            // 하단 탭바
            bottomTabBar
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Navigation Bar
    private var navigationBar: some View {
        HStack(spacing: 16) {
            // 뒤로가기 버튼
            Button(action: {}) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundStyle(.primary)
            }
            
            // 별 아이콘
            Image(systemName: "star")
                .font(.title3)
                .foregroundStyle(.secondary)
            
            // 프로그레스 바
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray4))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.blue)
                        .frame(width: geometry.size.width * todayProgress, height: 8)
                }
            }
            .frame(height: 8)
            
            // 설정 버튼
            Button(action: {}) {
                VStack(spacing: 2) {
                    Image(systemName: "gearshape")
                        .font(.title3)
                    Text("setting")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 10)
    }
    
    // MARK: - Streak Card (연속 학습일)
    private var streakCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                // Fire 아이콘
                ZStack {
                    Circle()
                        .stroke(Color(.systemGray3), lineWidth: 2)
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: "flame")
                        .font(.system(size: 24))
                        .foregroundStyle(.orange)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    // 연속 학습일 텍스트
                    Text("연속학습 \(streakDays)일")
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    // 요일 버튼들
                    HStack(spacing: 8) {
                        ForEach(weekdays, id: \.self) { day in
                            DayCircleButton(
                                day: day,
                                isCompleted: completedDays.contains(day)
                            )
                        }
                    }
                }
                
                Spacer()
            }
            .padding(20)
        }
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Today Study Card (오늘의 학습)
    private var todayStudyCard: some View {
        VStack(spacing: 20) {
            HStack(spacing: 20) {
                // Play 버튼 + 오늘의 학습
                Button(action: {}) {
                    HStack(spacing: 12) {
                        Image(systemName: "play.fill")
                            .font(.title2)
                        
                        Text("오늘의 학습")
                            .font(.headline)
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.systemGray3), lineWidth: 1)
                    )
                }
                
                Spacer()
                
                // Circular Progress
                CircularProgressView(progress: todayProgress)
                    .frame(width: 80, height: 80)
            }
            .padding(20)
        }
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Bottom Tab Bar
    private var bottomTabBar: some View {
        HStack {
            Spacer()
            
            // 홈 탭
            Button(action: { selectedTab = 0 }) {
                Text("홈")
                    .font(.headline)
                    .foregroundStyle(selectedTab == 0 ? .primary : .secondary)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.systemGray3), lineWidth: selectedTab == 0 ? 2 : 1)
                    )
            }
            
            Spacer()
            
            // 내 정보 탭
            Button(action: { selectedTab = 1 }) {
                Text("내 정보")
                    .font(.headline)
                    .foregroundStyle(selectedTab == 1 ? .primary : .secondary)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.systemGray3), lineWidth: selectedTab == 1 ? 2 : 1)
                    )
            }
            
            Spacer()
        }
        .padding(.vertical, 16)
        .background(Color(.systemGray6))
    }
}

// MARK: - Day Circle Button
struct DayCircleButton: View {
    let day: String
    let isCompleted: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(isCompleted ? Color.orange : Color(.systemGray3), lineWidth: 1.5)
                .frame(width: 32, height: 32)
            
            Text(day)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(isCompleted ? .orange : .primary)
        }
    }
}

// MARK: - Circular Progress View
struct CircularProgressView: View {
    let progress: Double
    
    var body: some View {
        ZStack {
            // 배경 원
            Circle()
                .stroke(Color(.systemGray4), lineWidth: 4)
            
            // 프로그레스 원
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    Color.blue,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            
            // 퍼센트 텍스트
            Text("\(Int(progress * 100)) %")
                .font(.system(size: 16, weight: .medium))
        }
    }
}

// MARK: - Preview
#Preview("Home View") {
    HomeView()
}

#Preview("Home View - With Data") {
    HomeView()
        .onAppear {
            // 더미 데이터로 미리보기
        }
}
