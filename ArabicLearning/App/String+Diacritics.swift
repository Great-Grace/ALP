//
//  String+Diacritics.swift
//  ArabicLearning
//
//  Arabic Diacritics (Harakat) Removal Extension
//

import Foundation

extension String {
    /// 아랍어 모음(Harakat/Diacritics)을 제거한 문자열 반환
    /// 예: "بَيْت" → "بيت"
    ///
    /// 추가 정규화:
    /// - Superscript Alef (U+0670 ٰ): 제거 (단검 알리프 - 키보드 입력 불가)
    /// - Alef Wasla (U+0671 ٱ): 일반 Alef (U+0627 ا)로 변환
    var withoutDiacritics: String {
        var result = self
        
        // 1. Strip standard diacritics (fatha, damma, kasra, shadda, sukun, etc.)
        result = result.applyingTransform(.stripDiacritics, reverse: false) ?? result
        
        // 2. Remove Superscript Alef (단검 알리프 - "투명 인간" 모음)
        // U+0670: ARABIC LETTER SUPERSCRIPT ALEF - 키보드 입력 불가
        result = result.replacingOccurrences(of: "\u{0670}", with: "")
        
        // 3. Normalize Alef Wasla to regular Alef ("변장술" 알리프)
        // U+0671 → U+0627 - 키보드 입력 불가
        result = result.replacingOccurrences(of: "\u{0671}", with: "\u{0627}")
        
        // Note: آ (Madda), أ (Hamza Above), إ (Hamza Below)는 키보드 입력 가능하므로 유지
        
        return result
    }
    
    /// 키보드 입력용 정규화된 아랍어 문자열 (정답 비교용)
    /// withoutDiacritics에 추가로 공백 제거
    var normalizedArabicForComparison: String {
        return self.withoutDiacritics.replacingOccurrences(of: " ", with: "")
    }
}
