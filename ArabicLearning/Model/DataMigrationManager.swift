// DataMigrationManager.swift
// 데이터베이스 마이그레이션 및 데이터 무결성 보정

import Foundation
import SwiftData

struct DataMigrationManager {
    /// 데이터 마이그레이션 실행
    /// - Word 모델에 새로 추가된 arabicClean, sentenceClean 필드가 비어있을 경우,
    ///   기존 데이터를 기반으로 채워넣습니다.
    @MainActor
    static func performMigrationIfNeeded(context: ModelContext) {
        do {
            // 1. arabicClean이 비어있는 단어 조회
            // (Note: SwiftData 쿼리에서 isEmpty 체크가 제한적일 수 있어, 전체 조회 후 필터링하거나 Predicate 사용)
            // 간단하게, 모든 단어를 가져와서 검사 (데이터량이 많지 않다고 가정)
            let descriptor = FetchDescriptor<Word>()
            let words = try context.fetch(descriptor)
            
            var updateCount = 0
            
            for word in words {
                var needsUpdate = false
                
                // arabicClean이 비어있으면 채움
                if word.arabicClean.isEmpty && !word.arabic.isEmpty {
                    word.arabicClean = word.arabic.withoutDiacritics
                    needsUpdate = true
                }
                
                // sentenceClean이 비어있으면 채움
                if word.sentenceClean.isEmpty && !word.exampleSentence.isEmpty {
                    word.sentenceClean = word.exampleSentence.withoutDiacritics
                    needsUpdate = true
                }
                
                if needsUpdate {
                    updateCount += 1
                }
            }
            
            if updateCount > 0 {
                try context.save()
                print("✅ Data Migration Completed: Updated \(updateCount) words with normalized text.")
            } else {
                print("✅ Data Migration Skipped: all data is up to date.")
            }
            
        } catch {
            print("❌ Data Migration Failed: \(error)")
        }
    }
}
