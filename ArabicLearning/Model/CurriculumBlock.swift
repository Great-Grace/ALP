// CurriculumBlock.swift
// Main curriculum block (12 blocks total)

import Foundation
import SwiftData

@Model
final class CurriculumBlock {
    
    // MARK: - Core Properties
    
    /// Block ID (0-12)
    @Attribute(.unique) var blockID: Int = 0
    
    /// Title in Korean (e.g., "Form I 완전정복")
    var title: String = ""
    
    /// Title in Arabic (e.g., "الفعل الثلاثي المجرد")
    var titleArabic: String = ""
    
    /// CEFR level (e.g., "A1", "B1-B2")
    var cefrLevel: String = ""
    
    /// Is this the "hub" block (Block 6)
    var isHub: Bool = false
    
    /// Is this block locked?
    var isLocked: Bool = true
    
    /// Total sub-levels in this block
    var totalSubLevels: Int = 0
    
    /// Completed sub-levels
    var completedSubLevels: Int = 0
    
    /// Sub-levels in this block
    @Relationship(deleteRule: .cascade, inverse: \SubLevel.block)
    var subLevels: [SubLevel]? = []
    
    // MARK: - Computed Properties
    
    var progress: Double {
        guard totalSubLevels > 0 else { return 0 }
        return Double(completedSubLevels) / Double(totalSubLevels)
    }
    
    var progressPercentage: Int {
        Int(progress * 100)
    }
    
    var statusIcon: String {
        if progress >= 1.0 { return "checkmark.circle.fill" }
        if progress > 0 { return "arrow.right.circle.fill" }
        return "circle"
    }
    
    var displayTitle: String {
        "Block \(blockID): \(title)"
    }
    
    // MARK: - Initializer
    
    init(
        blockID: Int,
        title: String,
        titleArabic: String = "",
        cefrLevel: String = "",
        isHub: Bool = false,
        totalSubLevels: Int = 0
    ) {
        self.blockID = blockID
        self.title = title
        self.titleArabic = titleArabic
        self.cefrLevel = cefrLevel
        self.isHub = isHub
        self.totalSubLevels = totalSubLevels
    }
    
    // MARK: - Static: Seed from JSON
    
    @MainActor
    static func seedFromJSON(context: ModelContext) {
        // Check if blocks exist
        let descriptor = FetchDescriptor<CurriculumBlock>()
        guard let count = try? context.fetchCount(descriptor), count == 0 else {
            return
        }
        
        // Load curriculum_structure.json
        guard let url = Bundle.main.url(forResource: "curriculum_structure", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let blocks = json["blocks"] as? [[String: Any]] else {
            print("❌ Failed to load curriculum_structure.json")
            return
        }
        
        for blockData in blocks {
            guard let blockID = blockData["id"] as? Int,
                  let title = blockData["title"] as? String else { continue }
            
            let block = CurriculumBlock(
                blockID: blockID,
                title: title,
                titleArabic: blockData["title_ar"] as? String ?? "",
                cefrLevel: blockData["cefr"] as? String ?? "",
                isHub: blockData["isHub"] as? Bool ?? false
            )
            
            // Parse sub-levels
            if let subLevelData = blockData["subLevels"] as? [[String: Any]] {
                block.totalSubLevels = subLevelData.count
                
                for (index, subData) in subLevelData.enumerated() {
                    guard let subID = subData["id"] as? String,
                          let subTitle = subData["title"] as? String else { continue }
                    
                    let subLevel = SubLevel(
                        subLevelID: subID,
                        blockID: blockID,
                        orderInBlock: index + 1,
                        title: subTitle,
                        concept: subData["concept"] as? String ?? "",
                        targetWordCount: subData["words"] as? Int ?? 30,
                        isLocked: !(blockID == 0 && index == 0) // Only 0-1 unlocked
                    )
                    subLevel.block = block
                    context.insert(subLevel)
                }
            }
            
            block.isLocked = blockID > 0  // Only Block 0 unlocked
            context.insert(block)
        }
        
        try? context.save()
        print("✅ Seeded \(blocks.count) blocks from curriculum_structure.json")
    }
}
