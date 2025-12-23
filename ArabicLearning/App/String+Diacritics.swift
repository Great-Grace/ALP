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
    var withoutDiacritics: String {
        return self.applyingTransform(.stripDiacritics, reverse: false) ?? self
    }
}
