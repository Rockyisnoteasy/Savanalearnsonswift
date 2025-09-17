//
//  MeaningToWordSelectView.swift
//  Savanalearns
//
//  Created by xiang guangzhen on 2025/9/16.
//

//
//  MeaningToWordSelectView.swift
//  Savanalearns
//
//  Meaning to Word Select Test - 以意选词
//  Show Chinese meaning, users select the correct English word
//

import SwiftUI

struct MeaningToWordSelectView: View {
    @ObservedObject var testCoordinator: TestCoordinator
    @ObservedObject var dictionaryViewModel: DictionaryViewModel
    let questions: [TestQuestion]
    let onComplete: () -> Void
    let onBack: () -> Void
    
    // MARK: - State Properties
    @State private var currentIndex = 0
    @State private var results: [WordTestResult] = []
    @State private var candidates: [String] = []
    @State private var isLoadingCandidates = false
    @State private var selectedAnswer: String? = nil
    @State private var showFeedback = false
    @State private var isCorrect = false
    
    // Animation states
    @State private var buttonAnimations: [String: Bool] = [:]
    @State private var shakeAnimation = false
    
    // Constants
    private let feedbackDuration = 1.0
    private let numberOfOptions = 4
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            testHeader
            
            // Progress bar
            progressBar
            
            // Main content
            if currentIndex < questions.count {
                questionContent
            } else {
                // This shouldn't happen as we handle completion
                EmptyView()
                    .onAppear {
                        completeTest()
                    }
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading: backButton)
        .onAppear {
            loadCandidatesForCurrentQuestion()
        }
    }
    
    // MARK: - View Components
    
    private var testHeader: some View {
        VStack(spacing: 4) {
            Text("以意选词")
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
            // Chinese meaning display
            VStack(spacing: 12) {
                Text("中文释义：")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text(currentQuestion.chinese)
                    .font(.title2)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue.opacity(0.05))
                    .cornerRadius(12)
                    .modifier(ShakeEffect(shakes: shakeAnimation ? 2 : 0))
                    .animation(.default, value: shakeAnimation)
            }
            .padding(.horizontal)
            .padding(.top, 32)
            
            Spacer()
            
            // Answer options
            if isLoadingCandidates {
                ProgressView()
                    .frame(maxHeight: 200)
            } else {
                VStack(spacing: 12) {
                    ForEach(candidates, id: \.self) { option in
                        AnswerButton(
                            text: option,
                            isSelected: selectedAnswer == option,
                            isCorrect: showFeedback && option == currentQuestion.word,
                            isIncorrect: showFeedback && selectedAnswer == option && option != currentQuestion.word,
                            isDisabled: showFeedback,
                            animation: buttonAnimations[option] ?? false
                        ) {
                            selectAnswer(option)
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            Spacer()
        }
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
    
    private var progressPercentage: Double {
        questions.isEmpty ? 0 : Double(currentIndex) / Double(questions.count)
    }
    
    // MARK: - Logic Methods
    
    private func loadCandidatesForCurrentQuestion() {
        guard currentIndex < questions.count else { return }
        
        isLoadingCandidates = true
        candidates = []
        selectedAnswer = nil
        showFeedback = false
        buttonAnimations = [:]
        
        Task {
            // Get distractor words from dictionary
            let correctWord = currentQuestion.word
            let distractors = await dictionaryViewModel.getRandomDistractorWords(
                correctWord,
                count: numberOfOptions - 1
            )
            
            // Combine and shuffle
            await MainActor.run {
                candidates = ([correctWord] + distractors).shuffled()
                isLoadingCandidates = false
            }
        }
    }
    
    private func selectAnswer(_ answer: String) {
        guard !showFeedback else { return }
        
        selectedAnswer = answer
        let correct = answer.lowercased() == currentQuestion.word.lowercased()
        isCorrect = correct
        
        // Animate the selected button
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            buttonAnimations[answer] = true
        }
        
        // Show feedback
        showFeedback = true
        
        if !correct {
            // Shake animation for incorrect answer
            shakeAnimation = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                shakeAnimation = false
            }
        }
        
        // Record result
        let result = WordTestResult(
            word: currentQuestion.word,
            chinese: currentQuestion.chinese,
            userAnswer: answer,
            isCorrect: correct,
            testType: TestType.meaningToWordSelect.rawValue
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
            }
            loadCandidatesForCurrentQuestion()
        } else {
            completeTest()
        }
    }
    
    private func completeTest() {
        // Report results to coordinator
        testCoordinator.completeCurrentTest(results: results)
        onComplete()
    }
}

// MARK: - Answer Button Component
struct AnswerButton: View {
    let text: String
    let isSelected: Bool
    let isCorrect: Bool
    let isIncorrect: Bool
    let isDisabled: Bool
    let animation: Bool
    let action: () -> Void
    
    private var backgroundColor: Color {
        if isCorrect {
            return Color.green.opacity(0.15)
        } else if isIncorrect {
            return Color.red.opacity(0.15)
        } else if isSelected {
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
        } else if isSelected {
            return Color.blue
        } else {
            return Color.gray.opacity(0.3)
        }
    }
    
    private var textColor: Color {
        if isCorrect {
            return .green
        } else if isIncorrect {
            return .red
        } else if isSelected {
            return .blue
        } else {
            return .primary
        }
    }
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.title3)
                .fontWeight(isSelected || isCorrect ? .semibold : .regular)
                .foregroundColor(textColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(borderColor, lineWidth: isSelected || isCorrect || isIncorrect ? 2 : 1)
                )
                .cornerRadius(12)
                .scaleEffect(animation ? 1.05 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: animation)
        }
        .disabled(isDisabled)
    }
}

// MARK: - Shake Effect Modifier
struct ShakeEffect: GeometryEffect {
    var shakes: Int
    var animatableData: Double {
        get { Double(shakes) }
        set { shakes = Int(newValue) }
    }
    
    func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = sin(.pi * 2 * Double(shakes)) * 5
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}
