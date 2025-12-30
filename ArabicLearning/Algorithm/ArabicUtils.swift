// ArabicUtils.swift
// Strict Arabic Text Normalizer - Preserves Hamza and Ya/Alif Maqsura forms

import Foundation

enum ArabicUtils {
    
    // MARK: - Tashkeel (Diacritics to Strip)
    
    /// Tashkeel (short vowels) to be stripped
    /// Preserves: Hamza forms (أ إ آ ء ؤ ئ), Alif Maqsura (ى) vs Ya (ي)
    private static let tashkeelRange: [Character] = [
        "\u{064B}", // Fathatan (ً)
        "\u{064C}", // Dammatan (ٌ)
        "\u{064D}", // Kasratan (ٍ)
        "\u{064E}", // Fatha (َ)
        "\u{064F}", // Damma (ُ)
        "\u{0650}", // Kasra (ِ)
        "\u{0651}", // Shadda (ّ)
        "\u{0652}", // Sukun (ْ)
        "\u{0653}", // Maddah above (ٓ)
        "\u{0654}", // Hamza above (ٔ)
        "\u{0655}", // Hamza below (ٕ)
        "\u{0656}", // Subscript alef (ٖ)
        "\u{0670}", // Superscript alef (ٰ)
        "\u{0640}", // Tatweel (ـ) - Kashida
    ]
    
    private static let tashkeelSet: Set<Character> = Set(tashkeelRange)
    
    // MARK: - Normalize (Strict)
    
    /// Strips only Tashkeel (diacritics) while preserving letter forms.
    /// - Preserves: Hamza forms (أ, إ, آ, ء, ؤ, ئ)
    /// - Preserves: Alif Maqsura (ى) vs Ya (ي)
    /// - Parameter text: Arabic text with possible diacritics
    /// - Returns: Normalized text without diacritics
    static func normalize(_ text: String) -> String {
        return String(text.filter { !tashkeelSet.contains($0) })
    }
    
    // MARK: - Strict Match
    
    /// Checks if user input strictly matches the target.
    /// Uses normalize() on both strings, then compares.
    /// - Parameters:
    ///   - input: User's typed input
    ///   - target: Target word to match
    /// - Returns: true if normalized forms are identical
    static func isStrictMatch(_ input: String, _ target: String) -> Bool {
        let normalizedInput = normalize(input.trimmingCharacters(in: .whitespacesAndNewlines))
        let normalizedTarget = normalize(target.trimmingCharacters(in: .whitespacesAndNewlines))
        return normalizedInput == normalizedTarget
    }
    
    // MARK: - Validation Helpers
    
    /// Checks if a character is Hamza-bearing (أ إ آ ء ؤ ئ)
    static func isHamza(_ char: Character) -> Bool {
        let hamzaForms: Set<Character> = ["أ", "إ", "آ", "ء", "ؤ", "ئ"]
        return hamzaForms.contains(char)
    }
    
    /// Checks if character is Alif Maqsura (ى) - NOT Ya (ي)
    static func isAlifMaqsura(_ char: Character) -> Bool {
        return char == "ى"
    }
    
    /// Checks if character is Ya (ي) - NOT Alif Maqsura (ى)
    static func isYa(_ char: Character) -> Bool {
        return char == "ي"
    }
    
    // MARK: - Detailed Comparison (for error feedback)
    
    /// Compares input to target and returns first mismatch position
    /// Useful for showing users where they made a mistake
    static func findFirstMismatch(_ input: String, _ target: String) -> (position: Int, expected: Character?, got: Character?)? {
        let normInput = normalize(input)
        let normTarget = normalize(target)
        
        let inputChars = Array(normInput)
        let targetChars = Array(normTarget)
        
        let minLength = min(inputChars.count, targetChars.count)
        
        for i in 0..<minLength {
            if inputChars[i] != targetChars[i] {
                return (i, targetChars[i], inputChars[i])
            }
        }
        
        // Length mismatch
        if inputChars.count != targetChars.count {
            if inputChars.count < targetChars.count {
                return (inputChars.count, targetChars[inputChars.count], nil)
            } else {
                return (targetChars.count, nil, inputChars[targetChars.count])
            }
        }
        
        return nil // Perfect match
    }
    
    // MARK: - Common Mistakes Detection
    
    /// Detects common Arabic typing mistakes
    enum TypingMistake {
        case hamzaConfusion      // أ/ا, إ/ي, etc.
        case alifMaqsuraYa       // ى/ي confusion
        case taMarbuta           // ة/ه confusion
        case none
    }
    
    static func detectMistakeType(expected: Character, got: Character) -> TypingMistake {
        // Hamza confusion
        let hamzaAndAlif: Set<Character> = ["أ", "إ", "آ", "ا", "ء", "ؤ", "ئ"]
        if hamzaAndAlif.contains(expected) && hamzaAndAlif.contains(got) {
            return .hamzaConfusion
        }
        
        // Alif Maqsura vs Ya
        if (expected == "ى" && got == "ي") || (expected == "ي" && got == "ى") {
            return .alifMaqsuraYa
        }
        
        // Ta Marbuta vs Ha
        if (expected == "ة" && got == "ه") || (expected == "ه" && got == "ة") {
            return .taMarbuta
        }
        
        return .none
    }
}
