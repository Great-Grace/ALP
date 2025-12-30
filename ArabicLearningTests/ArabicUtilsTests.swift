// ArabicUtilsTests.swift
// Unit Tests for Strict Arabic Normalizer

import XCTest
@testable import ArabicLearning

final class ArabicUtilsTests: XCTestCase {
    
    // MARK: - Test 1: Tashkeel Removal (Diacritics)
    
    func testNormalize_RemovesTashkeel() {
        // Fatha, Damma, Kasra, Sukun, Shadda
        let input = "أَنْتَ"  // 'anta (you)
        let normalized = ArabicUtils.normalize(input)
        
        XCTAssertEqual(normalized, "أنت", "Should remove all Tashkeel diacritics")
    }
    
    func testNormalize_RemovesTanween() {
        // Fathatan, Dammatan, Kasratan
        let input = "كِتَابًا"  // kitaaban
        let normalized = ArabicUtils.normalize(input)
        
        XCTAssertEqual(normalized, "كتابا", "Should remove Tanween")
    }
    
    func testNormalize_RemovesTatweel() {
        // Tatweel (Kashida) - decorative elongation
        let input = "مـحـمـد"  // Muhammad with Tatweel
        let normalized = ArabicUtils.normalize(input)
        
        XCTAssertEqual(normalized, "محمد", "Should remove Tatweel")
    }
    
    func testNormalize_PreservesBaseLetters() {
        let input = "مرحبا"  // marhaba (no diacritics)
        let normalized = ArabicUtils.normalize(input)
        
        XCTAssertEqual(normalized, "مرحبا", "Should preserve base letters unchanged")
    }
    
    // MARK: - Test 2: Hamza Preservation (CRITICAL)
    
    func testIsStrictMatch_HamzaOnAlif_vs_BareAlif() {
        // أ (Hamza on Alif) should NOT match ا (bare Alif)
        let withHamza = "أحمد"   // Ahmad with Hamza
        let bareAlif = "احمد"   // Ahmad without Hamza
        
        XCTAssertFalse(
            ArabicUtils.isStrictMatch(withHamza, bareAlif),
            "Hamza (أ) must NOT match bare Alif (ا)"
        )
    }
    
    func testIsStrictMatch_HamzaBelowAlif_vs_BareAlif() {
        // إ (Hamza below Alif) should NOT match ا (bare Alif)
        let hamzaBelow = "إسلام"  // Islam with Hamza below
        let bareAlif = "اسلام"   // Islam without Hamza
        
        XCTAssertFalse(
            ArabicUtils.isStrictMatch(hamzaBelow, bareAlif),
            "Hamza below (إ) must NOT match bare Alif (ا)"
        )
    }
    
    func testIsStrictMatch_HamzaOnWaw() {
        // ؤ (Hamza on Waw) should NOT match و (bare Waw)
        let hamzaWaw = "مؤمن"    // Mu'min (believer)
        let bareWaw = "مومن"    // Without Hamza
        
        XCTAssertFalse(
            ArabicUtils.isStrictMatch(hamzaWaw, bareWaw),
            "Hamza on Waw (ؤ) must NOT match bare Waw (و)"
        )
    }
    
    func testIsStrictMatch_HamzaOnYa() {
        // ئ (Hamza on Ya) should NOT match ي (bare Ya)
        let hamzaYa = "مائة"    // Hundred (maa'a)
        let bareYa = "ماية"    // Without Hamza
        
        XCTAssertFalse(
            ArabicUtils.isStrictMatch(hamzaYa, bareYa),
            "Hamza on Ya (ئ) must NOT match bare Ya (ي)"
        )
    }
    
    // MARK: - Test 3: Alif Maqsura vs Ya (CRITICAL)
    
    func testIsStrictMatch_AlifMaqsura_vs_Ya() {
        // ى (Alif Maqsura) should NOT match ي (Ya)
        let alifMaqsura = "على"  // 'alaa (on/upon) - ends with ى
        let withYa = "علي"       // 'Ali (name) - ends with ي
        
        XCTAssertFalse(
            ArabicUtils.isStrictMatch(alifMaqsura, withYa),
            "Alif Maqsura (ى) must NOT match Ya (ي)"
        )
    }
    
    func testIsStrictMatch_MustashfaEndings() {
        // مستشفى (hospital) ends with ى
        // مستشفي would be incorrect
        let correct = "مستشفى"
        let incorrect = "مستشفي"
        
        XCTAssertFalse(
            ArabicUtils.isStrictMatch(correct, incorrect),
            "Hospital (مستشفى) should not match with ي ending"
        )
    }
    
    // MARK: - Test 4: Exact Match Cases
    
    func testIsStrictMatch_SameWord_ReturnsTrue() {
        let word = "مرحبا"
        
        XCTAssertTrue(
            ArabicUtils.isStrictMatch(word, word),
            "Same word should match exactly"
        )
    }
    
    func testIsStrictMatch_WithAndWithoutTashkeel_ReturnsTrue() {
        // Same word, but one has diacritics
        let withTashkeel = "كَتَبَ"  // kataba (he wrote)
        let withoutTashkeel = "كتب"
        
        XCTAssertTrue(
            ArabicUtils.isStrictMatch(withTashkeel, withoutTashkeel),
            "Word with diacritics should match word without diacritics"
        )
    }
    
    func testIsStrictMatch_WhitespaceTrimming() {
        let padded = "  مرحبا  "
        let clean = "مرحبا"
        
        XCTAssertTrue(
            ArabicUtils.isStrictMatch(padded, clean),
            "Whitespace should be trimmed before comparison"
        )
    }
    
    // MARK: - Test 5: Helper Functions
    
    func testIsHamza_CorrectlyIdentifiesHamzaForms() {
        XCTAssertTrue(ArabicUtils.isHamza("أ"), "أ is Hamza")
        XCTAssertTrue(ArabicUtils.isHamza("إ"), "إ is Hamza")
        XCTAssertTrue(ArabicUtils.isHamza("آ"), "آ is Hamza")
        XCTAssertTrue(ArabicUtils.isHamza("ء"), "ء is Hamza")
        XCTAssertTrue(ArabicUtils.isHamza("ؤ"), "ؤ is Hamza")
        XCTAssertTrue(ArabicUtils.isHamza("ئ"), "ئ is Hamza")
        
        XCTAssertFalse(ArabicUtils.isHamza("ا"), "ا is NOT Hamza")
        XCTAssertFalse(ArabicUtils.isHamza("و"), "و is NOT Hamza")
    }
    
    func testIsAlifMaqsura_CorrectlyIdentifies() {
        XCTAssertTrue(ArabicUtils.isAlifMaqsura("ى"), "ى is Alif Maqsura")
        XCTAssertFalse(ArabicUtils.isAlifMaqsura("ي"), "ي is NOT Alif Maqsura")
    }
    
    func testIsYa_CorrectlyIdentifies() {
        XCTAssertTrue(ArabicUtils.isYa("ي"), "ي is Ya")
        XCTAssertFalse(ArabicUtils.isYa("ى"), "ى is NOT Ya")
    }
    
    // MARK: - Test 6: Mistake Detection
    
    func testDetectMistakeType_HamzaConfusion() {
        let mistake = ArabicUtils.detectMistakeType(expected: "أ", got: "ا")
        XCTAssertEqual(mistake, .hamzaConfusion, "Should detect Hamza confusion")
    }
    
    func testDetectMistakeType_AlifMaqsuraYa() {
        let mistake = ArabicUtils.detectMistakeType(expected: "ى", got: "ي")
        XCTAssertEqual(mistake, .alifMaqsuraYa, "Should detect Alif Maqsura vs Ya confusion")
    }
    
    func testDetectMistakeType_TaMarbuta() {
        let mistake = ArabicUtils.detectMistakeType(expected: "ة", got: "ه")
        XCTAssertEqual(mistake, .taMarbuta, "Should detect Ta Marbuta confusion")
    }
    
    // MARK: - Test 7: Edge Cases
    
    func testNormalize_EmptyString() {
        let result = ArabicUtils.normalize("")
        XCTAssertEqual(result, "", "Empty string should return empty")
    }
    
    func testIsStrictMatch_EmptyStrings() {
        XCTAssertTrue(
            ArabicUtils.isStrictMatch("", ""),
            "Two empty strings should match"
        )
    }
    
    func testNormalize_AllDiacritics() {
        // Word that is ALL diacritics
        let onlyDiacritics = "ً ٌ ٍ"
        let result = ArabicUtils.normalize(onlyDiacritics)
        
        XCTAssertEqual(result.trimmingCharacters(in: .whitespaces), "", "Pure diacritics should result in empty/whitespace")
    }
}
