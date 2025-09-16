//
//  TestCoordinator.swift
//  Savanalearns
//
//  Created by xiang guangzhen on 2025/9/16.
//

import Foundation
import SwiftUI

@MainActor
class TestCoordinator: ObservableObject {
    // MARK: - Published Properties
    @Published var currentSession: WordTestSession?
    @Published var isTestActive = false
    @Published var showingResults = false
    @Published var testQuestions: [TestQuestion] = []
    
    // MARK: - Dependencies
    private let authViewModel: AuthViewModel
    private let dictionaryViewModel: DictionaryViewModel
    
    // MARK: - Test Sequences (matching Kotlin)
    private let newWordTestSequence: [TestType] = [
        .wordToMeaningSelect,     // 以词选意
        .wordMeaningMatch,        // 词意匹配
        .meaningToWordSelect,     // 以意选词
        .chineseToEnglishSelect,  // 选择填词
        .chineseToEnglishSpell,   // 拼写填词
        .listeningTest,           // 听力填词
        .speechRecognitionTest    // 读词填空
    ]
    
    private let reviewTestSequence: [TestType] = [
        .chineseToEnglishSpell,   // 拼写填词
        .listeningTest,           // 听力填词
        .speechRecognitionTest    // 读词填空
    ]
    
    // MARK: - Initialization
    init(authViewModel: AuthViewModel, dictionaryViewModel: DictionaryViewModel) {
        self.authViewModel = authViewModel
        self.dictionaryViewModel = dictionaryViewModel
    }
    
    // MARK: - Public Methods
    
    /// Start a new test session
    func startTestSession(plan: Plan?, words: [String], isNewWordSession: Bool) {
        guard !words.isEmpty else {
            print("❌ [TestCoordinator] Cannot start session with empty words")
            return
        }
        
        print("🚀 [TestCoordinator] Starting \(isNewWordSession ? "new word" : "review") session with \(words.count) words")
        
        let sequence = isNewWordSession ? newWordTestSequence : reviewTestSequence
        
        currentSession = WordTestSession(
            planId: plan?.id,
            words: words,
            testSequence: sequence,
            isNewWordSession: isNewWordSession
        )
        
        isTestActive = true
        showingResults = false
        
        // Prepare questions for the first test
        prepareQuestionsForCurrentTest()
    }
    
    /// Process test completion and move to next
    func completeCurrentTest(results: [WordTestResult]) {
        guard var session = currentSession else { return }
        
        print("✅ [TestCoordinator] Test \(session.currentTestType?.displayName ?? "Unknown") completed with \(results.count) results")
        
        // Add results to session
        results.forEach { result in
            session.addResult(result)
            
            // Report to backend via AuthViewModel
            if let planId = session.planId {
                authViewModel.processTestAnswer(
                    word: result.word,
                    isCorrect: result.isCorrect,
                    testType: result.testType
                )
            }
        }
        
        // Move to next test
        session.moveToNextTest()
        currentSession = session
        
        if session.isComplete {
            finishSession()
        } else {
            prepareQuestionsForCurrentTest()
        }
    }
    
    /// Cancel current session
    func cancelSession() {
        print("🛑 [TestCoordinator] Session cancelled")
        currentSession = nil
        isTestActive = false
        showingResults = false
        testQuestions = []
        authViewModel.endSession()
    }
    
    /// Retry failed words
    func retryFailedWords() {
        guard let session = currentSession else { return }
        
        let failedWords = session.results
            .filter { !$0.isCorrect }
            .map { $0.word }
            .uniqued() // Remove duplicates
        
        if !failedWords.isEmpty {
            print("🔄 [TestCoordinator] Retrying \(failedWords.count) failed words")
            
            // For retry, we don't need a specific plan, just the words
            currentSession = WordTestSession(
                planId: session.planId,  // Keep the same plan ID if exists
                words: failedWords,
                testSequence: reviewTestSequence,  // Use review sequence for retry
                isNewWordSession: false
            )
            
            isTestActive = true
            showingResults = false
            prepareQuestionsForCurrentTest()
        }
    }
    // MARK: - Private Methods
    
    private func prepareQuestionsForCurrentTest() {
        guard let session = currentSession,
              let testType = session.currentTestType else { return }
        
        print("📝 [TestCoordinator] Preparing questions for \(testType.displayName)")
        
        testQuestions = session.words.compactMap { word in
            createTestQuestion(for: word, testType: testType)
        }.shuffled()
    }
    
    private func createTestQuestion(for word: String, testType: TestType) -> TestQuestion? {
        let definition = dictionaryViewModel.getDefinition(for: word)
        
        // Extract Chinese based on test type (matching Kotlin logic)
        let chinese: String?
        
        switch testType {
        case .wordToMeaningSelect:
            // For word to meaning select, use simplified definition not full
            chinese = dictionaryViewModel.getSimplifiedDefinition(for: word)
            
        case .wordMeaningMatch:
            // Use ultra-simplified for matching
            chinese = dictionaryViewModel.getUltraSimplifiedDefinition(for: word)
            
        case .meaningToWordSelect, .chineseToEnglishSelect, .chineseToEnglishSpell, .listeningTest, .speechRecognitionTest:
            // Use extracted Chinese for these tests
            chinese = dictionaryViewModel.getExtractedDefinition(for: word)
        }
        
        guard let chineseText = chinese, !chineseText.isEmpty else {
            print("⚠️ [TestCoordinator] No Chinese found for word: \(word)")
            return nil
        }
        
        return TestQuestion(
            word: word,
            chinese: chineseText,
            fullDefinition: definition,
            additionalData: nil
        )
    }
    
    private func finishSession() {
        guard let session = currentSession else { return }
        
        print("🎉 [TestCoordinator] Session complete! Accuracy: \(String(format: "%.1f%%", session.accuracy * 100))")
        
        showingResults = true
        authViewModel.endSession()
        
        // Refresh the daily session if there's a plan
        if let planId = session.planId {
            authViewModel.fetchDailySession(for: planId)
        }
    }
    
    // MARK: - Chinese Extraction (placeholder - implement based on your logic)
    
    private func extractChinese(from definition: String?) -> String? {
        guard let def = definition else { return nil }
        return dictionaryViewModel.getExtractedDefinition(for: def)
            ?? def.components(separatedBy: ";").first?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractSimplifiedChinese(from definition: String?) -> String? {
        guard let def = definition else { return nil }
        // Use ultra-simplified for matching tests
        return dictionaryViewModel.getUltraSimplifiedDefinition(for: def)
            ?? String(def.prefix(10))
    }
}

// MARK: - Helper Extension
extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
