//
//  ChineseToEnglishSelectView.swift
//  Savanalearns
//
//  Created by xiang guangzhen on 2025/9/16.
//

//
//  ChineseToEnglishSelectView.swift
//  Savanalearns
//
//  Chinese to English Select Test - 选择填词
//  Show Chinese meaning, users select letters to spell the English word
//

import SwiftUI

struct ChineseToEnglishSelectView: View {
    @ObservedObject var testCoordinator: TestCoordinator
    let questions: [TestQuestion]
    let onComplete: () -> Void
    let onBack: () -> Void
    
    // MARK: - State Properties
    @State private var currentIndex = 0
    @State private var selectedLetters = ""
    @State private var isAnswering = true
    @State private var results: [WordTestResult] = []
    @State private var showFeedback = false
    @State private var feedbackMessage = ""
    @State private var isCorrect = false
    
    // Animation states
    @State private var letterAnimations: [Character: Bool] = [:]
    @State private var shakeAnimation = false
    
    // Constants
    private let feedbackDuration = 1.5
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            testHeader
            
            // Progress bar
            progressBar
            
            if currentIndex < questions.count {
                // Main content
                questionContent
            } else {
                EmptyView()
                    .onAppear {
                        completeTest()
                    }
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading: backButton)
    }
    
    // MARK: - View Components
    
    private var testHeader: some View {
        VStack(spacing: 4) {
            Text("选择填词")
                .font(.title2)
                .fontWeight(.bold)
            
            HStack(spacing: 4) {
                Text("第 \(currentIndex + 1) 题")
                Text("/")
                Text("\(questions.count) 题")
            }
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
    
    private var questionContent: some View {
        VStack(spacing: 24) {
            // Chinese meaning
            VStack(spacing: 8) {
                Text("中文释义：")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text(currentQuestion.chinese)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue.opacity(0.05))
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.top, 20)
            
            // Word spelling area
            spellingArea
            
            Spacer()
            
            // Letter selection area
            if isAnswering {
                letterSelectionArea
            } else {
                // Feedback display
                feedbackDisplay
            }
            
            Spacer()
        }
    }
    
    private var spellingArea: some View {
        HStack(spacing: 8) {
            ForEach(0..<targetWord.count, id: \.self) { index in
                LetterBox(
                    letter: index < selectedLetters.count ?
                        String(selectedLetters[selectedLetters.index(selectedLetters.startIndex, offsetBy: index)]) : "_",
                    isRevealed: index < selectedLetters.count,
                    isCorrect: showFeedback && isCorrect,
                    isIncorrect: showFeedback && !isCorrect
                )
            }
        }
        .padding()
        .modifier(ShakeEffect(shakes: shakeAnimation ? 2 : 0))
        .animation(.default, value: shakeAnimation)
    }
    
    private var letterSelectionArea: some View {
        VStack(spacing: 12) {
            Text("请选择下一个字母")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                ForEach(currentCandidates, id: \.self) { letter in
                    LetterButton(
                        letter: String(letter),
                        isAnimated: letterAnimations[letter] ?? false
                    ) {
                        selectLetter(letter)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var feedbackDisplay: some View {
        VStack(spacing: 16) {
            Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(isCorrect ? .green : .red)
                .scaleEffect(showFeedback ? 1.2 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: showFeedback)
            
            VStack(spacing: 8) {
                Text(feedbackMessage)
                    .font(.headline)
                    .foregroundColor(isCorrect ? .green : .red)
                
                if !isCorrect {
                    Text("Correct answer: \(targetWord)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isCorrect ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isCorrect ? Color.green : Color.red, lineWidth: 1)
                )
        )
        .padding(.horizontal)
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
    
    private var currentQuestion: TestQuestion {
        questions[currentIndex]
    }
    
    private var targetWord: String {
        currentQuestion.word.lowercased()
    }
    
    private var progressPercentage: Double {
        questions.isEmpty ? 0 : Double(currentIndex) / Double(questions.count)
    }
    
    private var currentCandidates: [Character] {
        let currentPosition = selectedLetters.count
        guard currentPosition < targetWord.count else { return [] }
        
        let targetIndex = targetWord.index(targetWord.startIndex, offsetBy: currentPosition)
        let correctLetter = targetWord[targetIndex]
        
        // Generate 3 random incorrect letters
        let allLetters = "abcdefghijklmnopqrstuvwxyz"
        let incorrectLetters = allLetters
            .filter { $0 != correctLetter }
            .shuffled()
            .prefix(3)
        
        // Mix correct letter with incorrect ones
        return ([correctLetter] + incorrectLetters).shuffled()
    }
    
    // MARK: - Logic Methods
    
    private func selectLetter(_ letter: Character) {
        // Animate the button press
        withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
            letterAnimations[letter] = true
        }
        
        // Add letter to selected
        selectedLetters.append(letter)
        
        // Check if word is complete
        if selectedLetters.count == targetWord.count {
            checkAnswer()
        } else {
            // Reset animation for next selection
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                letterAnimations[letter] = false
            }
        }
    }
    
    private func checkAnswer() {
        isAnswering = false
        isCorrect = selectedLetters.lowercased() == targetWord
        
        if isCorrect {
            feedbackMessage = "正确! Well done!"
        } else {
            feedbackMessage = "不正确"
            shakeAnimation = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                shakeAnimation = false
            }
        }
        
        showFeedback = true
        
        // Record result
        let result = WordTestResult(
            word: currentQuestion.word,
            chinese: currentQuestion.chinese,
            userAnswer: selectedLetters,
            isCorrect: isCorrect,
            testType: TestType.chineseToEnglishSelect.rawValue
        )
        results.append(result)
        
        // Move to next question after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + feedbackDuration) {
            moveToNextQuestion()
        }
    }
    
    private func moveToNextQuestion() {
        if currentIndex + 1 < questions.count {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentIndex += 1
                resetForNewQuestion()
            }
        } else {
            completeTest()
        }
    }
    
    private func resetForNewQuestion() {
        selectedLetters = ""
        isAnswering = true
        showFeedback = false
        feedbackMessage = ""
        letterAnimations = [:]
        shakeAnimation = false
    }
    
    private func completeTest() {
        // Report results to coordinator
        testCoordinator.completeCurrentTest(results: results)
        onComplete()
    }
}

// MARK: - Letter Box Component
struct LetterBox: View {
    let letter: String
    let isRevealed: Bool
    let isCorrect: Bool
    let isIncorrect: Bool
    
    private var backgroundColor: Color {
        if isCorrect {
            return Color.green.opacity(0.1)
        } else if isIncorrect {
            return Color.red.opacity(0.1)
        } else if isRevealed {
            return Color.blue.opacity(0.1)
        } else {
            return Color.gray.opacity(0.05)
        }
    }
    
    private var borderColor: Color {
        if isCorrect {
            return Color.green
        } else if isIncorrect {
            return Color.red
        } else if isRevealed {
            return Color.blue
        } else {
            return Color.gray.opacity(0.3)
        }
    }
    
    var body: some View {
        Text(letter.uppercased())
            .font(.system(size: 24, weight: .bold, design: .monospaced))
            .frame(width: 40, height: 50)
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderColor, lineWidth: isRevealed ? 2 : 1)
            )
            .cornerRadius(8)
            .scaleEffect(isRevealed ? 1.0 : 0.95)
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isRevealed)
    }
}

// MARK: - Letter Button Component
struct LetterButton: View {
    let letter: String
    let isAnimated: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(letter.uppercased())
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.primary)
                .frame(width: 60, height: 60)
                .background(Color.blue.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
                .cornerRadius(12)
                .scaleEffect(isAnimated ? 0.9 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isAnimated)
        }
    }
}
