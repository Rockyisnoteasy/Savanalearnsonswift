//
//  WordMeaningMatchView.swift
//  Savanalearns
//
//  Created by xiang guangzhen on 2025/9/16.
//

//
//  WordMeaningMatchView.swift
//  Savanalearns
//
//  Word Meaning Match Test - 词意匹配
//  Users match English words with their Chinese meanings
//

import SwiftUI

struct WordMeaningMatchView: View {
    @ObservedObject var testCoordinator: TestCoordinator
    let questions: [TestQuestion]
    let onComplete: () -> Void
    let onBack: () -> Void
    
    // MARK: - State Properties
    @State private var remainingPairs: [(word: String, meaning: String)] = []
    @State private var currentRoundWords: [String] = []
    @State private var currentRoundMeanings: [String] = []
    @State private var matchedWordsInRound: Set<String> = []
    @State private var selectedWord: String? = nil
    @State private var incorrectSelection: (word: String?, meaning: String?) = (nil, nil)
    @State private var incorrectWordsInSession: Set<String> = []
    @State private var showIncorrectFeedback = false
    
    // Animation states
    @State private var matchAnimations: [String: Bool] = [:]
    @State private var incorrectAnimations: [String: Bool] = [:]
    
    // Constants
    private let wordsPerRound = 4
    private let incorrectFeedbackDuration = 0.8
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            testHeader
            
            // Progress indicator
            progressBar
            
            // Main content
            if !currentRoundWords.isEmpty {
                matchingArea
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading: backButton)
        .onAppear {
            setupTest()
        }
    }
    
    // MARK: - View Components
    
    private var testHeader: some View {
        VStack(spacing: 4) {
            Text("词意匹配")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("请将左侧的单词与右侧的释义进行匹配")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 2)
    }
    
    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 4)
                
                Rectangle()
                    .fill(Color.blue)
                    .frame(
                        width: geometry.size.width * progressPercentage,
                        height: 4
                    )
                    .animation(.easeInOut(duration: 0.3), value: progressPercentage)
            }
        }
        .frame(height: 4)
    }
    
    private var matchingArea: some View {
        HStack(spacing: 20) {
            // Left column - Words
            VStack(spacing: 12) {
                ForEach(currentRoundWords, id: \.self) { word in
                    MatchItem(
                        text: word,
                        isWord: true,
                        isSelected: selectedWord == word,
                        isMatched: matchedWordsInRound.contains(word),
                        isIncorrect: incorrectSelection.word == word && showIncorrectFeedback,
                        matchAnimation: matchAnimations[word] ?? false
                    ) {
                        if !matchedWordsInRound.contains(word) {
                            handleWordSelection(word)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            
            // Right column - Meanings
            VStack(spacing: 12) {
                ForEach(currentRoundMeanings, id: \.self) { meaning in
                    let matchedWord = findWordForMeaning(meaning)
                    MatchItem(
                        text: meaning,
                        isWord: false,
                        isSelected: false,
                        isMatched: matchedWord != nil && matchedWordsInRound.contains(matchedWord!),
                        isIncorrect: incorrectSelection.meaning == meaning && showIncorrectFeedback,
                        matchAnimation: matchAnimations[meaning] ?? false
                    ) {
                        if let word = selectedWord {
                            handleMeaningSelection(word: word, meaning: meaning)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
    }
    
    private var backButton: some View {
        Button(action: {
            onBack()
        }) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                Text("返回")
            }
        }
    }
    
    // MARK: - Helper Properties
    
    private var progressPercentage: Double {
        let totalPairs = questions.count
        let completedPairs = totalPairs - remainingPairs.count
        return totalPairs > 0 ? Double(completedPairs) / Double(totalPairs) : 0
    }
    
    private func findWordForMeaning(_ meaning: String) -> String? {
        questions.first { $0.chinese == meaning }?.word
    }
    
    // MARK: - Setup and Logic
    
    private func setupTest() {
        // Initialize pairs from questions
        remainingPairs = questions.map { (word: $0.word, meaning: $0.chinese) }
        startNewRound()
    }
    
    private func startNewRound() {
        guard !remainingPairs.isEmpty else {
            completeTest()
            return
        }
        
        // Take up to wordsPerRound pairs for this round
        let roundPairs = Array(remainingPairs.prefix(wordsPerRound))
        currentRoundWords = roundPairs.map { $0.word }
        currentRoundMeanings = roundPairs.map { $0.meaning }.shuffled()
        matchedWordsInRound = []
        selectedWord = nil
        incorrectSelection = (nil, nil)
        showIncorrectFeedback = false
        
        // Reset animations
        matchAnimations = [:]
        incorrectAnimations = [:]
    }
    
    private func handleWordSelection(_ word: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedWord = word
        }
    }
    
    private func handleMeaningSelection(word: String, meaning: String) {
        // Find the correct meaning for the selected word
        let correctMeaning = questions.first { $0.word == word }?.chinese
        
        if correctMeaning == meaning {
            // Correct match
            handleCorrectMatch(word: word, meaning: meaning)
        } else {
            // Incorrect match
            handleIncorrectMatch(word: word, meaning: meaning)
        }
    }
    
    private func handleCorrectMatch(word: String, meaning: String) {
        // Trigger match animation
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            matchAnimations[word] = true
            matchAnimations[meaning] = true
            matchedWordsInRound.insert(word)
            selectedWord = nil
        }
        
        // Check if round is complete
        if matchedWordsInRound.count == currentRoundWords.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                moveToNextRound()
            }
        }
    }
    
    private func handleIncorrectMatch(word: String, meaning: String) {
        // Mark this word as having an error
        incorrectWordsInSession.insert(word)
        
        // Show incorrect feedback
        withAnimation(.easeInOut(duration: 0.2)) {
            incorrectSelection = (word, meaning)
            showIncorrectFeedback = true
        }
        
        // Reset after feedback duration
        DispatchQueue.main.asyncAfter(deadline: .now() + incorrectFeedbackDuration) {
            withAnimation(.easeInOut(duration: 0.2)) {
                incorrectSelection = (nil, nil)
                showIncorrectFeedback = false
                selectedWord = nil
            }
        }
    }
    
    private func moveToNextRound() {
        // Remove completed pairs
        remainingPairs.removeFirst(min(wordsPerRound, remainingPairs.count))
        
        if remainingPairs.isEmpty {
            completeTest()
        } else {
            withAnimation(.easeInOut(duration: 0.3)) {
                startNewRound()
            }
        }
    }
    
    private func completeTest() {
        // Create results for all questions
        let results = questions.map { question in
            WordTestResult(
                word: question.word,
                chinese: question.chinese,
                userAnswer: incorrectWordsInSession.contains(question.word) ? "错误" : "正确",
                isCorrect: !incorrectWordsInSession.contains(question.word),
                testType: TestType.wordMeaningMatch.rawValue
            )
        }
        
        // Report results to coordinator
        testCoordinator.completeCurrentTest(results: results)
        onComplete()
    }
}

// MARK: - Match Item Component
struct MatchItem: View {
    let text: String
    let isWord: Bool
    let isSelected: Bool
    let isMatched: Bool
    let isIncorrect: Bool
    let matchAnimation: Bool
    let action: () -> Void
    
    private var backgroundColor: Color {
        if isMatched {
            return Color.green.opacity(0.3)
        } else if isIncorrect {
            return Color.red.opacity(0.3)
        } else if isSelected {
            return Color.blue.opacity(0.2)
        } else {
            return Color.white
        }
    }
    
    private var borderColor: Color {
        if isMatched {
            return Color.green
        } else if isIncorrect {
            return Color.red
        } else if isSelected {
            return Color.blue
        } else {
            return Color.gray.opacity(0.3)
        }
    }
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(isWord ? .system(size: 18, weight: .medium) : .system(size: 16))
                .foregroundColor(isMatched ? .green : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .padding(.horizontal, 12)
                .background(backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(borderColor, lineWidth: isSelected || isIncorrect ? 2 : 1)
                )
                .cornerRadius(12)
                .scaleEffect(matchAnimation ? 1.05 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: matchAnimation)
        }
        .disabled(isMatched)
    }
}
