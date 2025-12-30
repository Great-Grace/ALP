// DualColumnQuizView.swift
// 2-Column Selection Quiz UI for Arabic Morphology
// QA Hotfix: No answer spoiling, retry mode, Type 3 meaning display

import SwiftUI

struct DualColumnQuizView: View {
    let quiz: DualColumnQuizItem
    let onComplete: (Bool) -> Void
    
    // MARK: - State
    @State private var selectedLeftID: String? = nil
    @State private var selectedRightID: String? = nil
    @State private var attemptCount: Int = 0
    @State private var showError: Bool = false
    @State private var isSuccess: Bool = false
    @State private var hasCompleted: Bool = false  // Prevent double-skip
    
    // MARK: - Design Constants
    private let arabicFont: Font = .custom("Amiri-Bold", size: 36)
    private let koreanFont: Font = .system(size: 16, weight: .medium)
    private let buttonFont: Font = .system(size: 20, weight: .medium)
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Question Card
            questionCard
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 16)
            
            Divider()
                .padding(.horizontal, 24)
            
            // MARK: - Dual Column Selection
            HStack(alignment: .top, spacing: 16) {
                // Left Column
                columnView(
                    label: quiz.leftColumn.label,
                    options: quiz.leftColumn.options,
                    selectedID: $selectedLeftID,
                    isArabic: false
                )
                
                // Divider
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 1)
                
                // Right Column
                columnView(
                    label: quiz.rightColumn.label,
                    options: quiz.rightColumn.options,
                    selectedID: $selectedRightID,
                    isArabic: quiz.rightColumn.label == "어근" || quiz.rightColumn.label == "결과"
                )
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            
            Spacer()
            
            // MARK: - Submit Button
            submitButton
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
        }
        .modifier(ShakeEffect(animatableData: showError ? 1 : 0))
    }
    
    // MARK: - Question Card
    private var questionCard: some View {
        VStack(spacing: 12) {
            // Quiz Type Badge
            Text(quizTypeBadge)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(badgeColor)
                .cornerRadius(12)
            
            // Main Text (Arabic)
            Text(quiz.displayCard.mainText)
                .font(arabicFont)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .environment(\.layoutDirection, .rightToLeft)
            
            // Sub Text (Korean hint) - ALWAYS show for Type 3
            if let subText = quiz.displayCard.subText {
                Text(subText)
                    .font(koreanFont)
                    .foregroundColor(.secondary)
            } else if quiz.type == .constructiveSynthesis {
                // Type 3: Show target meaning hint
                Text(targetMeaningHint)
                    .font(.subheadline)
                    .foregroundColor(.orange)
                    .italic()
            }
            
            // Attempt indicator
            if attemptCount > 0 && !isSuccess {
                Text("시도: \(attemptCount)회")
                    .font(.caption2)
                    .foregroundColor(.red)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(isSuccess ? Color.green.opacity(0.1) : Color.white.opacity(0.95))
                .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
        )
    }
    
    // Hint for Type 3 Construction
    private var targetMeaningHint: String {
        // Extract from correct answer if available
        "→ 어떤 형태로 변환될까요?"
    }
    
    // MARK: - Column View
    private func columnView(
        label: String,
        options: [QuizOption],
        selectedID: Binding<String?>,
        isArabic: Bool
    ) -> some View {
        VStack(spacing: 12) {
            // Header
            Text(label)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
            
            // Options
            ForEach(options) { option in
                optionButton(
                    option: option,
                    isSelected: selectedID.wrappedValue == option.id,
                    isArabic: isArabic
                ) {
                    guard !isSuccess else { return }
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedID.wrappedValue = option.id
                        showError = false  // Clear error on new selection
                    }
                    hapticLight()
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Option Button (NO correct answer reveal on error!)
    private func optionButton(
        option: QuizOption,
        isSelected: Bool,
        isArabic: Bool,
        action: @escaping () -> Void
    ) -> some View {
        let isWrongSelection = showError && isSelected
        
        return Button(action: action) {
            Text(option.text)
                .font(isArabic ? .custom("Amiri-Regular", size: 24) : buttonFont)
                .foregroundColor(buttonTextColor(isSelected: isSelected, isWrong: isWrongSelection))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(buttonBackground(isSelected: isSelected, isWrong: isWrongSelection))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(buttonBorderColor(isSelected: isSelected, isWrong: isWrongSelection), lineWidth: isSelected ? 3 : 1)
                )
                .cornerRadius(14)
                .environment(\.layoutDirection, isArabic ? .rightToLeft : .leftToRight)
        }
        .buttonStyle(.plain)
        .disabled(isSuccess)
    }
    
    // MARK: - Submit Button
    private var submitButton: some View {
        Button(action: submitAnswer) {
            HStack {
                if isSuccess {
                    Image(systemName: "checkmark.circle.fill")
                }
                Text(submitButtonText)
                    .fontWeight(.bold)
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(submitButtonBackground)
            .cornerRadius(16)
        }
        .disabled(!canSubmit)
        .opacity(canSubmit ? 1 : 0.5)
    }
    
    // MARK: - Helpers
    
    private var canSubmit: Bool {
        if isSuccess { return false }
        return selectedLeftID != nil && selectedRightID != nil
    }
    
    private var submitButtonText: String {
        if isSuccess {
            return "정답! 🎉"
        }
        if showError {
            return "다시 시도"
        }
        return "확인"
    }
    
    private var submitButtonBackground: Color {
        if isSuccess { return .green }
        if showError { return .orange }
        return canSubmit ? .blue : .gray
    }
    
    private var quizTypeBadge: String {
        switch quiz.type {
        case .patternRecognition: return "패턴 인식"
        case .wordDeconstruction: return "단어 분석"
        case .constructiveSynthesis: return "조합 생성"
        }
    }
    
    private var badgeColor: Color {
        switch quiz.type {
        case .patternRecognition: return .purple
        case .wordDeconstruction: return .orange
        case .constructiveSynthesis: return .teal
        }
    }
    
    // MARK: - Button Styling (NO GREEN for wrong answers!)
    
    private func buttonTextColor(isSelected: Bool, isWrong: Bool) -> Color {
        if isSuccess && isSelected { return .white }
        if isWrong { return .white }
        return isSelected ? .blue : .primary
    }
    
    private func buttonBackground(isSelected: Bool, isWrong: Bool) -> Color {
        if isSuccess && isSelected { return .green }
        if isWrong { return .red.opacity(0.8) }
        return isSelected ? .blue.opacity(0.1) : Color.gray.opacity(0.15)
    }
    
    private func buttonBorderColor(isSelected: Bool, isWrong: Bool) -> Color {
        if isSuccess && isSelected { return .green }
        if isWrong { return .red }
        return isSelected ? .blue : .gray.opacity(0.3)
    }
    
    // MARK: - Actions
    
    private func submitAnswer() {
        guard let leftID = selectedLeftID, let rightID = selectedRightID else { return }
        guard !hasCompleted else { return }  // Prevent double-skip
        
        let correct = DualColumnQuizGenerator.shared.validateAnswer(
            quiz: quiz,
            leftSelection: leftID,
            rightSelection: rightID
        )
        
        if correct {
            // SUCCESS
            withAnimation(.easeInOut(duration: 0.3)) {
                isSuccess = true
                showError = false
            }
            hapticSuccess()
            
            // Single completion trigger with debounce
            hasCompleted = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                onComplete(true)
            }
        } else {
            // FAILURE - Just shake, don't reveal answer
            attemptCount += 1
            withAnimation(.easeInOut(duration: 0.1)) {
                showError = true
            }
            hapticError()
            
            // Shake animation
            withAnimation(.default) {
                showError = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // Keep showError true so user sees red selection
                // Don't reset - let them pick new options
            }
        }
    }
    
    // MARK: - Haptics
    
    private func hapticLight() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
    }
    
    private func hapticSuccess() {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
    }
    
    private func hapticError() {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
        #endif
    }
}

// MARK: - Shake Effect
struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat
    
    func effectValue(size: CGSize) -> ProjectionTransform {
        let offset = sin(animatableData * .pi * 4) * 10
        return ProjectionTransform(CGAffineTransform(translationX: offset, y: 0))
    }
}

// MARK: - Preview
#Preview("Pattern Recognition") {
    DualColumnQuizView(
        quiz: DualColumnQuizItem(
            id: "preview_1",
            type: .patternRecognition,
            displayCard: DisplayCard(mainText: "فَعَّلَ", subText: nil),
            leftColumn: ColumnSelector(
                label: "형태",
                options: [
                    QuizOption(id: "f1", text: "1형"),
                    QuizOption(id: "f2", text: "2형"),
                    QuizOption(id: "f3", text: "3형"),
                    QuizOption(id: "f4", text: "4형")
                ]
            ),
            rightColumn: ColumnSelector(
                label: "뉘앙스",
                options: [
                    QuizOption(id: "n1", text: "기본형"),
                    QuizOption(id: "n2", text: "사동/강조"),
                    QuizOption(id: "n3", text: "상호동작"),
                    QuizOption(id: "n4", text: "사역형")
                ]
            ),
            correctPair: ("f2", "n2")
        ),
        onComplete: { _ in }
    )
    .padding()
    .background(Color.gray.opacity(0.15))
}
