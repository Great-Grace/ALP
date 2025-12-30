// ArticleLoader.swift
// Dynamic Article Loader - Scans bundle for JSON files and imports to SwiftData

import Foundation
import SwiftData

// MARK: - Import Data Structure
struct ArticleImportData: Codable {
    let title: String
    let difficulty: Int?
    let tokens: [ArticleToken]
    let source: String?
}

// MARK: - Article Loader
final class ArticleLoader {
    
    // Prefix for article JSON files (e.g., article_story.json)
    static let articleFilePrefix = "article_"
    
    // MARK: - Dynamic Loading
    
    /// Scans bundle for all article_*.json files and imports them
    @MainActor
    static func loadAllArticles(context: ModelContext) -> LoadResult {
        var result = LoadResult()
        
        // 1. Find all JSON files in bundle with our prefix
        let jsonURLs = findArticleJSONFiles()
        result.filesFound = jsonURLs.count
        
        print("📚 ArticleLoader: Found \(jsonURLs.count) article JSON files")
        
        // 2. Process each file
        for url in jsonURLs {
            do {
                let imported = try importArticle(from: url, context: context)
                if imported {
                    result.imported += 1
                } else {
                    result.skipped += 1
                }
            } catch {
                print("⚠️ Failed to load \(url.lastPathComponent): \(error.localizedDescription)")
                result.errors.append((url.lastPathComponent, error.localizedDescription))
            }
        }
        
        // 3. Also try legacy sample_articles.json for backwards compatibility
        if let legacyCount = try? loadLegacyFormat(context: context) {
            result.imported += legacyCount
        }
        
        // 4. Save
        do {
            try context.save()
        } catch {
            print("⚠️ Failed to save context: \(error)")
        }
        
        print("✅ ArticleLoader complete: \(result.imported) imported, \(result.skipped) skipped, \(result.errors.count) errors")
        
        return result
    }
    
    /// Find all JSON files with article_ prefix in the main bundle
    private static func findArticleJSONFiles() -> [URL] {
        var urls: [URL] = []
        
        // Get all JSON files in bundle
        if let bundleURLs = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil) {
            for url in bundleURLs {
                let filename = url.deletingPathExtension().lastPathComponent
                // Match article_*.json OR any Arabic-titled json
                if filename.hasPrefix(articleFilePrefix) || filename.hasPrefix("sample_story") {
                    urls.append(url)
                }
            }
        }
        
        return urls
    }
    
    /// Import a single article JSON file
    @MainActor
    private static func importArticle(from url: URL, context: ModelContext) throws -> Bool {
        let data = try Data(contentsOf: url)
        
        // Try to decode as single article first
        let article: ArticleImportData
        
        if let single = try? JSONDecoder().decode(ArticleImportData.self, from: data) {
            article = single
        } else {
            // Maybe it's an array? Take first one
            let array = try JSONDecoder().decode([ArticleImportData].self, from: data)
            guard let first = array.first else { return false }
            article = first
        }
        
        // Check for duplicate
        let title = article.title
        let descriptor = FetchDescriptor<Article>(predicate: #Predicate { $0.title == title })
        
        if let existingCount = try? context.fetchCount(descriptor), existingCount > 0 {
            print("   ⏭️ Skipping '\(title)' (already exists)")
            return false
        }
        
        // Create Article
        let newArticle = Article(
            title: article.title,
            tokens: article.tokens,
            difficultyLevel: article.difficulty ?? 1,
            source: article.source ?? url.deletingPathExtension().lastPathComponent
        )
        
        context.insert(newArticle)
        print("   ✅ Imported '\(title)' (\(article.tokens.count) tokens)")
        
        return true
    }
    
    // MARK: - Legacy Support
    
    /// Load from the old sample_articles.json format (array of articles)
    @MainActor
    private static func loadLegacyFormat(context: ModelContext) throws -> Int {
        guard let url = Bundle.main.url(forResource: "sample_articles", withExtension: "json") else {
            return 0
        }
        
        let data = try Data(contentsOf: url)
        let importItems = try JSONDecoder().decode([ArticleImportData].self, from: data)
        
        var count = 0
        for item in importItems {
            let title = item.title
            let descriptor = FetchDescriptor<Article>(predicate: #Predicate { $0.title == title })
            
            if let existing = try? context.fetchCount(descriptor), existing > 0 {
                continue
            }
            
            let article = Article(
                title: item.title,
                tokens: item.tokens,
                difficultyLevel: item.difficulty ?? 1,
                source: item.source
            )
            context.insert(article)
            count += 1
        }
        
        return count
    }
    
    // MARK: - Result Type
    
    struct LoadResult {
        var filesFound: Int = 0
        var imported: Int = 0
        var skipped: Int = 0
        var errors: [(file: String, message: String)] = []
        
        var summary: String {
            if errors.isEmpty {
                return "Loaded \(imported) articles, skipped \(skipped) duplicates"
            } else {
                return "Loaded \(imported), skipped \(skipped), \(errors.count) errors"
            }
        }
    }
    
    // MARK: - Dummy Generator (for testing)
    
    @MainActor
    static func generateDummyArticle(context: ModelContext) {
        let tokens = [
            ArticleToken(text: "ذهب", cleanText: "ذهب", rootId: nil, isTargetWord: true, punctuation: nil),
            ArticleToken(text: "الطالب", cleanText: "الطالب", rootId: nil, isTargetWord: true, punctuation: nil),
            ArticleToken(text: "إلى", cleanText: "إلى", rootId: nil, isTargetWord: false, punctuation: nil),
            ArticleToken(text: "المدرسة", cleanText: "المدرسة", rootId: nil, isTargetWord: true, punctuation: ".")
        ]
        
        let article = Article(
            title: "يوم في المدرسة",
            tokens: tokens,
            difficultyLevel: 1,
            source: "System Generated"
        )
        context.insert(article)
        try? context.save()
    }
}
