// MorphologyCard.swift
// Bottom Sheet for selected word - Enriched Semantic Data Display

import SwiftUI

struct MorphologyCard: View {
    let token: ArticleToken
    let verbForm: VerbForm?
    let addedStatus: InteractiveReadingView.WordAddedStatus
    var onAdd: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Handle
                handleBar
                
                // Header: Word and Meaning
                headerSection
                
                Divider()
                
                // Content based on VerbForm availability
                if let vf = verbForm {
                    enrichedContent(vf)
                } else {
                    fallbackContent
                }
                
                Spacer(minLength: 20)
            }
            .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .background(backgroundColor)
    }
    
    // MARK: - Handle Bar
    private var handleBar: some View {
        Capsule()
            .fill(Color.gray.opacity(0.3))
            .frame(width: 40, height: 5)
            .padding(.top, 10)
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                // Arabic Word (Large)
                Text(token.text)
                    .font(.system(size: 40, weight: .bold))
                
                // Primary Meaning (Blue)
                if let vf = verbForm {
                    Text(vf.displayMeaning)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.blue)
                    
                    // Secondary Meaning (Gray)
                    if let secondary = vf.meaningSecondary, !secondary.isEmpty {
                        Text(secondary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("분석 정보 없음")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Add Button
            addButton
        }
    }
    
    // MARK: - Enriched Content
    @ViewBuilder
    private func enrichedContent(_ vf: VerbForm) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            
            // Nuance Section (Lightbulb)
            if !vf.displayNuance.isEmpty {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.yellow)
                        .frame(width: 28)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("뉘앙스")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        
                        Text(vf.displayNuance)
                            .font(.body)
                            .foregroundStyle(.primary)
                    }
                }
                .padding()
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(12)
            }
            
            // Example Sentence Section (Quote Style)
            if let example = vf.exampleSentence, !example.isEmpty {
                HStack(alignment: .top, spacing: 0) {
                    // Blue vertical bar
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: 4)
                        .cornerRadius(2)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        // Arabic example
                        Text(example)
                            .font(.system(size: 20))
                            .environment(\.layoutDirection, .rightToLeft)
                        
                        // Korean translation
                        if let meaning = vf.exampleSentenceMeaning, !meaning.isEmpty {
                            Text(meaning)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.leading, 12)
                }
                .padding()
                .background(Color.blue.opacity(0.05))
                .cornerRadius(12)
            }
            
            Divider()
            
            // Footer: Root and Form Chips
            footerChips(vf)
        }
    }
    
    // MARK: - Footer Chips
    private func footerChips(_ vf: VerbForm) -> some View {
        HStack(spacing: 12) {
            // Root Chip
            HStack(spacing: 6) {
                Image(systemName: "textformat.abc")
                    .font(.caption)
                Text(vf.root)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(20)
            
            // Form Chip
            HStack(spacing: 6) {
                Image(systemName: "number")
                    .font(.caption)
                Text(vf.formLabel)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(20)
            
            // Pattern Chip
            Text(vf.pattern)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.green.opacity(0.1))
                .cornerRadius(20)
            
            Spacer()
        }
    }
    
    // MARK: - Fallback Content (No VerbForm)
    private var fallbackContent: some View {
        VStack(spacing: 12) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 50))
                .foregroundStyle(.secondary.opacity(0.5))
            
            Text("이 단어는 아직 분석되지 않았습니다.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Text("단어장에 추가하면 직접 학습할 수 있어요.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 30)
    }
    
    // MARK: - Add Button with State
    @ViewBuilder
    private var addButton: some View {
        switch addedStatus {
        case .notAdded:
            Button(action: onAdd) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
            
        case .added:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.green)
            
        case .alreadyExists:
            VStack(spacing: 2) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.gray)
                Text("저장됨")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    // MARK: - Background Color
    private var backgroundColor: Color {
        #if os(iOS)
        return Color(uiColor: .systemBackground)
        #else
        return Color(nsColor: .windowBackgroundColor)
        #endif
    }
}
