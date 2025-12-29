// DualColumnQuizView.swift
// 2-Column Selection Quiz UI for Arabic Morphology

import SwiftUI

struct DualColumnQuizView: View {
    let quiz: DualColumnQuizItem
    let onComplete: (Bool) -> Void
    
    // MARK: - State
    @State private var selectedLeftID: String? = nil
    @State private var selectedRightID: String? = nil
    @State private var isSubmitted: Bool = false
    @State private var isCorrect: Bool = false
    @State private var showShake: Bool = false
    
    // MARK: - Design Constants
    private let arabicFont: Font = .system(size: 36, weight: .medium, design: .serif)
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
                    correctID: quiz.correctPair.0,
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
                    correctID: quiz.correctPair.1,
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
        .modifier(ShakeEffect(animatableData: showShake ? 1 : 0))
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
            
            // Sub Text (Korean hint, if exists)
            if let subText = quiz.displayCard.subText {
                Text(subText)
                    .font(koreanFont)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.95))
                .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
        )
    }
    
    // MARK: - Column View
    private func columnView(
        label: String,
        options: [QuizOption],
        selectedID: Binding<String?>,
        correctID: String,
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
                    isCorrectOption: option.id == correctID,
                    isArabic: isArabic
                ) {
                    if !isSubmitted {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedID.wrappedValue = option.id
                        }
                        hapticLight()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Option Button
    private func optionButton(
        option: QuizOption,
        isSelected: Bool,
        isCorrectOption: Bool,
        isArabic: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(option.text)
                .font(isArabic ? .system(size: 24, weight: .medium, design: .serif) : buttonFont)
                .foregroundColor(buttonTextColor(isSelected: isSelected, isCorrectOption: isCorrectOption))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(buttonBackground(isSelected: isSelected, isCorrectOption: isCorrectOption))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(buttonBorderColor(isSelected: isSelected, isCorrectOption: isCorrectOption), lineWidth: isSelected ? 3 : 1)
                )
                .cornerRadius(14)
                .environment(\.layoutDirection, isArabic ? .rightToLeft : .leftToRight)
        }
        .buttonStyle(.plain)
        .disabled(isSubmitted)
    }
    
    // MARK: - Submit Button
    private var submitButton: some View {
        Button(action: submitAnswer) {
            HStack {
                if isSubmitted {
                    Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
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
        if isSubmitted { return true }
        return selectedLeftID != nil && selectedRightID != nil
    }
    
    private var submitButtonText: String {
        if isSubmitted {
            return isCorrect ? "정답! 🎉" : "오답 - 다시 시도"
        }
        return "확인"
    }
    
    private var submitButtonBackground: Color {
        if isSubmitted {
            return isCorrect ? .green : .red
        }
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
    
    // MARK: - Button Styling
    
    private func buttonTextColor(isSelected: Bool, isCorrectOption: Bool) -> Color {
        if isSubmitted {
            if isCorrectOption { return .white }
            if isSelected { return .white }
        }
        return isSelected ? .blue : .primary
    }
    
    private func buttonBackground(isSelected: Bool, isCorrectOption: Bool) -> Color {
        if isSubmitted {
            if isCorrectOption { return .green }
            if isSelected && !isCorrectOption { return .red.opacity(0.9) }
        }
        return isSelected ? .blue.opacity(0.1) : Color.gray.opacity(0.15)
    }
    
    private func buttonBorderColor(isSelected: Bool, isCorrectOption: Bool) -> Color {
        if isSubmitted {
            if isCorrectOption { return .green }
            if isSelected { return .red }
        }
        return isSelected ? .blue : .gray.opacity(0.3)
    }
    
    // MARK: - Actions
    
    private func submitAnswer() {
        guard let leftID = selectedLeftID, let rightID = selectedRightID else { return }
        
        if isSubmitted && !isCorrect {
            // Retry
            withAnimation {
                isSubmitted = false
                selectedLeftID = nil
                selectedRightID = nil
            }
            return
        }
        
        let correct = DualColumnQuizGenerator.shared.validateAnswer(
            quiz: quiz,
            leftSelection: leftID,
            rightSelection: rightID
        )
        
        withAnimation(.easeInOut(duration: 0.3)) {
            isSubmitted = true
            isCorrect = correct
        }
        
        if correct {
            hapticSuccess()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                onComplete(true)
            }
        } else {
            hapticError()
            withAnimation(.default) {
                showShake = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showShake = false
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

#Preview("Word Deconstruction") {
    DualColumnQuizView(
        quiz: DualColumnQuizItem(
            id: "preview_2",
            type: .wordDeconstruction,
            displayCard: DisplayCard(mainText: "تَكَاتَبَ", subText: nil),
            leftColumn: ColumnSelector(
                label: "형태",
                options: [
                    QuizOption(id: "f3", text: "3형"),
                    QuizOption(id: "f5", text: "5형"),
                    QuizOption(id: "f6", text: "6형"),
                    QuizOption(id: "f8", text: "8형")
                ]
            ),
            rightColumn: ColumnSelector(
                label: "어근",
                options: [
                    QuizOption(id: "r0", text: "ع-ل-م"),
                    QuizOption(id: "r1", text: "ك-ت-ب"),
                    QuizOption(id: "r2", text: "ف-ه-م"),
                    QuizOption(id: "r3", text: "س-م-ع")
                ]
            ),
            correctPair: ("f6", "r1")
        ),
        onComplete: { _ in }
    )
    .padding()
    .background(Color.gray.opacity(0.15))
}
