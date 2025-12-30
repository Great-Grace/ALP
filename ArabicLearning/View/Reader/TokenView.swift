// TokenView.swift
// Component for a single Article Token

import SwiftUI

enum TokenVisualState {
    case normal
    case target       // Key vocabulary
    case highlighted  // Active selection / Matching root
    case dimmed       // Inactive when another root is selected
}

struct TokenView: View {
    let token: ArticleToken
    let state: TokenVisualState
    var onTap: () -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            Text(token.text)
                .font(.title3) // Readable Arabic size
                .fontWeight(fontWeight)
                .foregroundStyle(foregroundColor)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(backgroundColor)
                .cornerRadius(4)
            
            if let punc = token.punctuation {
                Text(punc)
                    .font(.title3)
                    .foregroundStyle(.primary)
            }
        }
        .onTapGesture {
            onTap()
        }
    }
    
    // MARK: - Visual Style Logic
    
    private var fontWeight: Font.Weight {
        switch state {
        case .target, .highlighted: return .bold
        default: return .regular
        }
    }
    
    private var foregroundColor: Color {
        switch state {
        case .normal: return .primary
        case .target: return .blue
        case .highlighted: return .white
        case .dimmed: return .secondary.opacity(0.5)
        }
    }
    
    private var backgroundColor: Color {
        switch state {
        case .highlighted: return .blue
        case .target: return .blue.opacity(0.1)
        default: return .clear
        }
    }
}
