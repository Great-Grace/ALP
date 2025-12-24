// ChapterFilterSheet - 학습 범위 선택
// Multi-select chapter filter

import SwiftUI

struct ChapterFilterSheet: View {
    @Binding var availableChapters: [Chapter]
    @Binding var selectedChapterIds: Set<UUID>
    var onToggleAll: () -> Void
    var isAllSelected: Bool
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with toggle all
                HStack {
                    Text("\(selectedChapterIds.count)/\(availableChapters.count) 선택됨")
                        .font(.subheadline)
                        .foregroundStyle(Color.textSecondary)
                    
                    Spacer()
                    
                    Button(action: onToggleAll) {
                        Text(isAllSelected ? "전체 해제" : "전체 선택")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.primary)
                    }
                }
                .padding()
                .background(Color.backgroundSecondary)
                
                Divider()
                
                // Chapter list
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(availableChapters) { chapter in
                            ChapterRow(
                                chapter: chapter,
                                isSelected: selectedChapterIds.contains(chapter.id),
                                onToggle: {
                                    toggleSelection(chapter.id)
                                }
                            )
                            Divider().padding(.leading, 56)
                        }
                    }
                }
            }
            .navigationTitle("학습 범위 설정")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        #if os(macOS)
        .frame(width: 400, height: 500)
        #endif
    }
    
    private func toggleSelection(_ id: UUID) {
        if selectedChapterIds.contains(id) {
            selectedChapterIds.remove(id)
        } else {
            selectedChapterIds.insert(id)
        }
    }
}

struct ChapterRow: View {
    let chapter: Chapter
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 16) {
                // Checkbox
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? Color.primary : Color.textTertiary, lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.primary)
                            .frame(width: 24, height: 24)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                
                // Chapter info
                VStack(alignment: .leading, spacing: 2) {
                    Text(chapter.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.textPrimary)
                    
                    Text("\(chapter.words.count)개 단어")
                        .font(.caption)
                        .foregroundStyle(Color.textSecondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isSelected ? Color.primary.opacity(0.05) : Color.clear)
    }
}

#Preview {
    ChapterFilterSheet(
        availableChapters: .constant([]),
        selectedChapterIds: .constant([]),
        onToggleAll: {},
        isAllSelected: true
    )
}
