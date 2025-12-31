// String+Extensions.swift
// String extensions for sentence processing and text cleanup

import Foundation

extension String {
    
    // MARK: - Sentence Splitting
    
    /// Splits text into sentences by periods (.) and newlines
    /// Handles Arabic text properly
    var sentences: [String] {
        // Split by Arabic/English sentence terminators and newlines
        let separators = CharacterSet(charactersIn: ".。؟?!\n")
        
        return self
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
    
    /// Splits text into words
    var arabicWords: [String] {
        self.components(separatedBy: .whitespaces)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }
    }
    
    // MARK: - Parentheses Removal
    
    /// Removes all parentheses and their contents from the string
    /// "집에 (빨리) 갔다" → "집에 빨리 갔다"
    var removingParenthesesContent: String {
        // Remove content inside parentheses but keep the content
        var result = self
        
        // Pattern: Replace "(" with "", ")" with ""
        result = result.replacingOccurrences(of: "(", with: "")
        result = result.replacingOccurrences(of: ")", with: "")
        
        // Clean up double spaces
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }
        
        return result.trimmingCharacters(in: .whitespaces)
    }
    
    /// Removes parentheses and the content inside them entirely
    /// "집에 (빨리) 갔다" → "집에 갔다"
    var removingParenthesesEntirely: String {
        var result = self
        
        // Regex to remove content inside parentheses including the parentheses
        if let regex = try? NSRegularExpression(pattern: "\\([^)]*\\)", options: []) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "")
        }
        
        // Clean up double spaces
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }
        
        return result.trimmingCharacters(in: .whitespaces)
    }
    
    // MARK: - Arabic Text Helpers
    
    /// Checks if string contains Arabic characters
    var containsArabic: Bool {
        for scalar in unicodeScalars {
            if (0x0600...0x06FF).contains(scalar.value) ||  // Arabic
               (0x0750...0x077F).contains(scalar.value) ||  // Arabic Supplement
               (0xFB50...0xFDFF).contains(scalar.value) ||  // Arabic Presentation Forms-A
               (0xFE70...0xFEFF).contains(scalar.value) {   // Arabic Presentation Forms-B
                return true
            }
        }
        return false
    }
}
