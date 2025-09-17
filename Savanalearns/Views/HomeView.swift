// Views/HomeView.swift
import SwiftUI

struct HomeView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @StateObject private var dictionaryViewModel = DictionaryViewModel()
    
    @StateObject private var testCoordinator: TestCoordinator

    // Navigation and session state
    @State private var showFlipCard = false
    @State private var wordsForCurrentSession: [String] = []
    @State private var currentPlanForTest: Plan? = nil
    @State private var isNewWordSession: Bool = true
    
    @State private var flipCardSession: FlipCardSession? = nil
    
    @State private var activeTestType: TestType? = nil
    @State private var showingTestResults = false
    
    @State private var wordsToPass: [String] = []
    
    init(authViewModel: AuthViewModel) {
        self.authViewModel = authViewModel
        // Initialize TestCoordinator with dependencies
        let dictionaryVM = DictionaryViewModel()
        self._dictionaryViewModel = StateObject(wrappedValue: dictionaryVM)
        self._testCoordinator = StateObject(wrappedValue: TestCoordinator(
            authViewModel: authViewModel,
            dictionaryViewModel: dictionaryVM
        ))
    }

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
        // Future: Add test sequence presentation
        .fullScreenCover(item: $flipCardSession) { session in
            NavigationView {
                FlipCardView(
                    wordList: session.words,
                    isNewWordSession: session.isNewWords,
                    plan: session.plan,
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
        
        .fullScreenCover(item: $activeTestType) { testType in
            NavigationView {
                testViewForType(testType)
                    .environmentObject(dictionaryViewModel)
                    .environmentObject(authViewModel)
            }
        }
        
        .fullScreenCover(isPresented: $showingTestResults) {
            NavigationView {
                TestResultsView(
                    testCoordinator: testCoordinator,
                    onComplete: {
                        showingTestResults = false
                        completeSession()
                    },
                    onRetry: {
                        showingTestResults = false
                        testCoordinator.retryFailedWords()
                    }
                )
            }
        }

        .onChange(of: testCoordinator.currentSession?.currentTestType) { newTestType in
            // Update the active test type to trigger view presentation
            if testCoordinator.isTestActive && !testCoordinator.showingResults {
                activeTestType = newTestType
            }
        }
        // ADD THIS OBSERVER FOR RESULTS:
        .onChange(of: testCoordinator.showingResults) { showingResults in
            if showingResults {
                activeTestType = nil  // Dismiss current test
                showingTestResults = true
            }
        }
    }
    
    // MARK: - Helper Functions
    private func startLearningSession(plan: Plan, words: [String], isNewWords: Bool) {
        print("DEBUG: startLearningSession called")
        print("DEBUG: Plan: \(plan.planName), isNewWords: \(isNewWords)")
        print("DEBUG: Words received: \(words)")
        print("DEBUG: Words count: \(words.count)")
        
        guard !words.isEmpty else {
            print("ERROR: Cannot start session with empty words")
            return
        }
        
        print("MainActivity: Starting \(isNewWords ? "NEW WORD" : "REVIEW") session for planId=\(plan.id)")
        
        // Set up session data
        currentPlanForTest = plan
        wordsForCurrentSession = words
        wordsToPass = words  // Keep this for compatibility
        isNewWordSession = isNewWords
        
        print("DEBUG: wordsForCurrentSession set to: \(wordsForCurrentSession)")
        
        // Register session with AuthViewModel
        authViewModel.startSession(plan: plan, words: words)
        
        // Create and set the session object - this will trigger the presentation
        flipCardSession = FlipCardSession(
            words: words,
            plan: plan,
            isNewWords: isNewWords
        )
        
        print("DEBUG: FlipCardSession created with \(words.count) words")
    }
    
    
    private func handleFlipCardSessionComplete() {
        
        flipCardSession = nil
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
        flipCardSession = nil
    }
    
    private func startTestSequence(isNewWordFlow: Bool) {
        print("Starting test sequence for \(isNewWordFlow ? "new words" : "review")")
        
        // Use TestCoordinator instead of local logic
        testCoordinator.startTestSession(
            plan: currentPlanForTest,
            words: wordsForCurrentSession,
            isNewWordSession: isNewWordFlow
        )
        
        // Navigation will be handled by showing test views
        // This will be implemented in the next step
    }
    
    private func completeSession() {
        print("Session fully completed")
        
        // Cancel any ongoing test session
        testCoordinator.cancelSession()
        
        // End the session in AuthViewModel
        authViewModel.endSession()
        
        // Refresh the daily session to update UI
        if let plan = currentPlanForTest, let planId = plan.id {
            authViewModel.fetchDailySession(for: planId)
        }
        
        // Reset session variables
        currentPlanForTest = nil
        wordsForCurrentSession = []
        wordsToPass = []
        isNewWordSession = true
    }
    
    @ViewBuilder
    private func testViewForType(_ testType: TestType) -> some View {
        switch testType {
        case .wordToMeaningSelect:
            WordToMeaningSelectView(
                testCoordinator: testCoordinator,
                questions: testCoordinator.testQuestions,
                onComplete: {
                    // Move to next test or show results
                    activeTestType = nil
                },
                onBack: {
                    testCoordinator.cancelSession()
                    activeTestType = nil
                }
            )
        
        case .wordMeaningMatch:
            WordMeaningMatchView(
                testCoordinator: testCoordinator,
                questions: testCoordinator.testQuestions,
                onComplete: {
                    // Move to next test or show results
                    activeTestType = nil
                },
                onBack: {
                    testCoordinator.cancelSession()
                    activeTestType = nil
                }
            )
        
        case .meaningToWordSelect:
            MeaningToWordSelectView(
                testCoordinator: testCoordinator,
                dictionaryViewModel: dictionaryViewModel,
                questions: testCoordinator.testQuestions,
                onComplete: {
                    // Move to next test or show results
                    activeTestType = nil
                },
                onBack: {
                    testCoordinator.cancelSession()
                    activeTestType = nil
                }
            )
        
        case .chineseToEnglishSelect:
            ChineseToEnglishSelectView(
                testCoordinator: testCoordinator,
                questions: testCoordinator.testQuestions,
                onComplete: {
                    // Move to next test or show results
                    activeTestType = nil
                },
                onBack: {
                    testCoordinator.cancelSession()
                    activeTestType = nil
                }
            )
        
        case .chineseToEnglishSpell:
            ChineseToEnglishSpellView(
                testCoordinator: testCoordinator,
                questions: testCoordinator.testQuestions,
                onComplete: {
                    // Move to next test or show results
                    activeTestType = nil
                },
                onBack: {
                    testCoordinator.cancelSession()
                    activeTestType = nil
                }
            )
        
        case .listeningTest:
            ListeningTestView(
                testCoordinator: testCoordinator,
                dictionaryViewModel: dictionaryViewModel,
                questions: testCoordinator.testQuestions,
                onComplete: {
                    // Move to next test or show results
                    activeTestType = nil
                },
                onBack: {
                    testCoordinator.cancelSession()
                    activeTestType = nil
                }
            )
        
        case .speechRecognitionTest:
            Text("读词填空 Test - Coming Soon")
                .navigationBarItems(
                    leading: Button("Back") {
                        testCoordinator.cancelSession()
                        activeTestType = nil
                    }
                )
        }
    }
}

struct FlipCardSession: Identifiable {
    let id = UUID()
    let words: [String]
    let plan: Plan
    let isNewWords: Bool
}

// MARK: - Preview Provider
struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            HomeView(authViewModel: AuthViewModel())
        }
    }
}
