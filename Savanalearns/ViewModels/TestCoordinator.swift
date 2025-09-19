//
//  TestCoordinator.swift
//  Savanalearns
//
//  Created by xiang guangzhen on 2025/9/16.
//

import Foundation
import SwiftUI

struct TestResult {
    let word: String
    let isCorrect: Bool
}

@MainActor
class TestCoordinator: ObservableObject {
    // MARK: - Published Properties
    @Published var currentSession: WordTestSession?
    @Published var isTestActive = false
    @Published var showingResults = false
    @Published var testQuestions: [TestQuestion] = []
    @Published var sessionLearningReport: [String: [Bool]] = [:]
    
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
        
        print("✅ [TestCoordinator] Test \(session.currentTestType?.displayName ?? "Unknown") completed with \(results.count) results.")
        
        session.results.append(contentsOf: results)
        
        // --- Step 1: Record results instead of sending them ---
        // Convert [WordTestResult] to the simpler [TestResult] format.
        let simpleResults = results.map { TestResult(word: $0.word, isCorrect: $0.isCorrect) }
        
        // Record the results from this test module in our session report.
        recordTestResult(results: simpleResults)
        
        // --- Step 2: Move to the next test ---
        session.moveToNextTest()
        currentSession = session
        
        // --- Step 3: Check if the entire session is now complete ---
        if session.isComplete {
            // The session is finished. FINALIZE and SUBMIT the summary report.
            if let planId = session.planId {
                print("🚀 [Debug] All tests complete. Finalizing and submitting round results...")
                finalizeAndSubmitRoundResults(authViewModel: authViewModel, planId: planId)
            }
            
            // Now, call the original finish function.
            finishSession()
            
        } else {
            // The session is not complete, prepare questions for the next test.
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
        case .wordToMeaningSelect, .speechRecognitionTest:
            // For word to meaning select, use simplified definition not full
            chinese = dictionaryViewModel.getSimplifiedDefinition(for: word)
            
        case .wordMeaningMatch:
            // Use ultra-simplified for matching
            chinese = dictionaryViewModel.getUltraSimplifiedDefinition(for: word)

        
        case .meaningToWordSelect, .chineseToEnglishSelect, .chineseToEnglishSpell, .listeningTest:
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
    
    private func prepareSpeechRecognitionQuestions(for words: [String]) -> [TestQuestion] {
        return words.compactMap { word in
            guard let fullDefinition = dictionaryViewModel.getDefinition(for: word),
                  let chineseMeaning = dictionaryViewModel.getExtractedDefinition(for: word) else {
                print("⚠️ [TestCoordinator] No Chinese definition found for word: \(word)")
                return nil
            }
            
            return TestQuestion(
                word: word,
                chinese: chineseMeaning,
                fullDefinition: fullDefinition,
                additionalData: nil
            )
        }
    }
}

// MARK: - Helper Extension
extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

extension TestCoordinator {
    
    // Call this from each test view's 'onFinish' callback
    func recordTestResult(results: [TestResult]) {
        
        print("➡️ [Debug] Recording \(results.count) results. Current report has \(sessionLearningReport.count) words.")
            
        for result in results {
            sessionLearningReport[result.word, default: []].append(result.isCorrect)
        }
    }

    // Call this when the entire test sequence for a round is complete
    func finalizeAndSubmitRoundResults(authViewModel: AuthViewModel, planId: Int) {
        
        print("🚀 [Debug] Starting finalizeAndSubmitRoundResults for plan ID: \(planId)")
        print("   [Debug] Found \(sessionLearningReport.count) words in the final report.")

        
        for (word, results) in sessionLearningReport {
            // Determines final correctness: true only if all tests were passed.
            let finalIsCorrect = !results.isEmpty && results.allSatisfy { $0 }

            // Call the ViewModel to send the data to the server
            authViewModel.processTestAnswer(
                word: word,
                isCorrect: finalIsCorrect,
                testType: "round_end_assessment",
                planId: planId
            )
        }
        
        // You might want to clear the report for the next round after submission
        // sessionLearningReport.removeAll()
    }
}
