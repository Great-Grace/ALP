// StringHelpers - 문자열 처리 헬퍼
// 괄호 처리, 아랍어 필터링, 정규화

import SwiftUI

// MARK: - Parenthesis & Highlighting (Multi-target Support)
extension String {
    
    /// 따옴표 제거
    var withoutQuotes: String {
        return self.replacingOccurrences(of: "\"", with: "")
    }
    
    /// 괄호와 내용물 모두 추출 (복수 지원)
    /// "나는 (학생)이고 (선생님)이다" → targets: ["학생", "선생님"], cleaned: "나는 학생이고 선생님이다"
    func extractAllParenthesisContent() -> (targets: [String], cleaned: String) {
        let pattern = "\\(([^)]+)\\)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return ([], self)
        }
        
        let nsString = self as NSString
        let matches = regex.matches(in: self, range: NSRange(location: 0, length: nsString.length))
        
        var targets: [String] = []
        for match in matches {
            if let targetRange = Range(match.range(at: 1), in: self) {
                targets.append(String(self[targetRange]))
            }
        }
        
        // 괄호만 제거 (내용은 유지)
        let cleaned = self
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .withoutQuotes
        
        return (targets, cleaned)
    }
    
    /// AttributedString - 여러 타겟 단어에 Accent Color 적용 (폰트 사이즈/굵기 변경 없음)
    func highlightedAttributedString(targets: [String], highlightColor: Color = .accent) -> AttributedString {
        var attributed = AttributedString(self)
        
        for target in targets {
            var searchStart = attributed.startIndex
            while let range = attributed[searchStart...].range(of: target) {
                attributed[range].foregroundColor = highlightColor
                searchStart = range.upperBound
            }
        }
        
        return attributed
    }
    
    /// 단일 타겟 버전 (호환성)
    func highlightedAttributedString(target: String, highlightColor: Color = .accent) -> AttributedString {
        return highlightedAttributedString(targets: [target], highlightColor: highlightColor)
    }
}

// MARK: - Arabic Input Filtering
extension String {
    
    /// 아랍어 문자와 공백만 필터링
    var arabicOnly: String {
        return self.filter { char in
            char.unicodeScalars.allSatisfy { scalar in
                // Arabic Unicode range: 0600-06FF, 0750-077F, 08A0-08FF
                (0x0600...0x06FF).contains(scalar.value) ||
                (0x0750...0x077F).contains(scalar.value) ||
                (0x08A0...0x08FF).contains(scalar.value) ||
                scalar == " " // Allow spaces
            }
        }
    }
    
    /// 공백 제거 (정답 비교용)
    var withoutSpaces: String {
        return self.replacingOccurrences(of: " ", with: "")
    }
    
    /// 정규화된 정답 비교용 문자열 (모음 제거 + 공백 제거)
    var normalizedForComparison: String {
        return self.withoutDiacritics.withoutSpaces
    }
}

#Preview {
    let testString = "\"나는 (학생)이고 (선생님)이다\""
    let result = testString.extractAllParenthesisContent()
    let attributed = result.cleaned.highlightedAttributedString(targets: result.targets)
    return VStack(spacing: 16) {
        Text("Original: \(testString)")
        Text("Targets: \(result.targets.joined(separator: ", "))")
        Text("Cleaned: \(result.cleaned)")
        Text(attributed)
            .font(.title2)
    }
    .padding()
}

