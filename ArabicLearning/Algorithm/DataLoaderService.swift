// DataLoaderService.swift
// Production-Grade Background Data Loader with Actor Isolation

import Foundation
import SwiftData

// MARK: - Loading State

enum DataLoadingState: Equatable {
    case idle
    case loading(progress: Double)
    case completed(wordCount: Int)
    case skipped(reason: String)
    case failed(error: String)
}

// MARK: - Data Loader Actor

/// Thread-safe data loader using Swift Actor for background processing
actor DataLoaderService {
    
    // MARK: - Singleton
    
    static let shared = DataLoaderService()
    private init() {}
    
    // MARK: - Progress Tracking
    
    private var _state: DataLoadingState = .idle
    private var continuations: [UUID: AsyncStream<DataLoadingState>.Continuation] = [:]
    
    var state: DataLoadingState {
        _state
    }
    
    /// Subscribe to loading state updates
    func stateStream() -> AsyncStream<DataLoadingState> {
        AsyncStream { continuation in
            let id = UUID()
            continuations[id] = continuation
            continuation.yield(_state)
            
            continuation.onTermination = { @Sendable [weak self] _ in
                Task { [weak self] in
                    await self?.removeContinuation(id: id)
                }
            }
        }
    }
    
    private func removeContinuation(id: UUID) {
        continuations.removeValue(forKey: id)
    }
    
    private func updateState(_ newState: DataLoadingState) {
        _state = newState
        for continuation in continuations.values {
            continuation.yield(newState)
        }
    }
    
    // MARK: - Main Loading Method
    
    /// Loads curriculum data with idempotency check and batch insert
    /// - Returns: Number of words imported (0 if skipped)
    @MainActor
    func loadCurriculumIfNeeded(context: ModelContext) async -> Int {
        // 1. Idempotency Check - Skip if data already exists
        let existingCount = (try? context.fetchCount(FetchDescriptor<Word>())) ?? 0
        
        if existingCount > 0 {
            await updateState(.skipped(reason: "데이터 이미 존재 (\(existingCount)개)"))
            return 0
        }
        
        await updateState(.loading(progress: 0.0))
        
        // 2. Seed Levels
        StudyLevel.seedLevels(context: context)
        await updateState(.loading(progress: 0.05))
        
        // 3. Load CSV
        guard let url = Bundle.main.url(forResource: "verb_forms", withExtension: "csv"),
              let csvString = try? String(contentsOf: url, encoding: .utf8) else {
            await updateState(.failed(error: "CSV 파일을 찾을 수 없습니다"))
            return 0
        }
        
        await updateState(.loading(progress: 0.1))
        
        // 4. Parse and Batch Insert
        let result = await batchImport(csvString: csvString, context: context)
        
        // 5. Save Once
        do {
            try context.save()
            await updateState(.completed(wordCount: result))
        } catch {
            await updateState(.failed(error: "저장 실패: \(error.localizedDescription)"))
            return 0
        }
        
        return result
    }
    
    // MARK: - Batch Import (Memory-Efficient)
    
    @MainActor
    private func batchImport(csvString: String, context: ModelContext) async -> Int {
        let lines = csvString.components(separatedBy: .newlines)
        guard lines.count > 1 else { return 0 }
        
        // Parse header
        let header = parseCSVLine(lines[0])
        let columnMap = Dictionary(uniqueKeysWithValues: header.enumerated().map { ($1, $0) })
        
        // Fetch/Create level map
        let levelDescriptor = FetchDescriptor<StudyLevel>()
        let existingLevels = (try? context.fetch(levelDescriptor)) ?? []
        var levelMap: [Int: StudyLevel] = Dictionary(uniqueKeysWithValues: existingLevels.map { ($0.levelID, $0) })
        
        let totalRows = lines.count - 1
        var importedCount = 0
        
        // Batch processing
        for i in 1..<lines.count {
            let line = lines[i]
            guard !line.isEmpty else { continue }
            
            // Update progress every 100 rows
            if importedCount % 100 == 0 {
                let progress = 0.1 + (Double(i) / Double(totalRows)) * 0.85
                await updateState(.loading(progress: progress))
                
                // Yield to prevent blocking
                await Task.yield()
            }
            
            let columns = parseCSVLine(line)
            
            // Parse required fields
            guard let rootIdx = columnMap["root"], rootIdx < columns.count,
                  let formIdx = columnMap["verb_form"], formIdx < columns.count,
                  let wordIdx = columnMap["arabic_word"], wordIdx < columns.count else {
                continue
            }
            
            let root = columns[rootIdx].trimmingCharacters(in: .whitespaces)
            let formNumber = Int(columns[formIdx].trimmingCharacters(in: .whitespaces)) ?? 1
            let arabicWord = columns[wordIdx].trimmingCharacters(in: .whitespaces)
            
            guard !arabicWord.isEmpty else { continue }
            
            // Auto-leveling
            let levelID = calculateAutoLevel(for: importedCount)
            
            // Get or create level
            let level: StudyLevel
            if let existingLevel = levelMap[levelID] {
                level = existingLevel
            } else {
                level = StudyLevel(
                    levelID: levelID,
                    title: "레벨 \(levelID)",
                    description: "",
                    isLocked: levelID > 1
                )
                context.insert(level)
                levelMap[levelID] = level
            }
            
            // Parse optional fields
            let pattern = safeColumn(columns, columnMap["pattern"])
            let meaningPrimary = safeColumn(columns, columnMap["meaning_primary"])
            let meaningKorean = safeColumn(columns, columnMap["meaning_korean"])
            let exampleSentence = safeColumn(columns, columnMap["example_sentence"])
            let sentenceMeaning = safeColumn(columns, columnMap["sentence_meaning"])
            let nuanceKorean = safeColumn(columns, columnMap["nuance_kr"])
            
            // Create Word (NO SAVE YET - batch at end)
            let word = Word(
                arabic: arabicWord,
                korean: meaningPrimary ?? meaningKorean ?? "",
                exampleSentence: exampleSentence ?? "",
                sentenceKorean: sentenceMeaning ?? ""
            )
            word.levelID = levelID
            word.level = level
            word.root = root
            word.pattern = pattern
            word.verbForm = formNumber
            word.nuanceKorean = nuanceKorean
            
            context.insert(word)
            importedCount += 1
        }
        
        await updateState(.loading(progress: 0.95))
        return importedCount
    }
    
    // MARK: - Helpers (nonisolated for @MainActor access)
    
    nonisolated private func parseCSVLine(_ line: String) -> [String] {
        var columns: [String] = []
        var current = ""
        var inQuotes = false
        
        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                columns.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        columns.append(current)
        
        return columns
    }
    
    nonisolated private func safeColumn(_ columns: [String], _ index: Int?) -> String? {
        guard let idx = index, idx < columns.count else { return nil }
        let value = columns[idx].trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? nil : value
    }
    
    nonisolated private func calculateAutoLevel(for index: Int) -> Int {
        switch index {
        case 0..<100: return 1
        case 100..<300: return 2
        case 300..<600: return 3
        case 600..<1000: return 4
        default: return 5
        }
    }
}
