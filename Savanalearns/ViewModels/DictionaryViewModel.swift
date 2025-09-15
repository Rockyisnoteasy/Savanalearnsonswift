// ViewModels/DictionaryViewModel.swift
import Foundation
import Combine

@MainActor
class DictionaryViewModel: ObservableObject {
    
    // MARK: - Published Properties for UI
    @Published var searchInput: String = ""
    @Published var searchResultDefinition: String?
    @Published var suggestions: [(word: String, definition: String)] = []
    @Published var isLoading: Bool = false
    
    // MARK: - Private Properties
    private var wordMap: [String: WordEntry] = [:]
    private var relatedWordMap: [String: String] = [:]
    private var cancellables = Set<AnyCancellable>()
    private let databaseService = DatabaseService.shared
    
    // A Swift equivalent of the Android utility
    private let chineseDefinitionExtractor = ChineseDefinitionExtractor()
    private var isDictionaryLoaded = false

    init() {
        // Load the dictionary asynchronously when the ViewModel is created.
        Task {
            await loadDictionary()
        }
        setupSearchDebounce()
    }
    
    private func loadDictionary() async {
        if isDictionaryLoaded { return }
        self.isLoading = true
        
        print("⏳ DictionaryViewModel: Starting dictionary load...")
        
        do {
            let allEntries = try await databaseService.loadAllWordEntries()
            
            // --- Build high-performance lookup maps ---
            var tempWordMap: [String: WordEntry] = [:]
            var tempRelatedMap: [String: String] = [:]
            
            for entry in allEntries {
               let lowercasedWord = entry.value.word.lowercased()
                tempWordMap[lowercasedWord] = entry.value
                
                // Parse relatedWords field, which is a stringified JSON array
                if let relatedWordsString = entry.value.relatedWords,
                   let data = relatedWordsString.data(using: .utf8) {
                    if let variants = try? JSONDecoder().decode([String].self, from: data) {
                        for variant in variants where !variant.isEmpty {
                            tempRelatedMap[variant.lowercased()] = lowercasedWord
                        }
                    }
                }
            }
            
            self.wordMap = tempWordMap
            self.relatedWordMap = tempRelatedMap
            self.isDictionaryLoaded = true
            self.isLoading = false
            print("✅ DictionaryViewModel: Dictionary loaded. \(self.wordMap.count) main words, \(self.relatedWordMap.count) variants mapped.")
            
        } catch {
            self.isLoading = false
            print("❌ DictionaryViewModel: Failed to load dictionary: \(error.localizedDescription)")
        }
    }
    
    private func setupSearchDebounce() {
        $searchInput
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .map { [weak self] text -> [(String, String)] in
                guard let self = self, !text.isEmpty else { return [] }
                
                // **FIXED**: Use the new String extension here
                if text.containsChineseCharacters {
                    return self.queryByChineseKeyword(keyword: text)
                } else {
                    return self.getSuggestions(for: text)
                }
            }
            .assign(to: \.suggestions, on: self)
            .store(in: &cancellables)
    }
    
    /// **Core lookup logic**, a direct port from the Android version.
    func getDefinition(for word: String) -> String? {
        let searchWord = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if searchWord.isEmpty { return nil }
        
        // 1. Direct lookup in the main word map
        if let entry = wordMap[searchWord] {
            return entry.definition
        }
        
        // 2. If not found, look for its root word in the related words map
        if let rootWord = relatedWordMap[searchWord] {
            return wordMap[rootWord]?.definition
        }
        
        // Return nil if nothing is found, letting the UI decide what to display
        return nil
    }

    /// Provides search suggestions for an English keyword prefix.
    private func getSuggestions(for keyword: String) -> [(String, String)] {
        let lowercasedKeyword = keyword.lowercased()
        
        // Filter keys (words) directly for performance, then map to values
        let filteredWords = wordMap.keys
            .filter { $0.starts(with: lowercasedKeyword) }
            .prefix(10)
        
        return filteredWords.compactMap { word in
            guard let entry = wordMap[word] else { return nil }
            let simplifiedDef = chineseDefinitionExtractor.simplify(definition: entry.definition)
            return (entry.word, simplifiedDef ?? "...")
        }
    }
    
    /// Searches for words based on a Chinese keyword in the definition.
    private func queryByChineseKeyword(keyword: String) -> [(String, String)] {
        // This can be slow on large datasets, but matches Android's logic.
        let filteredEntries = wordMap.values.filter {
            $0.definition.contains(keyword)
        }.prefix(10)
        
        return filteredEntries.map { entry in
            let simplifiedDef = chineseDefinitionExtractor.simplify(definition: entry.definition)
            return (entry.word, simplifiedDef ?? "...")
        }
    }
}


// MARK: - Chinese Definition Extractor Utility

// You can move this to its own file in a `Utils` group later for better organization.
class ChineseDefinitionExtractor {
    func simplify(definition: String?) -> String? {
        guard let def = definition else { return nil }
        
        // This logic is a direct Swift translation of your Kotlin version.
        guard let startRange = def.range(of: "中文释义：") else { return nil }
        
        var chinesePart = def[startRange.upperBound...]
        
        if let endRange = chinesePart.range(of: "词性：") {
            chinesePart = chinesePart[..<endRange.lowerBound]
        }
        
        return chinesePart
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .newlines).first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
