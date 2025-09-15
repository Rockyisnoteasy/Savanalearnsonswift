// Utils/ChineseDefinitionExtractor.swift
import Foundation

class ChineseDefinitionExtractor {
    
    /// Extract the Chinese definition portion from the full definition string
    func extract(definition: String?) -> String? {
        guard let def = definition, !def.isEmpty else { return nil }
        
        // Find the start position of "中文释义："
        guard let startRange = def.range(of: "中文释义：") else { return nil }
        
        let startIdx = startRange.upperBound
        
        // Find the end position (before "词性：" if it exists)
        if let endRange = def[startIdx...].range(of: "词性：") {
            let endIdx = def.index(startIdx, offsetBy: def.distance(from: startIdx, to: endRange.lowerBound))
            return String(def[startIdx..<endIdx]).trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            // If no "词性：" found, take everything after "中文释义："
            return String(def[startIdx...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    
    /// Simplify the Chinese definition by removing parentheses, splitting by punctuation, etc.
    func simplify(definition: String?) -> String? {
        guard let raw = extract(definition: definition) else { return nil }
        
        // Split by newlines or numbered items (1. 2. or 1、2、)
        let pattern = #"\n|\r|\d+[\.\、]"#
        let lines = raw.split(separator: try! Regex(pattern))
        
        // Process each line
        let processedLines = lines.compactMap { line -> String? in
            var processed = String(line).trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Remove parentheses and their content (both Chinese and English style)
            processed = processed.replacingOccurrences(
                of: #"（.*?）|\(.*?\)"#,
                with: "",
                options: .regularExpression
            )
            
            // Split by commas or semicolons and take the first part
            let parts = processed.split(separator: try! Regex("[,，；;]"))
            if let firstPart = parts.first {
                let result = String(firstPart).trimmingCharacters(in: .whitespacesAndNewlines)
                return result.isEmpty ? nil : result
            }
            return nil
        }
        
        // Filter out empty strings and join with semicolons
        let filtered = processedLines.filter { !$0.isEmpty }
        return filtered.isEmpty ? nil : filtered.joined(separator: "；")
    }
    
    /// Ultra-simplify to get a single, most concise definition
    func ultraSimplify(simplifiedDefinition: String?) -> String? {
        guard let simplified = simplifiedDefinition, !simplified.isEmpty else { return nil }
        
        // Split by semicolons
        let parts = simplified.split(separator: "；").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        let filteredParts = parts.filter { !$0.isEmpty }
        
        // Remove part-of-speech prefixes (n. v. adj. etc.)
        let cleanedParts = filteredParts.map { part in
            part.replacingOccurrences(
                of: #"^(n|v|adj|adv|prep|pron|conj|interj|int)\.\s*"#,
                with: "",
                options: .regularExpression
            ).trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty }
        
        // Return a random one from the valid definitions
        return cleanedParts.randomElement() ?? simplifiedDefinition
    }
}

// Helper extension for Regex splitting (if not already in project)
extension String {
    func split(separator: Regex) -> [Substring] {
        var results: [Substring] = []
        var currentIndex = self.startIndex
        
        let matches = self.matches(of: separator)
        for match in matches {
            if currentIndex < match.range.lowerBound {
                results.append(self[currentIndex..<match.range.lowerBound])
            }
            currentIndex = match.range.upperBound
        }
        
        if currentIndex < self.endIndex {
            results.append(self[currentIndex..<self.endIndex])
        }
        
        return results
    }
}
