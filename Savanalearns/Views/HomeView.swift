// Views/HomeView.swift
import SwiftUI

struct HomeView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @StateObject private var dictionaryViewModel = DictionaryViewModel()

    // Navigation and session state
    @State private var showFlipCard = false
    @State private var wordsForCurrentSession: [String] = []
    @State private var currentPlanForTest: Plan? = nil
    @State private var isNewWordSession: Bool = true
    
    // Test sequence states (for future implementation)
    @State private var showTestSequence = false
    @State private var currentTestIndex = 0
    @State private var testResults: [TestResult] = []

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Search bar at the top
                DictionarySearchBarView()
                    .padding(.horizontal)
                
                // Learning plans with callback handlers
                LearningPlanView(
                    authViewModel: authViewModel,
                    onStartLearnNew: { plan, words in
                        startLearningSession(plan: plan, words: words, isNewWords: true)
                    },
                    onStartReview: { plan, words in
                        startLearningSession(plan: plan, words: words, isNewWords: false)
                    }
                )
                .padding(.horizontal)
            }
            .padding(.top)
        }
        .background(Color(.systemGroupedBackground).edgesIgnoringSafeArea(.all))
        .navigationTitle("SavanaLearns")
        .navigationBarTitleDisplayMode(.inline)
        .environmentObject(dictionaryViewModel)
        .fullScreenCover(isPresented: $showFlipCard) {
            NavigationView {
                FlipCardView(
                    wordList: wordsForCurrentSession,
                    isNewWordSession: isNewWordSession,
                    plan: currentPlanForTest,
                    onSessionComplete: {
                        handleFlipCardSessionComplete()
                    },
                    onBack: {
                        handleFlipCardBack()
                    }
                )
                .environmentObject(dictionaryViewModel)
                .environmentObject(authViewModel)
            }
        }
        // Future: Add test sequence presentation
        .fullScreenCover(isPresented: $showTestSequence) {
            NavigationView {
                // TestSequenceView would handle the multiple test types
                EmptyView() // Placeholder for TestSequenceView
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func startLearningSession(plan: Plan, words: [String], isNewWords: Bool) {
        print("DEBUG: startLearningSession called")
        print("DEBUG: Plan: \(plan.planName), isNewWords: \(isNewWords)")
        print("DEBUG: Words received: \(words)")
        print("DEBUG: Words count: \(words.count)")
        
        print("MainActivity: Starting \(isNewWords ? "NEW WORD" : "REVIEW") session for planId=\(plan.id)")
        
        // Set up session data
        currentPlanForTest = plan
        wordsForCurrentSession = words
        isNewWordSession = isNewWords
        
        print("DEBUG: wordsForCurrentSession set to: \(wordsForCurrentSession)")
        print("DEBUG: About to show FlipCard with words: \(wordsForCurrentSession)")
        
        // Register session with AuthViewModel
        authViewModel.startSession(plan: plan, words: words)
        
        // Show FlipCard view
        DispatchQueue.main.async {
            self.showFlipCard = true
        }
    }
    
    private func handleFlipCardSessionComplete() {
        print("翻牌记忆环节结束")
        
        // Filter out familiar words
        let familiarWords = authViewModel.familiarWords
        let filteredWords = wordsForCurrentSession.filter { word in
            !familiarWords.contains(word.lowercased())
        }
        
        if isNewWordSession {
            print("熟词过滤后，本轮测试将包含 \(filteredWords.count) 个单词。")
            
            if filteredWords.isEmpty {
                // All words marked as familiar, skip tests
                print("所有单词已标记为熟悉，跳过测试")
                completeSession()
            } else {
                // Update words for testing
                wordsForCurrentSession = filteredWords
                // Start new word test sequence
                startTestSequence(isNewWordFlow: true)
            }
        } else {
            print("复习session完成")
            print("熟词过滤后，复习测试将包含 \(filteredWords.count) 个单词。")
            
            if filteredWords.isEmpty {
                print("所有复习单词已标记为熟悉，跳过测试")
                completeSession()
            } else {
                // Update words for testing
                wordsForCurrentSession = filteredWords
                // Start review test sequence
                startTestSequence(isNewWordFlow: false)
            }
        }
        
        // Close FlipCard view
        showFlipCard = false
    }
    
    private func handleFlipCardBack() {
        // User pressed back button in FlipCard
        print("用户退出翻牌记忆")
        
        // End the session
        authViewModel.endSession()
        
        // Close FlipCard view
        showFlipCard = false
    }
    
    private func startTestSequence(isNewWordFlow: Bool) {
        // Define test sequences based on flow type
        let testSequence: [String]
        
        if isNewWordFlow {
            // New word test sequence (comprehensive)
            testSequence = [
                "word_to_meaning_select",     // 以词选意
                "word_meaning_match",          // 词意匹配
                "meaning_to_word_select",      // 以意选词
                "chinese_select",              // 选择填词
                "chinese_spell",               // 拼写填词
                "listening_test",              // 听力填词
                "speech_recognition_test"      // 读词填空
            ]
        } else {
            // Review test sequence (shorter, focused on recall)
            testSequence = [
                "chinese_spell",
                "listening_test",
                "speech_recognition_test"
            ]
        }
        
        print("Starting test sequence for \(isNewWordFlow ? "new words" : "review")")
        print("Test sequence: \(testSequence)")
        
        // Reset test state
        currentTestIndex = 0
        testResults = []
        
        // TODO: Implement test sequence navigation
        // For now, just log and complete
        print("TODO: Implement test sequence views")
        
        // Temporary: directly complete session
        completeSession()
        
        // When implemented, uncomment:
        // showTestSequence = true
    }
    
    private func completeSession() {
        print("Session fully completed")
        
        // End the session in AuthViewModel
        authViewModel.endSession()
        
        // Refresh the daily session to update UI
        if let plan = currentPlanForTest, let planId = plan.id {
            authViewModel.fetchDailySession(for: planId)
        }
        
        // Reset session variables
        currentPlanForTest = nil
        wordsForCurrentSession = []
        isNewWordSession = true
    }
}

// MARK: - Test Result Structure (for future use)
struct TestResult {
    let word: String
    let testType: String
    let isCorrect: Bool
    let userAnswer: String?
}

// MARK: - Preview Provider
struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            HomeView(authViewModel: AuthViewModel())
        }
    }
}
