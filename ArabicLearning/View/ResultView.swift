// ResultView - 학습 결과 화면
// Modern Design System 적용

import SwiftUI

struct ResultView: View {
    let correctCount: Int
    let wrongCount: Int
    let wrongWords: [Word]
    let accuracy: Double
    let onDismiss: () -> Void
    
    var totalCount: Int {
        correctCount + wrongCount
    }
    
    var body: some View {
        ZStack {
            Color.backgroundPrimary
                .ignoresSafeArea()
            
            VStack(spacing: Design.spacingXL) {
                Spacer()
                
                // 결과 아이콘
                resultIcon
                
                // 타이틀
                Text(resultTitle)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.textPrimary)
                
                // 정확도
                Text("\(Int(accuracy))%")
                    .font(.system(size: 64, weight: .bold))
                    .foregroundStyle(resultColor)
                
                // 상세 결과 카드
                statsCard
                
                // 오답 목록
                if !wrongWords.isEmpty {
                    wrongWordsList
                }
                
                Spacer()
                
                // 확인 버튼
                Button("확인") { onDismiss() }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, Design.spacingXL)
                    .padding(.bottom, Design.spacingXL)
            }
            .padding(.horizontal, Design.spacingL)
        }
    }
    
    // MARK: - Result Icon
    private var resultIcon: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [resultColor, resultColor.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 120, height: 120)
                .shadow(color: resultColor.opacity(0.4), radius: 20, y: 10)
            
            Image(systemName: resultIconName)
                .font(.system(size: 50))
                .foregroundStyle(.white)
        }
    }
    
    // MARK: - Stats Card
    private var statsCard: some View {
        HStack(spacing: 0) {
            resultStatItem(title: "정답", count: correctCount, color: .success)
            
            Divider()
                .frame(height: 50)
            
            resultStatItem(title: "오답", count: wrongCount, color: .error)
            
            Divider()
                .frame(height: 50)
            
            resultStatItem(title: "총", count: totalCount, color: .primary)
        }
        .cardStyle()
    }
    
    private func resultStatItem(title: String, count: Int, color: Color) -> some View {
        VStack(spacing: Design.spacingS) {
            Text("\(count)")
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(color)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Wrong Words List
    private var wrongWordsList: some View {
        VStack(alignment: .leading, spacing: Design.spacingM) {
            Text("복습이 필요한 단어")
                .font(.headline)
                .foregroundStyle(Color.textSecondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Design.spacingM) {
                    ForEach(wrongWords, id: \.id) { word in
                        VStack(spacing: Design.spacingXS) {
                            Text(word.arabic)
                                .font(.system(size: 18, weight: .semibold))
                                .environment(\.layoutDirection, .rightToLeft)
                                .foregroundStyle(Color.textPrimary)
                            
                            Text(word.korean)
                                .font(.caption)
                                .foregroundStyle(Color.textSecondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.error.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: Design.radiusMedium))
                    }
                }
            }
        }
        .cardStyle()
    }
    
    // MARK: - Computed Properties
    private var resultColor: Color {
        if accuracy >= 80 { return .success }
        if accuracy >= 60 { return .warning }
        return .error
    }
    
    private var resultIconName: String {
        if accuracy >= 80 { return "star.fill" }
        if accuracy >= 60 { return "hand.thumbsup.fill" }
        return "arrow.clockwise"
    }
    
    private var resultTitle: String {
        if accuracy >= 80 { return "훌륭해요! 🎉" }
        if accuracy >= 60 { return "잘했어요! 👍" }
        return "다시 도전! 💪"
    }
}

// MARK: - Preview
#Preview {
    ResultView(
        correctCount: 15,
        wrongCount: 5,
        wrongWords: [],
        accuracy: 75.0,
        onDismiss: {}
    )
}
