// Extensions/String+Extensions.swift
import Foundation

extension String {
    /// 檢查字串是否包含任何中文字元 (漢字)。
    public var containsChineseCharacters: Bool {
        // CJK (中日韓) 統一表意文字的 Unicode 範圍是 0x4E00 到 0x9FFF。
        // 我們遍歷字串中的每一個字元，檢查其 Unicode 純量值是否在此範圍內。
        return self.unicodeScalars.contains { scalar in
            return (scalar.value >= 0x4E00 && scalar.value <= 0x9FFF)
        }
    }
}

