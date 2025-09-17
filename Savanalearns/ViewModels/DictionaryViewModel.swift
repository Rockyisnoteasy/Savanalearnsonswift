// ViewModels/DictionaryViewModel.swift
import Foundation
import Combine
import AVFoundation
import CryptoKit


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
                
                // Use the String extension to check for Chinese characters
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
    
    /// Get simplified Chinese definition for a word
    func getSimplifiedDefinition(for word: String) -> String? {
        guard let fullDefinition = getDefinition(for: word) else { return nil }
        return chineseDefinitionExtractor.simplify(definition: fullDefinition)
    }
    
    func getRandomEnglishSentence(for word: String) -> (String, Int?)? {
        // 1. Use the pre-loaded map to find the entry for the word.
        guard let entry = wordMap[word.lowercased()],
              let sentencesText = entry.sentence, !sentencesText.isEmpty else {
            // No entry or no sentences for this word.
            return nil
        }

        // 2. Replicate the Kotlin logic: split by lines and find English sentences.
        let englishSentences = sentencesText.split(separator: "\n").compactMap { line -> String? in
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedLine.uppercased().starts(with: "EN") {
                // Find the sentence part after the "EN...-" prefix
                if let range = trimmedLine.range(of: "-") {
                    return String(trimmedLine[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                }
            }
            return nil
        }

        // 3. Pick one sentence at random.
        guard let randomSentence = englishSentences.randomElement() else {
            return nil
        }
        
        // 4. Find the word's position in the sentence for potential UI highlighting.
        let wordIndex = findWordIndexInSentence(sentence: randomSentence, word: word)
        
        return (randomSentence, wordIndex)
    }
    
    // MARK: - Helper Methods for Testing
    func getRandomDefinitions(excluding word: String, count: Int) -> [String] {
        // Get all words from wordMap except the current one
        let allWords = Array(wordMap.keys).filter {
            $0.lowercased() != word.lowercased()
        }
        
        // Randomly select 'count' words and get their FULL definitions
        let selectedWords = allWords.shuffled().prefix(count)
        
        return selectedWords.compactMap { selectedWord in
            // Get the FULL definition for each selected word
            // Then apply simplification using ChineseDefinitionExtractor
            if let fullDef = getDefinition(for: selectedWord) {
                return chineseDefinitionExtractor.simplify(definition: fullDef)
            }
            return nil
        }
    }

    
    private func findWordIndexInSentence(sentence: String, word: String) -> Int? {
        if let range = sentence.range(of: word, options: .caseInsensitive) {
            return sentence.distance(from: sentence.startIndex, to: range.lowerBound)
        }
        return nil
    }
    
    /// Get ultra-simplified Chinese definition for a word
    func getUltraSimplifiedDefinition(for word: String) -> String? {
        guard let simplified = getSimplifiedDefinition(for: word) else { return nil }
        return chineseDefinitionExtractor.ultraSimplify(simplifiedDefinition: simplified)
    }
    
    /// Get extracted Chinese definition (without simplification)
    func getExtractedDefinition(for word: String) -> String? {
        guard let fullDefinition = getDefinition(for: word) else { return nil }
        return chineseDefinitionExtractor.extract(definition: fullDefinition)
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

    
    /// Play word audio and then sentence audio
    func playWordAndThenSentence(_ word: String, _ sentence: String?, context: Any) {
        guard !word.isEmpty else { return }
        
        print("DEBUG: Playing audio for word '\(word)'")
        
        // Play word audio first
        VoiceCacheManager.shared.getOrDownloadWordAudio(word) { wordAudioURL in
            if let url = wordAudioURL {
                DispatchQueue.main.async {
                    // ACTUALLY PLAY THE AUDIO HERE
                    AudioManager.shared.playAudio(from: url) {
                        print("✅ Word audio finished playing: \(word)")
                        
                        // After word audio finishes, play sentence audio if available
                        if let sentenceText = sentence {
                            print("DEBUG: Now playing sentence audio")
                            VoiceCacheManager.shared.getOrDownloadSentenceAudio(sentenceText) { sentenceAudioURL in
                                if let sentenceURL = sentenceAudioURL {
                                    DispatchQueue.main.async {
                                        AudioManager.shared.playAudio(from: sentenceURL) {
                                            print("✅ Sentence audio finished playing")
                                        }
                                    }
                                } else {
                                    print("❌ Failed to get sentence audio URL")
                                }
                            }
                        }
                    }
                }
            } else {
                print("❌ Failed to get word audio URL for: \(word)")
            }
        }
    }

    /// Play word audio only
    func playWord(_ word: String, completion: (() -> Void)? = nil) {
        guard !word.isEmpty else {
            completion?()
            return
        }
        
        print("DEBUG: Playing single word audio for '\(word)'")
        
        VoiceCacheManager.shared.getOrDownloadWordAudio(word) { audioURL in
            if let url = audioURL {
                DispatchQueue.main.async {
                    // ACTUALLY PLAY THE AUDIO HERE
                    AudioManager.shared.playAudio(from: url, completion: completion)
                }
            } else {
                print("❌ Failed to get audio URL for word: \(word)")
                completion?()
            }
        }
    }
    
    /// Get random distractor words for multiple choice tests
    func getRandomDistractorWords(_ correctWord: String, count: Int = 3) -> [String] {
        let allWords = Array(wordMap.keys)
        let filtered = allWords.filter { $0 != correctWord.lowercased() }
        return Array(filtered.shuffled().prefix(count))
    }
    
    /// Get random distractor definitions for multiple choice tests
    func getRandomDistractorDefinitions(_ word: String, count: Int = 3) -> [String] {
        let correctDef = getDefinition(for: word)
        let allDefinitions = wordMap.values.compactMap { entry -> String? in
            entry.definition != correctDef ? entry.definition : nil
        }
        return Array(allDefinitions.shuffled().prefix(count))
    }
    
    // MARK: - Audio Playback Support
    @MainActor
    func playWord(_ word: String, completion: @escaping (Bool) -> Void) async {
        // Generate MD5 hash for the word (following Python logic)
        let wordLower = word.lowercased()
        let fileHash = wordLower.md5() + ".mp3"
        
        // Construct the audio URL from CDN with correct base URL
        let audioURLString = "https://wordsentencevoice.savanalearns.cc/voice_cache/\(fileHash)"
        
        guard let audioURL = URL(string: audioURLString) else {
            print("Invalid audio URL for word: \(word)")
            completion(false)
            return
        }
        
        // Check if we have cached audio locally
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let audioCache = documentsPath.appendingPathComponent("audio_cache", isDirectory: true)
        
        // Create cache directory if it doesn't exist
        try? FileManager.default.createDirectory(at: audioCache, withIntermediateDirectories: true)
        
        let localAudioFile = audioCache.appendingPathComponent(fileHash)
        
        do {
            var audioData: Data
            
            if FileManager.default.fileExists(atPath: localAudioFile.path) {
                // Use cached audio
                audioData = try Data(contentsOf: localAudioFile)
                print("Using cached audio for: \(word)")
            } else {
                // Download audio from CDN
                print("Downloading audio from: \(audioURLString)")
                let (data, _) = try await URLSession.shared.data(from: audioURL)
                audioData = data
                
                // Cache the audio file
                try audioData.write(to: localAudioFile)
                print("Cached audio for: \(word)")
            }
            
            // Play the audio
            let audioPlayer = try AVAudioPlayer(data: audioData)
            audioPlayer.prepareToPlay()
            audioPlayer.play()
            
            // Wait for playback to complete
            DispatchQueue.main.asyncAfter(deadline: .now() + audioPlayer.duration) {
                completion(true)
            }
            
        } catch {
            print("Failed to play audio for \(word): \(error)")
            completion(false)
        }
    }
}

extension String {
    func md5() -> String {
        let digest = Insecure.MD5.hash(data: self.data(using: .utf8) ?? Data())
        return digest.map {
            String(format: "%02hhx", $0)
        }.joined()
    }
}


